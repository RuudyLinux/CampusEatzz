using Microsoft.AspNetCore.Mvc;
using UniversityCanteen.Api.Services;

namespace UniversityCanteen.Api.Controllers;

[ApiController]
[Route("api/chat")]
public sealed class ChatController(
    IAiChatService chatService,
    ILogger<ChatController> logger) : ControllerBase
{
    [HttpPost("message")]
    public async Task<IActionResult> SendMessage(
        [FromBody] ChatMessageRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request is null)
            return BadRequest(new { success = false, message = "Request body is required." });

        var sessionId = (request.SessionId ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(sessionId))
            return BadRequest(new { success = false, message = "sessionId is required." });

        var userMessage = (request.Message ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(userMessage))
            return BadRequest(new { success = false, message = "message is required." });

        try
        {
            var result = await chatService.SendMessageAsync(
                sessionId,
                userMessage,
                request.UserId > 0 ? request.UserId : null,
                cancellationToken);

            if (!result.Success)
            {
                return BadRequest(new
                {
                    success = false,
                    message = result.Error ?? "Failed to process message."
                });
            }

            return Ok(new
            {
                success = true,
                message = "Message processed successfully.",
                data = new
                {
                    sessionId = result.SessionId,
                    response = result.Response,
                    timestamp = result.Timestamp
                }
            });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error processing chat message for session {SessionId}", sessionId);
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                success = false,
                message = "Internal server error while processing chat message."
            });
        }
    }

    [HttpGet("history/{sessionId}")]
    public async Task<IActionResult> GetHistory(
        string sessionId,
        [FromQuery] int limit = 50,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(sessionId))
            return BadRequest(new { success = false, message = "sessionId is required." });

        try
        {
            var messages = await chatService.GetHistoryAsync(
                sessionId.Trim(),
                Math.Clamp(limit, 1, 100),
                cancellationToken);

            return Ok(new
            {
                success = true,
                message = "Chat history fetched successfully.",
                data = new
                {
                    sessionId,
                    messages = messages.Select(m => new
                    {
                        role = m.Role,
                        content = m.Content,
                        timestamp = m.CreatedAt
                    }),
                    total = messages.Count
                }
            });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error fetching chat history for session {SessionId}", sessionId);
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                success = false,
                message = "Internal server error while fetching chat history."
            });
        }
    }
}

public sealed class ChatMessageRequest
{
    public string? SessionId { get; init; }
    public string? Message { get; init; }
    public int UserId { get; init; }
}
