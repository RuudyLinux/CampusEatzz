using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using UniversityCanteen.Api.Configuration;
using UniversityCanteen.Api.Models;

namespace UniversityCanteen.Api.Services;

public sealed class JwtTokenService(IOptions<JwtOptions> jwtOptions) : IJwtTokenService
{
    private const string FallbackSecret = "UniversityCanteen-DefaultSecret-ChangeInProduction!";

    private readonly JwtOptions _jwtOptions = jwtOptions.Value;

    public static string ResolveSecret(string? configuredSecret)
    {
        return string.IsNullOrWhiteSpace(configuredSecret)
            ? FallbackSecret
            : configuredSecret.Trim();
    }

    public AccessTokenResult GenerateAccessToken(SessionUserDto user)
    {
        var secret = ResolveSecret(_jwtOptions.Secret);
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var expiresAtUtc = DateTime.UtcNow.AddHours(Math.Clamp(_jwtOptions.ExpiryHours, 1, 168));

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString(CultureInfo.InvariantCulture)),
            new(JwtRegisteredClaimNames.Email, user.Email),
            new(ClaimTypes.Role, user.Role),
            new(ClaimTypes.Name, user.Name),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        if (!string.IsNullOrWhiteSpace(user.UniversityId))
        {
            claims.Add(new Claim("universityId", user.UniversityId));
        }

        var jwt = new JwtSecurityToken(
            issuer: _jwtOptions.Issuer,
            audience: _jwtOptions.Audience,
            claims: claims,
            expires: expiresAtUtc,
            signingCredentials: creds);

        return new AccessTokenResult
        {
            Token = new JwtSecurityTokenHandler().WriteToken(jwt),
            ExpiresAtUtc = expiresAtUtc
        };
    }

    public ClaimsPrincipal? ValidateToken(string token, bool validateLifetime = true)
    {
        if (string.IsNullOrWhiteSpace(token))
        {
            return null;
        }

        var secret = ResolveSecret(_jwtOptions.Secret);
        var tokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = validateLifetime,
            ValidateIssuerSigningKey = true,
            ValidIssuer = _jwtOptions.Issuer,
            ValidAudience = _jwtOptions.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret)),
            ClockSkew = TimeSpan.FromMinutes(1)
        };

        try
        {
            var handler = new JwtSecurityTokenHandler();
            return handler.ValidateToken(token, tokenValidationParameters, out _);
        }
        catch
        {
            return null;
        }
    }

    public string GenerateRefreshToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(64);
        return Convert.ToBase64String(bytes);
    }

    public string HashRefreshToken(string refreshToken)
    {
        var normalized = refreshToken?.Trim() ?? string.Empty;
        var bytes = Encoding.UTF8.GetBytes(normalized);
        var hash = SHA256.HashData(bytes);
        return Convert.ToHexString(hash);
    }

    public DateTime GetRefreshTokenExpiryUtc()
    {
        var refreshDays = Math.Clamp(_jwtOptions.RefreshTokenDays, 1, 60);
        return DateTime.UtcNow.AddDays(refreshDays);
    }
}
