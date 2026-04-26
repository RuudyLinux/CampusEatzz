namespace UniversityCanteen.Api.Services;

public interface IAiChatService
{
    Task<ChatReplyResult> SendMessageAsync(string sessionId, string userMessage, int? userId, CancellationToken ct);
    Task<IReadOnlyList<ChatMessageItem>> GetHistoryAsync(string sessionId, int limit, CancellationToken ct);
}

public sealed record ChatReplyResult(bool Success, string Response, string SessionId, DateTime Timestamp, string? Error = null);

public sealed record ChatMessageItem(string Role, string Content, DateTime CreatedAt);
