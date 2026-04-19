using System.Security.Claims;
using UniversityCanteen.Api.Models;

namespace UniversityCanteen.Api.Services;

public interface IJwtTokenService
{
    AccessTokenResult GenerateAccessToken(SessionUserDto user);
    ClaimsPrincipal? ValidateToken(string token, bool validateLifetime = true);
    string GenerateRefreshToken();
    string HashRefreshToken(string refreshToken);
    DateTime GetRefreshTokenExpiryUtc();
}

public sealed class AccessTokenResult
{
    public string Token { get; init; } = string.Empty;
    public DateTime ExpiresAtUtc { get; init; }
}
