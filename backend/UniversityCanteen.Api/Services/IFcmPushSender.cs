namespace UniversityCanteen.Api.Services;

public interface IFcmPushSender
{
    Task<FcmSendResult> SendToTokensAsync(
        string title,
        string body,
        IReadOnlyDictionary<string, string> data,
        IReadOnlyCollection<string> tokens,
        CancellationToken cancellationToken);
}

public sealed class FcmSendResult
{
    public static FcmSendResult Disabled(string reason) => new()
    {
        Enabled = false,
        SuccessCount = 0,
        FailureCount = 0,
        Error = reason
    };

    public static FcmSendResult Empty() => new()
    {
        Enabled = true,
        SuccessCount = 0,
        FailureCount = 0,
    };

    public bool Enabled { get; init; }
    public int SuccessCount { get; init; }
    public int FailureCount { get; init; }
    public string? Error { get; init; }
}
