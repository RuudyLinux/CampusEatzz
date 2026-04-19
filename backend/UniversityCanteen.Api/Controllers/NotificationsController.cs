using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using UniversityCanteen.Api.Data;
using UniversityCanteen.Api.Services;

namespace UniversityCanteen.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/notifications")]
public sealed class NotificationsController(
    IDbConnectionFactory dbConnectionFactory,
    INotificationService notificationService,
    ILogger<NotificationsController> logger) : ControllerBase
{
    [HttpPost("device-token")]
    public async Task<IActionResult> RegisterDeviceToken(
        [FromBody] RegisterDeviceTokenRequest request,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(request.Token))
        {
            return BadRequest(Failure("FCM token is required."));
        }

        var actor = ResolveActor();
        if (actor.UserId <= 0 || string.IsNullOrWhiteSpace(actor.Role))
        {
            return Unauthorized(Failure("Authenticated user context is required."));
        }

        try
        {
            await notificationService.RegisterDeviceTokenAsync(new DeviceTokenRegistrationRequest
            {
                UserId = actor.UserId,
                Role = actor.Role,
                Token = request.Token.Trim(),
                Platform = string.IsNullOrWhiteSpace(request.Platform) ? "unknown" : request.Platform.Trim().ToLowerInvariant()
            }, cancellationToken);

            return Ok(Success("Device registered for notifications.", null!));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(Failure(ex.Message));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to register FCM device token for user {UserId}.", actor.UserId);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while registering device token."));
        }
    }

    [HttpGet("history")]
    public async Task<IActionResult> GetHistory(
        [FromQuery] int limit = 30,
        [FromQuery] bool unreadOnly = false,
        CancellationToken cancellationToken = default)
    {
        var actor = ResolveActor();
        if (actor.UserId <= 0 || string.IsNullOrWhiteSpace(actor.Role))
        {
            return Unauthorized(Failure("Authenticated user context is required."));
        }

        try
        {
            var items = await notificationService.GetHistoryAsync(
                actor.UserId,
                actor.Role,
                limit,
                unreadOnly,
                cancellationToken);

            return Ok(Success("Notifications loaded.", new
            {
                notifications = items.Select(item => new
                {
                    id = item.Id,
                    type = item.NotificationType,
                    title = item.Title,
                    message = item.Message,
                    deliveryStatus = item.DeliveryStatus,
                    isRead = item.IsRead,
                    createdAtUtc = item.CreatedAtUtc,
                    readAtUtc = item.ReadAtUtc,
                    data = item.Data
                }),
                total = items.Count
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to load notification history for user {UserId}.", actor.UserId);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while loading notification history."));
        }
    }

    [HttpGet("unread-count")]
    public async Task<IActionResult> GetUnreadCount(CancellationToken cancellationToken = default)
    {
        var actor = ResolveActor();
        if (actor.UserId <= 0 || string.IsNullOrWhiteSpace(actor.Role))
        {
            return Unauthorized(Failure("Authenticated user context is required."));
        }

        try
        {
            var unread = await notificationService.GetUnreadCountAsync(actor.UserId, actor.Role, cancellationToken);
            return Ok(Success("Unread count loaded.", new { unreadCount = unread }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to load unread notification count for user {UserId}.", actor.UserId);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while loading unread count."));
        }
    }

    [HttpPost("mark-read")]
    public async Task<IActionResult> MarkAsRead(
        [FromBody] MarkReadRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.NotificationId <= 0)
        {
            return BadRequest(Failure("Valid notificationId is required."));
        }

        var actor = ResolveActor();
        if (actor.UserId <= 0 || string.IsNullOrWhiteSpace(actor.Role))
        {
            return Unauthorized(Failure("Authenticated user context is required."));
        }

        try
        {
            await notificationService.MarkAsReadAsync(request.NotificationId, actor.UserId, actor.Role, cancellationToken);
            return Ok(Success("Notification marked as read.", new { notificationId = request.NotificationId }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to mark notification {NotificationId} as read for user {UserId}.", request.NotificationId, actor.UserId);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while updating notification."));
        }
    }

    [HttpPost("admin/send")]
    public async Task<IActionResult> AdminSend(
        [FromBody] AdminNotificationSendRequest request,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(request.Title) || string.IsNullOrWhiteSpace(request.Message))
        {
            return BadRequest(Failure("Title and message are required."));
        }

        var actor = ResolveActor();
        if (actor.UserId <= 0 || !string.Equals(actor.Role, "admin", StringComparison.OrdinalIgnoreCase))
        {
            return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var adminExists = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
                "SELECT COUNT(1) FROM admin_users WHERE id = @id;",
                new { id = actor.UserId },
                cancellationToken: cancellationToken));

            if (adminExists <= 0)
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var result = await notificationService.CreateOrScheduleAsync(new NotificationCreateRequest
            {
                NotificationType = request.NotificationType,
                Title = request.Title,
                Message = request.Message,
                TargetScope = request.TargetScope,
                TargetUserId = request.TargetUserId,
                TargetRole = request.TargetRole,
                TargetCanteenId = request.TargetCanteenId,
                ScheduledForUtc = request.ScheduledForUtc,
                Data = request.Data,
                CreatedByUserId = actor.UserId,
                CreatedByRole = "admin"
            }, cancellationToken);

            return Ok(Success(
                string.Equals(result.Status, "scheduled", StringComparison.OrdinalIgnoreCase)
                    ? "Notification scheduled successfully."
                    : "Notification dispatched successfully.",
                new
                {
                    notificationId = result.NotificationId,
                    status = result.Status,
                    recipients = result.RecipientCount,
                    delivered = result.DeliveredCount,
                    failed = result.FailedCount,
                    stored = result.StoredCount
                }));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(Failure(ex.Message));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to send/schedule admin notification.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while sending notification."));
        }
    }

    private ActorContext ResolveActor()
    {
        var role = User.FindFirstValue(ClaimTypes.Role)
            ?? User.FindFirstValue("role")
            ?? Request.Headers["X-Requester-Role"].FirstOrDefault()
            ?? Request.Query["requesterRole"].FirstOrDefault()
            ?? string.Empty;

        var idRaw = User.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? Request.Headers["X-Requester-Id"].FirstOrDefault()
            ?? Request.Query["requesterId"].FirstOrDefault()
            ?? string.Empty;

        var email = User.FindFirstValue(JwtRegisteredClaimNames.Email)
            ?? User.FindFirstValue(ClaimTypes.Email)
            ?? User.FindFirstValue("email")
            ?? Request.Headers["X-Requester-Email"].FirstOrDefault()
            ?? Request.Query["requesterEmail"].FirstOrDefault()
            ?? string.Empty;

        var userId = 0;
        if (int.TryParse(idRaw, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsedId) && parsedId > 0)
        {
            userId = parsedId;
        }

        return new ActorContext(userId, role.Trim().ToLowerInvariant(), email.Trim().ToLowerInvariant());
    }

    private static object Success(string message, object data)
    {
        return new
        {
            success = true,
            message,
            data
        };
    }

    private static object Failure(string message)
    {
        return new
        {
            success = false,
            message
        };
    }

    private sealed record ActorContext(int UserId, string Role, string Email);

    public sealed class RegisterDeviceTokenRequest
    {
        public string Token { get; init; } = string.Empty;
        public string Platform { get; init; } = "unknown";
    }

    public sealed class MarkReadRequest
    {
        public long NotificationId { get; init; }
    }

    public sealed class AdminNotificationSendRequest
    {
        public string NotificationType { get; init; } = "general_alert";
        public string Title { get; init; } = string.Empty;
        public string Message { get; init; } = string.Empty;
        public string TargetScope { get; init; } = "all";
        public int? TargetUserId { get; init; }
        public string? TargetRole { get; init; }
        public int? TargetCanteenId { get; init; }
        public DateTime? ScheduledForUtc { get; init; }
        public Dictionary<string, string>? Data { get; init; }
    }
}
