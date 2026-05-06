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
    IOtpEmailSender otpEmailSender,
    IHostEnvironment hostEnvironment,
    ILogger<AuthController> logger) : ControllerBase
{
    private readonly JwtOptions _jwtOptions = jwtOptions.Value;
    private readonly OtpOptions _otpOptions = otpOptions.Value;

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

            if (user is null || !IsPasswordValid(password, user.PasswordHash))
            {
                return Unauthorized(OtpFailure("Invalid email/enrollment number or password."));
            }

            if (IsStudentRole(user.Role) && LooksLikeEmail(identifier))
            {
                return BadRequest(OtpFailure("Students must login using enrollment number."));
            }

            if (IsStaffRole(user.Role) && !LooksLikeEmail(identifier))
            {
                return BadRequest(OtpFailure("Faculty must login using email."));
            }

            var challenge = await IssueOtp(connection, schema, user, identifier, cancellationToken);
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
                return Unauthorized(OtpFailure("Invalid email/enrollment number."));
            }

            if (IsStudentRole(user.Role) && LooksLikeEmail(identifier))
            {
                return BadRequest(OtpFailure("Students must login using enrollment number."));
            }

            if (IsStaffRole(user.Role) && !LooksLikeEmail(identifier))
            {
                return BadRequest(OtpFailure("Faculty must login using email."));
            }

            var otpSession = await FindOtpSessionByUserId(connection, user.UniversityId, cancellationToken);
            if (otpSession is null || string.IsNullOrWhiteSpace(otpSession.OtpCode))
            {
                return BadRequest(OtpFailure("No active OTP session found. Please login again."));
            }

            var cooldownSeconds = Math.Clamp(_otpOptions.ResendCooldownSeconds, 0, 300);
            if (cooldownSeconds > 0 && otpSession.CreatedAt.HasValue)
            {
                var issuedAtUtc = NormalizeToUtc(otpSession.CreatedAt.Value);
                var secondsSinceLastIssue = (DateTime.UtcNow - issuedAtUtc).TotalSeconds;
                if (secondsSinceLastIssue < cooldownSeconds)
                {
                    var waitSeconds = Math.Max(1, cooldownSeconds - (int)Math.Floor(secondsSinceLastIssue));
                    return BadRequest(OtpFailure($"Please wait {waitSeconds} seconds before requesting another OTP."));
                }
            }

            var challenge = await IssueOtp(connection, schema, user, identifier, cancellationToken);
            return Ok(challenge);
        }
        catch (InvalidOperationException ex)
        {
            logger.LogWarning(ex, "OTP resend failed for identifier {Identifier}", identifier);
            return StatusCode(StatusCodes.Status503ServiceUnavailable, OtpFailure(ex.Message));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unexpected OTP resend error for identifier {Identifier}", identifier);
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
            return BadRequest(Failure("Email or enrollment number and OTP are required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var schema = await ResolveUsersSchema(connection, cancellationToken);
            var user = await FindUserByIdentifier(connection, schema, identifier, cancellationToken);

            if (user is null)
            {
                return Unauthorized(Failure("Invalid email/enrollment number."));
            }

            if (IsStudentRole(user.Role) && LooksLikeEmail(identifier))
            {
                return BadRequest(Failure("Students must login using enrollment number."));
            }

            if (IsStaffRole(user.Role) && !LooksLikeEmail(identifier))
            {
                return BadRequest(Failure("Faculty must login using email."));
            }

            var otpSession = await FindOtpSessionByUserId(connection, user.UniversityId, cancellationToken);
            if (otpSession is null || string.IsNullOrWhiteSpace(otpSession.OtpCode))
            {
                return BadRequest(Failure("No active OTP found. Please request a new OTP."));
            }

            if (otpSession.ExpiresAt is null || NormalizeToUtc(otpSession.ExpiresAt.Value) <= DateTime.UtcNow)
            {
                await ClearOtpSessionAsync(connection, user.UniversityId, cancellationToken);
                return BadRequest(Failure("OTP has expired. Please request a new OTP."));
            }

            if (!VerifyBcrypt(otp, otpSession.OtpCode))
            {
                return Unauthorized(Failure("Invalid OTP."));
            }

            await ClearOtpSessionAsync(connection, user.UniversityId, cancellationToken);
            await MarkUserLoggedInAsync(connection, schema, user.UniversityId, cancellationToken);

            var session = BuildUserSession(user, identifier);
            var token = IssueJwt(session);
            return Ok(Success("OTP verified. Login successful.", session, token));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "OTP verify failed for identifier {Identifier}", identifier);
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
        var sql = schema.Kind == UsersSchemaKind.Legacy
            ? BuildFindLegacyUserSql()
            : LooksLikeEmail(identifier)
                ? BuildFindStaffUserSql(schema)
                : BuildFindStudentUserSql(schema);

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
        string requestedIdentifier,
        CancellationToken cancellationToken)
    {
        var codeLength = Math.Clamp(_otpOptions.CodeLength, 4, 8);
        var expiryMinutes = Math.Clamp(_otpOptions.ExpiryMinutes, 1, 30);
        var expiryUtc = DateTime.UtcNow.AddMinutes(expiryMinutes);
        var otp = GenerateOtp(codeLength);
        var exposeOtpInResponse = _otpOptions.ExposeOtpInResponseInDevelopment && hostEnvironment.IsDevelopment();
        var allowOtpResponseOnDeliveryFailure = _otpOptions.AllowOtpInResponseOnDeliveryFailure;
        var responseMessage = "OTP sent successfully.";
        var otpForResponse = exposeOtpInResponse ? otp : null;
        var recipientEmail = (user.EmailId ?? string.Empty).Trim();
        var otpHash = BCrypt.Net.BCrypt.HashPassword(otp);
        await UpsertOtpSessionAsync(connection, user.UniversityId, otpHash, expiryUtc, cancellationToken);
        await MarkUserLoggedOutAsync(connection, schema, user.UniversityId, cancellationToken);

        if (string.IsNullOrWhiteSpace(recipientEmail) || !LooksLikeEmail(recipientEmail))
        {
            await ClearOtpSessionAsync(connection, user.UniversityId, cancellationToken);
            throw new InvalidOperationException("No valid registered email found for this account. Please contact support.");
        }

        try
        {
            await otpEmailSender.SendOtpAsync(recipientEmail, user.FullName, otp, expiryUtc, cancellationToken);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("Resend", StringComparison.OrdinalIgnoreCase))
        {
            if (allowOtpResponseOnDeliveryFailure)
            {
                logger.LogWarning(ex, "Resend delivery failed for {UniversityId}; returning OTP in response due fallback setting.", user.UniversityId);
                responseMessage = "OTP generated. Email delivery unavailable; use OTP from response.";
                otpForResponse = otp;
            }
            else
            {
                logger.LogWarning(ex, "Resend OTP configuration/delivery failed for {UniversityId}.", user.UniversityId);
                await ClearOtpSessionAsync(connection, user.UniversityId, cancellationToken);
                throw;
            }
        }
        catch (Exception ex)
        {
            if (allowOtpResponseOnDeliveryFailure)
            {
                logger.LogWarning(ex, "SMTP/Email delivery failed for {UniversityId}; returning OTP in response due fallback setting.", user.UniversityId);
                responseMessage = "OTP generated. Email delivery unavailable; use OTP from response.";
                otpForResponse = otp;
            }
            else
            {
                logger.LogWarning(ex, "Failed to send OTP email for {UniversityId}.", user.UniversityId);
                await ClearOtpSessionAsync(connection, user.UniversityId, cancellationToken);
                throw new InvalidOperationException("Unable to deliver OTP email right now. Please try again shortly.");
            }
        }

        logger.LogInformation("OTP generated for user {UniversityId}", user.UniversityId);

        return OtpSuccess(
            responseMessage,
            new OtpChallengeData
            {
                Identifier = ResolveOtpIdentifier(requestedIdentifier, user),
                ExpiresInSeconds = expiryMinutes * 60,
                Otp = otpForResponse,
                DeliveryEmail = recipientEmail
            });
    }

    private static SessionUserDto BuildUserSession(UserRow user, string identifier)
    {
        return new SessionUserDto
        {
            Id = user.UniversityId,
            Name = user.FullName,
            Email = user.EmailId,
            Role = user.Role,
            UniversityId = LooksLikeEmail(identifier) ? null : identifier
        };
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

    private static DateTime NormalizeToUtc(DateTime value)
    {
        return value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value, DateTimeKind.Utc)
        };
    }

    private static bool LooksLikeEmail(string identifier)
    {
        return identifier.Contains('@', StringComparison.Ordinal);
    }

    private static bool IsStudentRole(string role)
    {
        return string.Equals(role, "student", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsStaffRole(string role)
    {
        return string.Equals(role, "staff", StringComparison.OrdinalIgnoreCase)
            || string.Equals(role, "faculty", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsPasswordValid(string providedPassword, string storedPasswordHash)
    {
        if (string.IsNullOrWhiteSpace(providedPassword) || string.IsNullOrWhiteSpace(storedPasswordHash))
        {
            return false;
        }

        var stored = storedPasswordHash.Trim();

        // Legacy datasets sometimes store plaintext passwords. Only allow plaintext compare
        // when the stored value doesn't look like a bcrypt hash.
        var looksLikeBcrypt = stored.StartsWith("$2", StringComparison.Ordinal) && stored.Length >= 20;
        if (!looksLikeBcrypt)
        {
            return string.Equals(providedPassword, stored, StringComparison.Ordinal);
        }

        try
        {
            return BCrypt.Net.BCrypt.Verify(providedPassword, stored);
        }
        catch
        {
            return false;
        }
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
            var hasUniversityId = await ColumnExistsByProbe(connection, "UniversityId", cancellationToken);
            var hasUniversityIdSnake = await ColumnExistsByProbe(connection, "university_id", cancellationToken);
            var studentKeyColumn = await ResolveIdentifierColumn(connection, "students", cancellationToken);
            var staffKeyColumn = await ResolveIdentifierColumn(connection, "university_staff", cancellationToken);

            return new UsersSchemaInfo
            {
                Kind = UsersSchemaKind.Cafe,
                KeyColumn = "id",
                HasIsLoggedIn = await ColumnExistsByProbe(connection, "IsLoggedIn", cancellationToken),
                HasEnrollmentNo = await ColumnExistsByProbe(connection, "enrollment_no", cancellationToken),
                HasUniversityId = hasUniversityId,
                HasUniversityIdSnake = hasUniversityIdSnake,
                HasNameColumns = hasFirstName || hasLastName,
                StudentIdentifierColumn = studentKeyColumn,
                StaffIdentifierColumn = staffKeyColumn
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
        return await ColumnExistsByProbe(connection, "users", columnName, cancellationToken);
    }

    private static async Task<bool> ColumnExistsByProbe(
        System.Data.IDbConnection connection,
        string tableName,
        string columnName,
        CancellationToken cancellationToken)
    {
        var sql = $"SELECT `{columnName}` FROM `{tableName}` LIMIT 1;";

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

    private static async Task<string> ResolveIdentifierColumn(
        System.Data.IDbConnection connection,
        string tableName,
        CancellationToken cancellationToken)
    {
        if (await ColumnExistsByProbe(connection, tableName, "UniversityId", cancellationToken))
        {
            return "UniversityId";
        }

        if (await ColumnExistsByProbe(connection, tableName, "university_id", cancellationToken))
        {
            return "university_id";
        }

        throw new InvalidOperationException(
            $"Missing identifier column in table '{tableName}'. Expected 'UniversityId' or 'university_id'.");
    }

    private static string BuildFindLegacyUserSql()
    {
        return """
            SELECT
                u.UniversityId AS UniversityId,
                u.EmailId AS EmailId,
                u.PasswordHash AS PasswordHash,
                u.Role AS Role,
                u.EmailId AS FullName
            FROM users u
            WHERE u.EmailId = @identifier
               OR CAST(u.UniversityId AS CHAR) = @identifier
            LIMIT 1;
            """;
    }

    private static string BuildFindStudentUserSql(UsersSchemaInfo schema)
    {
        const string emailExpression = "COALESCE(NULLIF(TRIM(s.email), ''), NULLIF(TRIM(u.email), ''), '')";
        var fullNameExpression = schema.HasNameColumns
            ? $"COALESCE(NULLIF(TRIM(CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, ''))), ''), {emailExpression})"
            : emailExpression;

        var userIdentifierExpression = BuildUserIdentifierExpression(schema, "u");

        return $"""
            SELECT
                u.id AS UniversityId,
                {emailExpression} AS EmailId,
                COALESCE(u.password_hash, '') AS PasswordHash,
                COALESCE(u.role, '') AS Role,
                {fullNameExpression} AS FullName
            FROM users u
            INNER JOIN students s
                ON COALESCE(s.{schema.StudentIdentifierColumn}, '') = COALESCE({userIdentifierExpression}, '')
            WHERE COALESCE({userIdentifierExpression}, '') = @identifier
              AND LOWER(COALESCE(u.role, '')) = 'student'
              AND COALESCE(u.status, 'active') = 'active'
            LIMIT 1;
            """;
    }

    private static string BuildFindStaffUserSql(UsersSchemaInfo schema)
    {
        const string emailExpression = "COALESCE(NULLIF(TRIM(us.email), ''), NULLIF(TRIM(u.email), ''), '')";
        var fullNameExpression = schema.HasNameColumns
            ? $"COALESCE(NULLIF(TRIM(CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, ''))), ''), {emailExpression})"
            : emailExpression;

        var userIdentifierExpression = BuildUserIdentifierExpression(schema, "u");

        return $"""
            SELECT
                u.id AS UniversityId,
                {emailExpression} AS EmailId,
                COALESCE(u.password_hash, '') AS PasswordHash,
                COALESCE(u.role, '') AS Role,
                {fullNameExpression} AS FullName
            FROM users u
            INNER JOIN university_staff us
                ON COALESCE(us.{schema.StaffIdentifierColumn}, '') = COALESCE({userIdentifierExpression}, '')
            WHERE LOWER(COALESCE(u.email, '')) = LOWER(@identifier)
              AND LOWER(COALESCE(u.role, '')) IN ('staff', 'faculty')
              AND COALESCE(u.status, 'active') = 'active'
            LIMIT 1;
            """;
    }

    private static string BuildUserIdentifierExpression(UsersSchemaInfo schema, string alias)
    {
        if (schema.HasUniversityId && schema.HasUniversityIdSnake && schema.HasEnrollmentNo)
        {
            return $"COALESCE({alias}.UniversityId, {alias}.university_id, {alias}.enrollment_no, CAST({alias}.id AS CHAR))";
        }

        if (schema.HasUniversityId && schema.HasUniversityIdSnake)
        {
            return $"COALESCE({alias}.UniversityId, {alias}.university_id, CAST({alias}.id AS CHAR))";
        }

        if (schema.HasUniversityId && schema.HasEnrollmentNo)
        {
            return $"COALESCE({alias}.UniversityId, {alias}.enrollment_no, CAST({alias}.id AS CHAR))";
        }

        if (schema.HasUniversityIdSnake && schema.HasEnrollmentNo)
        {
            return $"COALESCE({alias}.university_id, {alias}.enrollment_no, CAST({alias}.id AS CHAR))";
        }

        if (schema.HasUniversityId)
        {
            return $"COALESCE({alias}.UniversityId, CAST({alias}.id AS CHAR))";
        }

        if (schema.HasUniversityIdSnake)
        {
            return $"COALESCE({alias}.university_id, CAST({alias}.id AS CHAR))";
        }

        if (schema.HasEnrollmentNo)
        {
            return $"COALESCE({alias}.enrollment_no, CAST({alias}.id AS CHAR))";
        }

        return $"CAST({alias}.id AS CHAR)";
    }

    private static string BuildMarkUserLoggedInSql(UsersSchemaInfo schema)
    {
        if (schema.HasIsLoggedIn)
        {
            return $"UPDATE users SET IsLoggedIn = 1 WHERE {schema.KeyColumn} = @userId;";
        }

        return string.Empty;
    }

    private static string BuildMarkUserLoggedOutSql(UsersSchemaInfo schema)
    {
        if (schema.HasIsLoggedIn)
        {
            return $"UPDATE users SET IsLoggedIn = 0 WHERE {schema.KeyColumn} = @userId;";
        }

        return string.Empty;
    }

    private static async Task<OtpSessionRow?> FindOtpSessionByUserId(
        System.Data.IDbConnection connection,
        int userId,
        CancellationToken cancellationToken)
    {
        return await connection.QuerySingleOrDefaultAsync<OtpSessionRow>(new CommandDefinition(
            """
            SELECT
                COALESCE(otp_code, '') AS OtpCode,
                expires_at AS ExpiresAt,
                created_at AS CreatedAt
            FROM user_otps
            WHERE user_id = @userId
            ORDER BY id DESC
            LIMIT 1;
            """,
            new { userId },
            cancellationToken: cancellationToken));
    }

    private static async Task UpsertOtpSessionAsync(
        System.Data.IDbConnection connection,
        int userId,
        string otpHash,
        DateTime expiryUtc,
        CancellationToken cancellationToken)
    {
        if (connection is System.Data.Common.DbConnection dbConnection
            && dbConnection.State != System.Data.ConnectionState.Open)
        {
            await dbConnection.OpenAsync(cancellationToken);
        }
        else if (connection.State != System.Data.ConnectionState.Open)
        {
            connection.Open();
        }

        using var transaction = connection.BeginTransaction();

        await connection.ExecuteAsync(new CommandDefinition(
            "DELETE FROM user_otps WHERE user_id = @userId;",
            new { userId },
            transaction: transaction,
            cancellationToken: cancellationToken));

        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO user_otps (user_id, otp_code, expires_at, created_at)
            VALUES (@userId, @otpHash, @expiryUtc, UTC_TIMESTAMP());
            """,
            new
            {
                userId,
                otpHash,
                expiryUtc
            },
            transaction: transaction,
            cancellationToken: cancellationToken));

        transaction.Commit();
    }

    private static async Task ClearOtpSessionAsync(
        System.Data.IDbConnection connection,
        int userId,
        CancellationToken cancellationToken)
    {
        await connection.ExecuteAsync(new CommandDefinition(
            "DELETE FROM user_otps WHERE user_id = @userId;",
            new { userId },
            cancellationToken: cancellationToken));
    }

    private static async Task MarkUserLoggedOutAsync(
        System.Data.IDbConnection connection,
        UsersSchemaInfo schema,
        int userId,
        CancellationToken cancellationToken)
    {
        var sql = BuildMarkUserLoggedOutSql(schema);
        if (string.IsNullOrWhiteSpace(sql))
        {
            return;
        }

        await connection.ExecuteAsync(new CommandDefinition(
            sql,
            new { userId },
            cancellationToken: cancellationToken));
    }

    private static async Task MarkUserLoggedInAsync(
        System.Data.IDbConnection connection,
        UsersSchemaInfo schema,
        int userId,
        CancellationToken cancellationToken)
    {
        var sql = BuildMarkUserLoggedInSql(schema);
        if (string.IsNullOrWhiteSpace(sql))
        {
            return;
        }

        await connection.ExecuteAsync(new CommandDefinition(
            sql,
            new { userId },
            cancellationToken: cancellationToken));
    }

    private static string ResolveOtpIdentifier(string requestedIdentifier, UserRow user)
    {
        if (!string.IsNullOrWhiteSpace(requestedIdentifier))
        {
            return requestedIdentifier.Trim();
        }

        if (!string.IsNullOrWhiteSpace(user.EmailId))
        {
            return user.EmailId;
        }

        return user.UniversityId.ToString();
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

        var universityIdCondition =
            (schema.HasUniversityId
                ? "\n               OR COALESCE(u.UniversityId, '') = @identifier"
                : string.Empty)
            + (schema.HasUniversityIdSnake
                ? "\n               OR COALESCE(u.university_id, '') = @identifier"
                : string.Empty);

        var universityIdSelectExpression = schema.HasUniversityId && schema.HasUniversityIdSnake
            ? "COALESCE(u.UniversityId, u.university_id, CAST(u.id AS CHAR))"
            : schema.HasUniversityId
                ? "COALESCE(u.UniversityId, CAST(u.id AS CHAR))"
                : schema.HasUniversityIdSnake
                    ? "COALESCE(u.university_id, CAST(u.id AS CHAR))"
                    : "CAST(u.id AS CHAR)";

        return $"""
            SELECT
                u.id AS Id,
                {universityIdSelectExpression} AS UniversityId,
                COALESCE(u.email, '') AS Email,
                COALESCE(u.role, '') AS Role,
                COALESCE(NULLIF(TRIM(CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, ''))), ''), u.email) AS Name,
                COALESCE(u.first_name, '') AS FirstName,
                COALESCE(u.last_name, '') AS LastName,
                COALESCE(u.contact, '') AS Contact,
                COALESCE(u.department, '') AS Department,
                COALESCE(u.status, '') AS Status,
                COALESCE(u.profile_image_url, '') AS ProfileImageUrl
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
        public bool HasUniversityIdSnake { get; init; }
        public bool HasNameColumns { get; init; }
        public string StudentIdentifierColumn { get; init; } = "UniversityId";
        public string StaffIdentifierColumn { get; init; } = "UniversityId";
    }

    private sealed class UserRow
    {
        public int UniversityId { get; init; }
        public string EmailId { get; init; } = string.Empty;
        public string PasswordHash { get; init; } = string.Empty;
        public string Role { get; init; } = string.Empty;
        public string FullName { get; init; } = string.Empty;
    }

    private sealed class OtpSessionRow
    {
        public string OtpCode { get; init; } = string.Empty;
        public DateTime? ExpiresAt { get; init; }
        public DateTime? CreatedAt { get; init; }
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
