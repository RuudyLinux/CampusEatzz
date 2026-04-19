namespace UniversityCanteen.Api.Models;

public sealed class ApiLoginResponse
{
    public bool Success { get; init; }
    public string Message { get; init; } = string.Empty;
    public SessionUserDto? Data { get; init; }
    public string? Token { get; init; }
    public DateTime? TokenExpiresAtUtc { get; init; }
    public string? RefreshToken { get; init; }
    public DateTime? RefreshTokenExpiresAtUtc { get; init; }
}
