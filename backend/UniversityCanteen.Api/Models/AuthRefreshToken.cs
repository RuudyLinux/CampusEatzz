namespace UniversityCanteen.Api.Models;

public sealed class AuthRefreshToken
{
    public long Id { get; init; }
    public int UserId { get; init; }
    public string Role { get; init; } = string.Empty;
    public string TokenHash { get; init; } = string.Empty;
    public DateTime ExpiresAtUtc { get; init; }
    public DateTime CreatedAtUtc { get; init; }
    public DateTime? RevokedAtUtc { get; init; }
}
