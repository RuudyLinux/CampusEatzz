namespace UniversityCanteen.Api.Services;

public interface IAiChatService
{
    Task<ChatReplyResult> SendMessageAsync(string sessionId, string userMessage, int? userId, string? userName, CancellationToken ct);
    Task<IReadOnlyList<ChatMessageItem>> GetHistoryAsync(string sessionId, int limit, CancellationToken ct);
}

public sealed record ChatReplyResult(
    bool Success,
    string Response,
    string SessionId,
    DateTime Timestamp,
    string? Error = null,
    string? Intent = null,
    string? Action = null,
    int? CanteenId = null,
    string? CanteenName = null);

public sealed record ChatMessageItem(string Role, string Content, DateTime CreatedAt);
