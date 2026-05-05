using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using UniversityCanteen.Api.Data;
using UniversityCanteen.Api.Models;
using UniversityCanteen.Api.Services;

namespace UniversityCanteen.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthApiController(
    UniversityCanteenDbContext dbContext,
    IJwtTokenService jwtTokenService,
    ILogger<AuthApiController> logger) : ControllerBase
{
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] AuthLoginApiRequest request, CancellationToken cancellationToken)
    {
        var loginType = (request.LoginType ?? string.Empty).Trim();

        if (string.Equals(loginType, "admin", StringComparison.OrdinalIgnoreCase))
        {
            return await LoginAdminInternal(request.Identifier, request.Password, cancellationToken);
        }

        return await LoginUserInternal(request.Identifier, request.Password, cancellationToken);
    }

    [HttpPost("admin/login")]
    public async Task<IActionResult> AdminLogin([FromBody] AdminLoginApiRequest request, CancellationToken cancellationToken)
    {
        return await LoginAdminInternal(request.Identifier, request.Password, cancellationToken);
    }

    [HttpPost("user/login")]
    public async Task<IActionResult> UserLogin([FromBody] UserLoginApiRequest request, CancellationToken cancellationToken)
    {
        return await LoginUserInternal(request.Identifier, request.Password, cancellationToken);
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh([FromBody] RefreshTokenApiRequest request, CancellationToken cancellationToken)
    {
        var refreshToken = (request.RefreshToken ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(refreshToken))
        {
            return BadRequest(Failure("Refresh token is required."));
        }

        try
        {
            var refreshTokenHash = jwtTokenService.HashRefreshToken(refreshToken);
            var existingToken = await dbContext.FindRefreshTokenByHashAsync(refreshTokenHash, cancellationToken);
            if (existingToken is null
                || existingToken.RevokedAtUtc.HasValue
                || existingToken.ExpiresAtUtc <= DateTime.UtcNow)
            {
                return Unauthorized(Failure("Refresh token is invalid or expired."));
            }

            var sessionUser = await dbContext.BuildSessionUserAsync(existingToken.UserId, existingToken.Role, cancellationToken);
            if (sessionUser is null)
            {
                await dbContext.RevokeRefreshTokenAsync(refreshTokenHash, cancellationToken);
                return Unauthorized(Failure("Session no longer exists."));
            }

            await dbContext.RevokeRefreshTokenAsync(refreshTokenHash, cancellationToken);
            var refreshedResponse = await BuildLoginResponseAsync(
                sessionUser,
                "Token refreshed successfully.",
                cancellationToken);

            return Ok(refreshedResponse);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Refresh token flow failed.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error during token refresh."));
        }
    }

    [Authorize]
    [HttpGet("profile")]
    public IActionResult Profile()
    {
        var subject = User.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? string.Empty;

        var email = User.FindFirstValue(JwtRegisteredClaimNames.Email)
            ?? User.FindFirstValue(ClaimTypes.Email)
            ?? string.Empty;

        var role = User.FindFirstValue(ClaimTypes.Role) ?? string.Empty;
        var name = User.FindFirstValue(ClaimTypes.Name) ?? string.Empty;
        var universityId = User.FindFirstValue("universityId") ?? string.Empty;

        return Ok(new
        {
            success = true,
            message = "Profile fetched successfully.",
            data = new
            {
                id = subject,
                email,
                role,
                name,
                universityId
            }
        });
    }

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout([FromBody] LogoutApiRequest request, CancellationToken cancellationToken)
    {
        var subject = User.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? User.FindFirstValue(ClaimTypes.NameIdentifier);
        var role = User.FindFirstValue(ClaimTypes.Role);

        if (int.TryParse(subject, NumberStyles.Integer, CultureInfo.InvariantCulture, out var userId)
            && !string.IsNullOrWhiteSpace(role))
        {
            await dbContext.RevokeRefreshTokensAsync(userId, role, cancellationToken);
        }

        var refreshToken = (request.RefreshToken ?? string.Empty).Trim();
        if (!string.IsNullOrWhiteSpace(refreshToken))
        {
            await dbContext.RevokeRefreshTokenAsync(jwtTokenService.HashRefreshToken(refreshToken), cancellationToken);
        }

        return Ok(new
        {
            success = true,
            message = "Logout successful. Clear access token on the client."
        });
    }

    private async Task<IActionResult> LoginAdminInternal(string identifierInput, string passwordInput, CancellationToken cancellationToken)
    {
        var identifier = (identifierInput ?? string.Empty).Trim();
        var password = passwordInput ?? string.Empty;

        if (string.IsNullOrWhiteSpace(identifier) || string.IsNullOrWhiteSpace(password))
        {
            return BadRequest(Failure("Identifier and password are required."));
        }

        try
        {
            var admin = await dbContext.FindAdminByIdentifierAsync(identifier, cancellationToken);
            if (admin is null || !VerifyPassword(password, admin.Password))
            {
                return Unauthorized(Failure("Invalid admin credentials"));
            }

            var session = new SessionUserDto
            {
                Id = admin.Id,
                Name = string.IsNullOrWhiteSpace(admin.Name) ? admin.Email : admin.Name,
                Email = admin.Email,
                Role = "admin"
            };

            var response = await BuildLoginResponseAsync(session, "Admin login successful.", cancellationToken);
            return Ok(response);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Admin login failed for identifier {Identifier}.", identifier);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error during admin login."));
        }
    }

    private async Task<IActionResult> LoginUserInternal(string identifierInput, string passwordInput, CancellationToken cancellationToken)
    {
        var identifier = (identifierInput ?? string.Empty).Trim();
        var password = passwordInput ?? string.Empty;

        if (string.IsNullOrWhiteSpace(identifier) || string.IsNullOrWhiteSpace(password))
        {
            return BadRequest(Failure("Identifier and password are required."));
        }

        try
        {
            if (LooksLikeEmail(identifier))
            {
                var staffCredential = await dbContext.FindStaffCredentialByEmailAsync(identifier, cancellationToken);
                if (staffCredential is null || !VerifyPassword(password, staffCredential.PasswordHash))
                {
                    return Unauthorized(Failure("Invalid user credentials"));
                }

                var staffProfile = await dbContext.FindUniversityStaffByUniversityIdAsync(staffCredential.UniversityId, cancellationToken);
                if (staffProfile is null)
                {
                    return NotFound(Failure("No such user exists"));
                }

                var staffFullName = string.Join(' ', new[] { staffCredential.FirstName, staffCredential.LastName }
                    .Where(value => !string.IsNullOrWhiteSpace(value)));

                var staffSession = new SessionUserDto
                {
                    Id = staffCredential.Id,
                    UniversityId = staffCredential.UniversityId,
                    Name = string.IsNullOrWhiteSpace(staffFullName) ? staffCredential.Email : staffFullName,
                    Email = staffCredential.Email,
                    Role = "staff",
                    FirstName = staffCredential.FirstName,
                    LastName = staffCredential.LastName,
                    Contact = staffCredential.Contact,
                    Department = staffCredential.Department,
                    Status = staffCredential.Status
                };

                var staffResponse = await BuildLoginResponseAsync(staffSession, "User login successful.", cancellationToken);
                return Ok(staffResponse);
            }

            var student = await dbContext.FindStudentByUniversityIdAsync(identifier, cancellationToken);
            if (student is null)
            {
                return NotFound(Failure("No such user exists"));
            }

            var expectedRole = "student";
            var credential = await dbContext.FindUserCredentialByUniversityIdAsync(identifier, cancellationToken);

            if (credential is null
                || !string.Equals(credential.Role, expectedRole, StringComparison.OrdinalIgnoreCase)
                || !VerifyPassword(password, credential.PasswordHash))
            {
                return Unauthorized(Failure("Invalid user credentials"));
            }

            var fullName = string.Join(' ', new[] { credential.FirstName, credential.LastName }
                .Where(value => !string.IsNullOrWhiteSpace(value)));

            var session = new SessionUserDto
            {
                Id = credential.Id,
                UniversityId = credential.UniversityId,
                Name = string.IsNullOrWhiteSpace(fullName) ? credential.UniversityId : fullName,
                Email = credential.Email,
                Role = expectedRole,
                FirstName = credential.FirstName,
                LastName = credential.LastName,
                Contact = credential.Contact,
                Department = credential.Department,
                Status = credential.Status
            };

            var response = await BuildLoginResponseAsync(session, "User login successful.", cancellationToken);
            return Ok(response);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "User login failed for identifier {Identifier}.", identifier);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error during user login."));
        }
    }

    private static bool LooksLikeEmail(string identifier)
    {
        return identifier.Contains('@', StringComparison.Ordinal);
    }

    private async Task<ApiLoginResponse> BuildLoginResponseAsync(
        SessionUserDto session,
        string message,
        CancellationToken cancellationToken)
    {
        var accessToken = jwtTokenService.GenerateAccessToken(session);

        var refreshToken = jwtTokenService.GenerateRefreshToken();
        var refreshTokenHash = jwtTokenService.HashRefreshToken(refreshToken);
        var refreshTokenExpiresAtUtc = jwtTokenService.GetRefreshTokenExpiryUtc();

        await dbContext.SaveRefreshTokenAsync(new AuthRefreshToken
        {
            UserId = session.Id,
            Role = session.Role,
            TokenHash = refreshTokenHash,
            ExpiresAtUtc = refreshTokenExpiresAtUtc
        }, cancellationToken);

        return Success(
            message,
            session,
            accessToken.Token,
            accessToken.ExpiresAtUtc,
            refreshToken,
            refreshTokenExpiresAtUtc);
    }

    private static bool VerifyPassword(string inputPassword, string storedPassword)
    {
        if (string.IsNullOrWhiteSpace(storedPassword))
        {
            return false;
        }

        var normalizedInput = inputPassword ?? string.Empty;

        if (storedPassword.StartsWith("$2", StringComparison.Ordinal))
        {
            try
            {
                return BCrypt.Net.BCrypt.Verify(normalizedInput, storedPassword);
            }
            catch
            {
                return false;
            }
        }

        return string.Equals(normalizedInput, storedPassword, StringComparison.Ordinal);
    }

    private static ApiLoginResponse Success(
        string message,
        SessionUserDto data,
        string token,
        DateTime tokenExpiresAtUtc,
        string refreshToken,
        DateTime refreshTokenExpiresAtUtc) => new()
    {
        Success = true,
        Message = message,
        Data = data,
        Token = token,
        TokenExpiresAtUtc = tokenExpiresAtUtc,
        RefreshToken = refreshToken,
        RefreshTokenExpiresAtUtc = refreshTokenExpiresAtUtc
    };

    private static ApiLoginResponse Failure(string message) => new()
    {
        Success = false,
        Message = message
    };
}
