namespace UniversityCanteen.Api.Models;

public sealed class OtpChallengeResponse
{
    public bool Success { get; init; }
    public string Message { get; init; } = string.Empty;
    public OtpChallengeData? Data { get; init; }
}

public sealed class OtpChallengeData
{
    public string Identifier { get; init; } = string.Empty;
    public int ExpiresInSeconds { get; init; }
    public string? DevelopmentOtp { get; init; }
}
