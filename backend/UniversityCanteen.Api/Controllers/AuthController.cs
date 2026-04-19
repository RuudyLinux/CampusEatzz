using Dapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using UniversityCanteen.Api.Configuration;
using UniversityCanteen.Api.Data;
using UniversityCanteen.Api.Models;
using UniversityCanteen.Api.Services;

namespace UniversityCanteen.Api.Controllers;

[ApiController]
[Route("api")]
public sealed class AuthController(
    IDbConnectionFactory dbConnectionFactory,
    IOptions<OtpOptions> otpOptions,
    IOptions<JwtOptions> jwtOptions,
    IOptions<SmtpOptions> smtpOptions,
    IOtpEmailSender otpEmailSender,
    ILogger<AuthController> logger,
    IWebHostEnvironment environment) : ControllerBase
{
    private readonly JwtOptions _jwtOptions = jwtOptions.Value;
    private readonly OtpOptions _otpOptions = otpOptions.Value;
    private readonly SmtpOptions _smtpOptions = smtpOptions.Value;
    private readonly bool _isDevelopment = environment.IsDevelopment();

    [HttpPost("login.php")]
    [HttpPost("auth/request-otp")]
    public async Task<IActionResult> RequestOtp([FromBody] LoginRequest request, CancellationToken cancellationToken)
    {
        var identifier = request.Email.Trim();
        var password = request.Password;

        if (string.IsNullOrWhiteSpace(identifier) || string.IsNullOrWhiteSpace(password))
        {
            return BadRequest(OtpFailure("Email or enrollment number and password are required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var schema = await ResolveUsersSchema(connection, cancellationToken);
            var user = await FindUserByIdentifier(connection, schema, identifier, cancellationToken);

            if (user is null || !BCrypt.Net.BCrypt.Verify(password, user.PasswordHash))
            {
                return Unauthorized(OtpFailure("Invalid email/enrollment number or password."));
            }

            var challenge = await IssueOtp(connection, schema, user, cancellationToken);
            return Ok(challenge);
        }
        catch (InvalidOperationException ex)
        {
            logger.LogWarning(ex, "OTP request delivery failed for identifier {Identifier}", identifier);
            return StatusCode(StatusCodes.Status503ServiceUnavailable, OtpFailure(ex.Message));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "OTP request failed for identifier {Identifier}", identifier);
            return StatusCode(StatusCodes.Status500InternalServerError, OtpFailure("Internal server error during OTP request."));
        }
    }

    [HttpPost("auth/resend-otp")]
    public async Task<IActionResult> ResendOtp([FromBody] OtpResendRequest request, CancellationToken cancellationToken)
    {
        var identifier = request.Email.Trim();
        if (string.IsNullOrWhiteSpace(identifier))
        {
            return BadRequest(OtpFailure("Email or enrollment number is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var schema = await ResolveUsersSchema(connection, cancellationToken);
            var user = await FindUserByIdentifier(connection, schema, identifier, cancellationToken);
            if (user is null)
            {
                return NotFound(OtpFailure("User account not found."));
            }

            if (string.IsNullOrWhiteSpace(user.OtpCode) || user.OtpExpiry is null || user.OtpExpiry.Value < DateTime.UtcNow)
            {
                return BadRequest(OtpFailure("OTP session expired. Please log in again to request a new OTP."));
            }

            var challenge = await IssueOtp(connection, schema, user, cancellationToken);
            return Ok(challenge);
        }
        catch (InvalidOperationException ex)
        {
            logger.LogWarning(ex, "OTP resend delivery failed for identifier {Identifier}", identifier);
            return StatusCode(StatusCodes.Status503ServiceUnavailable, OtpFailure(ex.Message));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "OTP resend failed for identifier {Identifier}", identifier);
            return StatusCode(StatusCodes.Status500InternalServerError, OtpFailure("Internal server error during OTP resend."));
        }
    }

    [HttpPost("auth/verify-otp")]
    public async Task<IActionResult> VerifyOtp([FromBody] OtpVerifyRequest request, CancellationToken cancellationToken)
    {
        var identifier = request.Email.Trim();
        var otp = request.Otp.Trim();

        if (string.IsNullOrWhiteSpace(identifier) || string.IsNullOrWhiteSpace(otp))
        {
            return BadRequest(Failure("Email/enrollment number and OTP are required."));
        }

        if (otp.Length != 6 || otp.Any(ch => !char.IsDigit(ch)))
        {
            return BadRequest(Failure("OTP must be exactly 6 digits."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var schema = await ResolveUsersSchema(connection, cancellationToken);
            var user = await FindUserByIdentifier(connection, schema, identifier, cancellationToken);

            if (user is null)
            {
                return Unauthorized(Failure("Invalid account."));
            }

            if (string.IsNullOrWhiteSpace(user.OtpCode) || user.OtpExpiry is null)
            {
                return BadRequest(Failure("Please request OTP first."));
            }

            if (user.OtpExpiry.Value < DateTime.UtcNow)
            {
                return Unauthorized(Failure("OTP expired. Please request a new OTP."));
            }

            var isOtpValid = false;
            try
            {
                isOtpValid = BCrypt.Net.BCrypt.Verify(otp, user.OtpCode);
            }
            catch
            {
                isOtpValid = false;
            }

            if (!isOtpValid)
            {
                return Unauthorized(Failure("Invalid OTP."));
            }

            var updateSql = BuildVerifySuccessUpdateSql(schema);

            await connection.ExecuteAsync(new CommandDefinition(
                updateSql,
                new { userId = user.UniversityId },
                cancellationToken: cancellationToken));

            var session = new SessionUserDto
            {
                Id = user.UniversityId,
                Name = user.FullName,
                Email = user.EmailId,
                Role = user.Role
            };

            var token = IssueJwt(session);
            return Ok(Success("OTP verified. Login successful.", session, token));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "OTP verification failed for identifier {Identifier}", identifier);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error during OTP verification."));
        }
    }

    [HttpGet("auth/me")]
    public async Task<IActionResult> GetCurrentUser([FromQuery] string identifier, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(identifier))
        {
            return BadRequest(Failure("Identifier is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var schema = await ResolveUsersSchema(connection, cancellationToken);
            var user = await FindCurrentUser(connection, schema, identifier.Trim(), cancellationToken);

            if (user is null)
            {
                return NotFound(Failure("User not found."));
            }

            return Ok(Success("User profile fetched successfully.", user));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch current user profile for identifier {Identifier}", identifier);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching profile."));
        }
    }

    [HttpPost("admin/login")]
    public async Task<IActionResult> AdminLogin([FromBody] LoginRequest request, CancellationToken cancellationToken)
    {
        var email = request.Email.Trim();
        var password = request.Password;

        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
        {
            return BadRequest(Failure("Email and password are required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var admin = await FindAdminUserByEmailAsync(connection, email, cancellationToken);
            if (admin is not null && VerifyBcrypt(password, admin.PasswordHash))
            {
                var directSession = BuildAdminSession(admin);
                return Ok(Success("Login successful.", directSession, IssueJwt(directSession)));
            }
            return Unauthorized(Failure("Invalid admin credentials"));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Admin login failed for {Email}.", email);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error during admin login."));
        }
    }

    private static SessionUserDto BuildAdminSession(AdminUserAccountRow admin)
    {
        return new SessionUserDto
        {
            Id = admin.Id,
            Name = string.IsNullOrWhiteSpace(admin.Name) ? admin.Email : admin.Name,
            Email = admin.Email,
            Role = "admin"
        };
    }

    private static bool VerifyBcrypt(string inputPassword, string hash)
    {
        if (string.IsNullOrWhiteSpace(hash))
        {
            return false;
        }

        try
        {
            return BCrypt.Net.BCrypt.Verify(inputPassword, hash);
        }
        catch
        {
            return false;
        }
    }

    private static async Task<AdminUserAccountRow?> FindAdminUserByEmailAsync(
        System.Data.IDbConnection connection,
        string email,
        CancellationToken cancellationToken)
    {
        return await connection.QuerySingleOrDefaultAsync<AdminUserAccountRow>(new CommandDefinition(
            """
            SELECT
                id AS Id,
                COALESCE(name, '') AS Name,
                COALESCE(email, '') AS Email,
                COALESCE(password, '') AS PasswordHash,
                COALESCE(created_at, UTC_TIMESTAMP()) AS CreatedAt
            FROM admin_users
            WHERE LOWER(COALESCE(email, '')) = LOWER(@email)
            LIMIT 1;
            """,
            new { email },
            cancellationToken: cancellationToken));
    }

    private static async Task<LegacyAdminUserRow?> FindLegacyAdminByEmailAsync(
        System.Data.IDbConnection connection,
        string email,
        CancellationToken cancellationToken)
    {
        return await connection.QuerySingleOrDefaultAsync<LegacyAdminUserRow>(new CommandDefinition(
            """
            SELECT
                COALESCE(NULLIF(TRIM(CONCAT(COALESCE(first_name, ''), ' ', COALESCE(last_name, ''))), ''), COALESCE(email, 'Admin')) AS Name,
                COALESCE(email, '') AS Email,
                COALESCE(password_hash, '') AS PasswordHash
            FROM users
            WHERE LOWER(COALESCE(email, '')) = LOWER(@email)
              AND LOWER(COALESCE(role, 'student')) = 'admin'
              AND COALESCE(is_deleted, 0) = 0
              AND COALESCE(status, 'active') = 'active'
            LIMIT 1;
            """,
            new { email },
            cancellationToken: cancellationToken));
    }

    private static async Task<AdminUserAccountRow> UpsertAdminUserAsync(
        System.Data.IDbConnection connection,
        string name,
        string email,
        string passwordHash,
        CancellationToken cancellationToken)
    {
        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO admin_users (name, email, password, created_at)
            VALUES (@name, @email, @password, UTC_TIMESTAMP())
            ON DUPLICATE KEY UPDATE
                name = VALUES(name),
                password = VALUES(password);
            """,
            new
            {
                name = string.IsNullOrWhiteSpace(name) ? "Platform Admin" : name.Trim(),
                email = email.Trim(),
                password = passwordHash
            },
            cancellationToken: cancellationToken));

        var upsertedAdmin = await FindAdminUserByEmailAsync(connection, email, cancellationToken);
        if (upsertedAdmin is null)
        {
            throw new InvalidOperationException("Failed to create admin account record.");
        }

        return upsertedAdmin;
    }

    private async Task<UserRow?> FindUserByIdentifier(
        System.Data.IDbConnection connection,
        UsersSchemaInfo schema,
        string identifier,
        CancellationToken cancellationToken)
    {
        var sql = BuildFindUserSql(schema);

        return await connection.QuerySingleOrDefaultAsync<UserRow>(
            new CommandDefinition(sql, new { identifier }, cancellationToken: cancellationToken));
    }

    private async Task<SessionUserDto?> FindCurrentUser(
        System.Data.IDbConnection connection,
        UsersSchemaInfo schema,
        string identifier,
        CancellationToken cancellationToken)
    {
        var sql = BuildCurrentUserSql(schema);

        return await connection.QuerySingleOrDefaultAsync<SessionUserDto>(
            new CommandDefinition(sql, new { identifier }, cancellationToken: cancellationToken));
    }

    private async Task<OtpChallengeResponse> IssueOtp(
        System.Data.IDbConnection connection,
        UsersSchemaInfo schema,
        UserRow user,
        CancellationToken cancellationToken)
    {
        var codeLength = Math.Clamp(_otpOptions.CodeLength, 4, 8);
        var expiryMinutes = Math.Clamp(_otpOptions.ExpiryMinutes, 1, 30);
        var expiryUtc = DateTime.UtcNow.AddMinutes(expiryMinutes);
        var otp = GenerateOtp(codeLength);
        var otpHash = BCrypt.Net.BCrypt.HashPassword(otp);

        var updateSql = BuildIssueOtpUpdateSql(schema);

        await connection.ExecuteAsync(new CommandDefinition(
            updateSql,
            new
            {
                otpHash,
                expiryUtc,
                userId = user.UniversityId
            },
            cancellationToken: cancellationToken));

        string? developmentOtp = null;
        if (IsSmtpConfigured())
        {
            try
            {
                await otpEmailSender.SendOtpAsync(user.EmailId, user.FullName, otp, expiryUtc, cancellationToken);

                if (_isDevelopment && _otpOptions.ExposeOtpInResponseInDevelopment)
                {
                    developmentOtp = otp;
                    logger.LogInformation(
                        "Development mode is enabled. Including OTP in response payload for identifier {Identifier}.",
                        user.EmailId);
                }
            }
            catch
            {
                var rollbackSql = BuildClearOtpSql(schema);

                await connection.ExecuteAsync(new CommandDefinition(
                    rollbackSql,
                    new { userId = user.UniversityId },
                    cancellationToken: cancellationToken));

                throw;
            }
        }
        else
        {
            developmentOtp = otp;
            logger.LogWarning(
                "SMTP is not configured. Returning development OTP for identifier {Identifier}.",
                user.EmailId);
        }

        logger.LogInformation("OTP generated for user {UniversityId}", user.UniversityId);

        return OtpSuccess(
            "OTP sent successfully.",
            new OtpChallengeData
            {
                Identifier = user.EmailId,
                ExpiresInSeconds = expiryMinutes * 60,
                DevelopmentOtp = developmentOtp
            });
    }

    private bool IsSmtpConfigured()
    {
        return !string.IsNullOrWhiteSpace(_smtpOptions.Host)
            && !string.IsNullOrWhiteSpace(_smtpOptions.UserName)
            && !string.IsNullOrWhiteSpace(_smtpOptions.Password)
            && !string.IsNullOrWhiteSpace(_smtpOptions.FromEmail);
    }

    private static string GenerateOtp(int length)
    {
        var output = new char[length];
        for (var i = 0; i < length; i++)
        {
            output[i] = (char)('0' + RandomNumberGenerator.GetInt32(0, 10));
        }

        return new string(output);
    }

    private static async Task<UsersSchemaInfo> ResolveUsersSchema(
        System.Data.IDbConnection connection,
        CancellationToken cancellationToken)
    {
        var hasLegacyUniversityId = await ColumnExistsByProbe(connection, "UniversityId", cancellationToken);
        var hasLegacyEmail = await ColumnExistsByProbe(connection, "EmailId", cancellationToken);
        var hasLegacyPasswordHash = await ColumnExistsByProbe(connection, "PasswordHash", cancellationToken);

        var isLegacy = hasLegacyUniversityId && hasLegacyEmail && hasLegacyPasswordHash;

        if (isLegacy)
        {
            return new UsersSchemaInfo
            {
                Kind = UsersSchemaKind.Legacy,
                KeyColumn = "UniversityId",
                HasIsLoggedIn = await ColumnExistsByProbe(connection, "IsLoggedIn", cancellationToken)
            };
        }

        var hasCafeId = await ColumnExistsByProbe(connection, "id", cancellationToken);
        var hasCafeEmail = await ColumnExistsByProbe(connection, "email", cancellationToken);
        var hasCafePasswordHash = await ColumnExistsByProbe(connection, "password_hash", cancellationToken);

        var isCafe = hasCafeId && hasCafeEmail && hasCafePasswordHash;

        if (isCafe)
        {
            var hasFirstName = await ColumnExistsByProbe(connection, "first_name", cancellationToken);
            var hasLastName = await ColumnExistsByProbe(connection, "last_name", cancellationToken);

            return new UsersSchemaInfo
            {
                Kind = UsersSchemaKind.Cafe,
                KeyColumn = "id",
                HasIsLoggedIn = await ColumnExistsByProbe(connection, "IsLoggedIn", cancellationToken),
                HasEnrollmentNo = await ColumnExistsByProbe(connection, "enrollment_no", cancellationToken),
                HasUniversityId = await ColumnExistsByProbe(connection, "UniversityId", cancellationToken),
                HasNameColumns = hasFirstName || hasLastName
            };
        }

        throw new InvalidOperationException(
            "Unsupported users table schema. Expected legacy (UniversityId/EmailId/PasswordHash) or cafe (id/email/password_hash).");
    }

    private static async Task<bool> ColumnExistsByProbe(
        System.Data.IDbConnection connection,
        string columnName,
        CancellationToken cancellationToken)
    {
        var sql = $"SELECT `{columnName}` FROM users LIMIT 1;";

        try
        {
            await connection.ExecuteScalarAsync(new CommandDefinition(sql, cancellationToken: cancellationToken));
            return true;
        }
        catch (Exception ex) when (ex.Message.Contains("Unknown column", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }
    }

    private static string BuildFindUserSql(UsersSchemaInfo schema)
    {
        if (schema.Kind == UsersSchemaKind.Legacy)
        {
            return """
                SELECT
                    u.UniversityId AS UniversityId,
                    u.EmailId AS EmailId,
                    u.PasswordHash AS PasswordHash,
                    u.Role AS Role,
                    u.OtpCode,
                    u.OtpExpiry,
                    u.EmailId AS FullName
                FROM users u
                WHERE u.EmailId = @identifier
                   OR CAST(u.UniversityId AS CHAR) = @identifier
                LIMIT 1;
                """;
        }

        var fullNameExpression = schema.HasNameColumns
            ? "COALESCE(NULLIF(TRIM(CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, ''))), ''), u.email)"
            : "u.email";

        var enrollmentCondition = schema.HasEnrollmentNo
            ? "\n               OR COALESCE(u.enrollment_no, '') = @identifier"
            : string.Empty;

        var universityIdCondition = schema.HasUniversityId
            ? "\n               OR COALESCE(u.UniversityId, '') = @identifier"
            : string.Empty;

        return $"""
            SELECT
                u.id AS UniversityId,
                u.email AS EmailId,
                u.password_hash AS PasswordHash,
                u.role AS Role,
                u.OtpCode,
                u.OtpExpiry,
                {fullNameExpression} AS FullName
            FROM users u
            WHERE u.email = @identifier
                    OR CAST(u.id AS CHAR) = @identifier{enrollmentCondition}{universityIdCondition}
            LIMIT 1;
            """;
    }

    private static string BuildIssueOtpUpdateSql(UsersSchemaInfo schema)
    {
        if (schema.HasIsLoggedIn)
        {
            return $"UPDATE users SET OtpCode = @otpHash, OtpExpiry = @expiryUtc, IsLoggedIn = 0 WHERE {schema.KeyColumn} = @userId;";
        }

        return $"UPDATE users SET OtpCode = @otpHash, OtpExpiry = @expiryUtc WHERE {schema.KeyColumn} = @userId;";
    }

    private static string BuildVerifySuccessUpdateSql(UsersSchemaInfo schema)
    {
        if (schema.HasIsLoggedIn)
        {
            return $"UPDATE users SET IsLoggedIn = 1, OtpCode = NULL, OtpExpiry = NULL WHERE {schema.KeyColumn} = @userId;";
        }

        return $"UPDATE users SET OtpCode = NULL, OtpExpiry = NULL WHERE {schema.KeyColumn} = @userId;";
    }

    private static string BuildClearOtpSql(UsersSchemaInfo schema)
    {
        return $"UPDATE users SET OtpCode = NULL, OtpExpiry = NULL WHERE {schema.KeyColumn} = @userId;";
    }

    private static string BuildCurrentUserSql(UsersSchemaInfo schema)
    {
        if (schema.Kind == UsersSchemaKind.Legacy)
        {
            return """
                SELECT
                    u.UniversityId AS Id,
                    CAST(u.UniversityId AS CHAR) AS UniversityId,
                    COALESCE(u.EmailId, '') AS Email,
                    COALESCE(u.Role, '') AS Role,
                    COALESCE(u.EmailId, '') AS Name,
                    NULL AS FirstName,
                    NULL AS LastName,
                    NULL AS Contact,
                    NULL AS Department,
                    NULL AS Status
                FROM users u
                WHERE u.EmailId = @identifier
                   OR CAST(u.UniversityId AS CHAR) = @identifier
                LIMIT 1;
                """;
        }

        var enrollmentCondition = schema.HasEnrollmentNo
            ? "\n               OR COALESCE(u.enrollment_no, '') = @identifier"
            : string.Empty;

        var universityIdCondition = schema.HasUniversityId
            ? "\n               OR COALESCE(u.UniversityId, '') = @identifier"
            : string.Empty;

        return $"""
            SELECT
                u.id AS Id,
                COALESCE(u.UniversityId, CAST(u.id AS CHAR)) AS UniversityId,
                COALESCE(u.email, '') AS Email,
                COALESCE(u.role, '') AS Role,
                COALESCE(NULLIF(TRIM(CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, ''))), ''), u.email) AS Name,
                COALESCE(u.first_name, '') AS FirstName,
                COALESCE(u.last_name, '') AS LastName,
                COALESCE(u.contact, '') AS Contact,
                COALESCE(u.department, '') AS Department,
                COALESCE(u.status, '') AS Status
            FROM users u
            WHERE u.email = @identifier
               OR CAST(u.id AS CHAR) = @identifier{enrollmentCondition}{universityIdCondition}
            LIMIT 1;
            """;
    }

    [HttpPost("canteen-admin/login")]
    public async Task<IActionResult> CanteenAdminLogin([FromBody] LoginRequest request, CancellationToken cancellationToken)
    {
        var email = request.Email.Trim();
        var password = request.Password;

        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
        {
            return BadRequest(Failure("Email and password are required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var dbAdmin = await connection.QuerySingleOrDefaultAsync<CanteenAdminAccountRow>(new CommandDefinition(
                """
                SELECT
                    ca.id AS Id,
                    ca.canteen_id AS CanteenId,
                    COALESCE(ca.username, '') AS Username,
                    COALESCE(ca.password, '') AS PasswordHash,
                    COALESCE(ca.plain_password, '') AS PlainPassword,
                    COALESCE(ca.name, '') AS Name,
                    COALESCE(ca.email, '') AS Email,
                    COALESCE(ca.image_url, '') AS ImageUrl,
                    COALESCE(c.name, '') AS CanteenName
                FROM canteen_admins ca
                LEFT JOIN canteens c ON c.id = ca.canteen_id
                WHERE (
                    LOWER(COALESCE(ca.email, '')) = LOWER(@identifier)
                    OR LOWER(ca.username) = LOWER(@identifier)
                )
                  AND COALESCE(ca.status, 'active') = 'active'
                LIMIT 1;
                """,
                new { identifier = email },
                cancellationToken: cancellationToken));

            if (dbAdmin is null || !VerifyCanteenAdminPassword(password, dbAdmin))
            {
                return Unauthorized(Failure("Invalid email or password."));
            }

            var dbSession = new SessionUserDto
            {
                Id = dbAdmin.Id,
                Name = string.IsNullOrWhiteSpace(dbAdmin.Name) ? dbAdmin.Username : dbAdmin.Name,
                Email = string.IsNullOrWhiteSpace(dbAdmin.Email) ? email : dbAdmin.Email,
                Role = "canteen_admin",
                CanteenId = dbAdmin.CanteenId,
                CanteenName = string.IsNullOrWhiteSpace(dbAdmin.CanteenName) ? "Canteen" : dbAdmin.CanteenName,
                ImageUrl = ToClientImageUrl(dbAdmin.ImageUrl)
            };

            return Ok(Success("Login successful.", dbSession, IssueJwt(dbSession)));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Canteen admin DB login failed for identifier {Identifier}.", email);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error during canteen admin login."));
        }
    }

    private static bool VerifyCanteenAdminPassword(string inputPassword, CanteenAdminAccountRow account)
    {
        if (!string.IsNullOrWhiteSpace(account.PlainPassword)
            && string.Equals(inputPassword, account.PlainPassword, StringComparison.Ordinal))
        {
            return true;
        }

        if (string.IsNullOrWhiteSpace(account.PasswordHash))
        {
            return false;
        }

        try
        {
            return BCrypt.Net.BCrypt.Verify(inputPassword, account.PasswordHash);
        }
        catch
        {
            return false;
        }
    }

    private static ApiLoginResponse Success(string message, SessionUserDto data, string? token = null) => new()
    {
        Success = true,
        Message = message,
        Data = data,
        Token = token
    };

    private string IssueJwt(SessionUserDto user)
    {
        var secret = _jwtOptions.Secret;
        if (string.IsNullOrWhiteSpace(secret))
        {
            // Fallback: derive a stable key from a fixed phrase so the app still works
            // when Jwt:Secret is not configured. Not recommended for production.
            secret = "UniversityCanteen-DefaultSecret-ChangeInProduction!";
        }

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, user.Email),
            new Claim(ClaimTypes.Role, user.Role),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var expiryHours = Math.Clamp(_jwtOptions.ExpiryHours, 1, 168);
        var token = new JwtSecurityToken(
            issuer: _jwtOptions.Issuer,
            audience: _jwtOptions.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddHours(expiryHours),
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private string ToClientImageUrl(string? value)
    {
        var raw = (value ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(raw))
        {
            return string.Empty;
        }

        if (raw.StartsWith("data:", StringComparison.OrdinalIgnoreCase))
        {
            return raw;
        }

        if (Uri.TryCreate(raw, UriKind.Absolute, out var absolute)
            && (absolute.Scheme.Equals("http", StringComparison.OrdinalIgnoreCase)
                || absolute.Scheme.Equals("https", StringComparison.OrdinalIgnoreCase)))
        {
            return raw;
        }

        var normalized = raw.TrimStart('/');
        return $"{Request.Scheme}://{Request.Host}/{normalized}";
    }

    private static ApiLoginResponse Failure(string message) => new()
    {
        Success = false,
        Message = message
    };

    private static OtpChallengeResponse OtpSuccess(string message, OtpChallengeData data) => new()
    {
        Success = true,
        Message = message,
        Data = data
    };

    private static OtpChallengeResponse OtpFailure(string message) => new()
    {
        Success = false,
        Message = message
    };

    private enum UsersSchemaKind
    {
        Legacy,
        Cafe
    }

    private sealed class UsersSchemaInfo
    {
        public UsersSchemaKind Kind { get; init; }
        public string KeyColumn { get; init; } = "id";
        public bool HasIsLoggedIn { get; init; }
        public bool HasEnrollmentNo { get; init; }
        public bool HasUniversityId { get; init; }
        public bool HasNameColumns { get; init; }
    }

    private sealed class UserRow
    {
        public int UniversityId { get; init; }
        public string EmailId { get; init; } = string.Empty;
        public string PasswordHash { get; init; } = string.Empty;
        public string Role { get; init; } = string.Empty;
        public string FullName { get; init; } = string.Empty;
        public string? OtpCode { get; init; }
        public DateTime? OtpExpiry { get; init; }
    }

    private sealed class CanteenAdminAccountRow
    {
        public int Id { get; init; }
        public int CanteenId { get; init; }
        public string Username { get; init; } = string.Empty;
        public string PasswordHash { get; init; } = string.Empty;
        public string PlainPassword { get; init; } = string.Empty;
        public string Name { get; init; } = string.Empty;
        public string Email { get; init; } = string.Empty;
        public string ImageUrl { get; init; } = string.Empty;
        public string CanteenName { get; init; } = string.Empty;
    }

    private sealed class AdminUserAccountRow
    {
        public int Id { get; init; }
        public string Name { get; init; } = string.Empty;
        public string Email { get; init; } = string.Empty;
        public string PasswordHash { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
    }

    private sealed class LegacyAdminUserRow
    {
        public string Name { get; init; } = string.Empty;
        public string Email { get; init; } = string.Empty;
        public string PasswordHash { get; init; } = string.Empty;
    }

}
