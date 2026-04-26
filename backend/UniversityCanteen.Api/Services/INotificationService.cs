namespace UniversityCanteen.Api.Services;

public interface INotificationService
{
    Task RegisterDeviceTokenAsync(DeviceTokenRegistrationRequest request, CancellationToken cancellationToken);

    Task<IReadOnlyList<NotificationHistoryItem>> GetHistoryAsync(
        int userId,
        string role,
        int limit,
        bool unreadOnly,
        CancellationToken cancellationToken);

    Task<int> GetUnreadCountAsync(int userId, string role, CancellationToken cancellationToken);

    Task MarkAsReadAsync(long notificationId, int userId, string role, CancellationToken cancellationToken);

    Task<NotificationDispatchSummary> CreateOrScheduleAsync(
        NotificationCreateRequest request,
        CancellationToken cancellationToken);

    Task<int> DispatchDueScheduledAsync(CancellationToken cancellationToken);

    Task NotifyOrderStatusAsync(NotificationOrderStatusRequest request, CancellationToken cancellationToken);

    Task NotifyNewOrderAsync(NotificationNewOrderRequest request, CancellationToken cancellationToken);

    Task NotifySystemMaintenanceAsync(
        bool isActive,
        string message,
        int createdByUserId,
        string createdByRole,
        CancellationToken cancellationToken);

    Task NotifyCanteenMaintenanceAsync(
        int canteenId,
        bool isActive,
        string reason,
        int createdByUserId,
        string createdByRole,
        CancellationToken cancellationToken);
}

public sealed class DeviceTokenRegistrationRequest
{
    public int UserId { get; init; }
    public string Role { get; init; } = string.Empty;
    public string Token { get; init; } = string.Empty;
    public string Platform { get; init; } = "unknown";
}

public sealed class NotificationCreateRequest
{
    public string NotificationType { get; init; } = "alert";
    public string Title { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
    public string TargetScope { get; init; } = "all";
    public int? TargetUserId { get; init; }
    public string? TargetRole { get; init; }
    public int? TargetCanteenId { get; init; }
    public DateTime? ScheduledForUtc { get; init; }
    public IReadOnlyDictionary<string, string>? Data { get; init; }
    public int CreatedByUserId { get; init; }
    public string CreatedByRole { get; init; } = string.Empty;
}

public sealed class NotificationDispatchSummary
{
    public long NotificationId { get; init; }
    public string Status { get; init; } = "pending";
    public int RecipientCount { get; init; }
    public int DeliveredCount { get; init; }
    public int FailedCount { get; init; }
    public int StoredCount { get; init; }
}

public sealed class NotificationHistoryItem
{
    public long Id { get; init; }
    public string NotificationType { get; init; } = string.Empty;
    public string Title { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
    public string DeliveryStatus { get; init; } = "pending";
    public bool IsRead { get; init; }
    public DateTime CreatedAtUtc { get; init; }
    public DateTime? ReadAtUtc { get; init; }
    public IReadOnlyDictionary<string, string> Data { get; init; } = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
}

public sealed class NotificationOrderStatusRequest
{
    public int OrderId { get; init; }
    public string Status { get; init; } = string.Empty;
    public int? EstimatedTime { get; init; }
    public int ChangedByUserId { get; init; }
    public string ChangedByRole { get; init; } = "canteen_admin";
}

public sealed class NotificationNewOrderRequest
{
    public long OrderId { get; init; }
    public string OrderNumber { get; init; } = string.Empty;
    public int UserId { get; init; }
    public string UserRole { get; init; } = "student";
    public string CustomerName { get; init; } = string.Empty;
    public decimal Total { get; init; }
    public int? CanteenId { get; init; }
}
