using System.Text.Json;
using System.Net;
using System.Net.Mail;
using System.Globalization;
using Dapper;
using Microsoft.Extensions.Options;
using UniversityCanteen.Api.Configuration;
using UniversityCanteen.Api.Data;

namespace UniversityCanteen.Api.Services;

public sealed class NotificationService(
    IDbConnectionFactory dbConnectionFactory,
    IFcmPushSender fcmPushSender,
    IOptions<SmtpOptions> smtpOptions,
    ILogger<NotificationService> logger) : INotificationService
{
    private readonly SmtpOptions _smtpOptions = smtpOptions.Value;

    public async Task RegisterDeviceTokenAsync(DeviceTokenRegistrationRequest request, CancellationToken cancellationToken)
    {
        var role = NormalizeRole(request.Role);
        var token = (request.Token ?? string.Empty).Trim();
        var platform = (request.Platform ?? string.Empty).Trim().ToLowerInvariant();

        if (request.UserId <= 0)
        {
            throw new InvalidOperationException("Valid user id is required to register device token.");
        }

        if (string.IsNullOrWhiteSpace(role))
        {
            throw new InvalidOperationException("Valid role is required to register device token.");
        }

        if (token.Length < 20)
        {
            throw new InvalidOperationException("Invalid FCM token supplied.");
        }

        using var connection = dbConnectionFactory.CreateConnection();
        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO user_device_tokens (user_id, role, token, platform, is_active, created_at_utc, updated_at_utc, last_seen_utc)
            VALUES (@userId, @role, @token, @platform, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP(), UTC_TIMESTAMP())
            ON DUPLICATE KEY UPDATE
                user_id = VALUES(user_id),
                role = VALUES(role),
                platform = VALUES(platform),
                is_active = 1,
                updated_at_utc = UTC_TIMESTAMP(),
                last_seen_utc = UTC_TIMESTAMP();
            """,
            new
            {
                userId = request.UserId,
                role,
                token,
                platform = string.IsNullOrWhiteSpace(platform) ? "unknown" : platform
            },
            cancellationToken: cancellationToken));
    }

    public async Task<IReadOnlyList<NotificationHistoryItem>> GetHistoryAsync(
        int userId,
        string role,
        int limit,
        bool unreadOnly,
        CancellationToken cancellationToken)
    {
        var normalizedRole = NormalizeRole(role);
        if (userId <= 0 || string.IsNullOrWhiteSpace(normalizedRole))
        {
            return [];
        }

        var normalizedLimit = Math.Clamp(limit, 1, 200);

        using var connection = dbConnectionFactory.CreateConnection();
        var rows = await connection.QueryAsync<NotificationHistoryRow>(new CommandDefinition(
            """
            SELECT
                n.id AS Id,
                COALESCE(n.notification_type, 'alert') AS NotificationType,
                COALESCE(n.title, '') AS Title,
                COALESCE(n.message, '') AS Message,
                COALESCE(n.payload_json, '{}') AS PayloadJson,
                COALESCE(r.delivery_status, 'pending') AS DeliveryStatus,
                r.read_at_utc AS ReadAtUtc,
                COALESCE(n.created_at_utc, UTC_TIMESTAMP()) AS CreatedAtUtc
            FROM app_notification_recipients r
            INNER JOIN app_notifications n ON n.id = r.notification_id
            WHERE r.recipient_user_id = @userId
              AND LOWER(COALESCE(r.recipient_role, '')) = @role
              AND (@unreadOnly = 0 OR r.read_at_utc IS NULL)
            ORDER BY n.created_at_utc DESC
            LIMIT @limit;
            """,
            new
            {
                userId,
                role = normalizedRole,
                unreadOnly = unreadOnly ? 1 : 0,
                limit = normalizedLimit
            },
            cancellationToken: cancellationToken));

        return rows.Select(row => new NotificationHistoryItem
        {
            Id = row.Id,
            NotificationType = row.NotificationType,
            Title = row.Title,
            Message = row.Message,
            DeliveryStatus = row.DeliveryStatus,
            IsRead = row.ReadAtUtc.HasValue,
            CreatedAtUtc = row.CreatedAtUtc,
            ReadAtUtc = row.ReadAtUtc,
            Data = ParsePayload(row.PayloadJson)
        }).ToList();
    }

    public async Task<int> GetUnreadCountAsync(int userId, string role, CancellationToken cancellationToken)
    {
        var normalizedRole = NormalizeRole(role);
        if (userId <= 0 || string.IsNullOrWhiteSpace(normalizedRole))
        {
            return 0;
        }

        using var connection = dbConnectionFactory.CreateConnection();
        return await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            """
            SELECT COUNT(1)
            FROM app_notification_recipients
            WHERE recipient_user_id = @userId
              AND LOWER(COALESCE(recipient_role, '')) = @role
              AND read_at_utc IS NULL;
            """,
            new
            {
                userId,
                role = normalizedRole
            },
            cancellationToken: cancellationToken));
    }

    public async Task MarkAsReadAsync(long notificationId, int userId, string role, CancellationToken cancellationToken)
    {
        var normalizedRole = NormalizeRole(role);
        if (notificationId <= 0 || userId <= 0 || string.IsNullOrWhiteSpace(normalizedRole))
        {
            return;
        }

        using var connection = dbConnectionFactory.CreateConnection();
        await connection.ExecuteAsync(new CommandDefinition(
            """
            UPDATE app_notification_recipients
            SET read_at_utc = COALESCE(read_at_utc, UTC_TIMESTAMP())
            WHERE notification_id = @notificationId
              AND recipient_user_id = @userId
              AND LOWER(COALESCE(recipient_role, '')) = @role;
            """,
            new
            {
                notificationId,
                userId,
                role = normalizedRole
            },
            cancellationToken: cancellationToken));
    }

    public async Task<NotificationDispatchSummary> CreateOrScheduleAsync(
        NotificationCreateRequest request,
        CancellationToken cancellationToken)
    {
        var normalizedScope = NormalizeScope(request.TargetScope);
        var normalizedType = NormalizeType(request.NotificationType);
        var normalizedTargetRole = NormalizeRole(request.TargetRole ?? string.Empty);
        var normalizedCreatorRole = NormalizeRole(request.CreatedByRole);

        if (string.IsNullOrWhiteSpace(request.Title) || string.IsNullOrWhiteSpace(request.Message))
        {
            throw new InvalidOperationException("Notification title and message are required.");
        }

        ValidateTarget(normalizedScope, request.TargetUserId, normalizedTargetRole, request.TargetCanteenId);

        var scheduledForUtc = request.ScheduledForUtc?.ToUniversalTime();
        var shouldSchedule = scheduledForUtc.HasValue && scheduledForUtc.Value > DateTime.UtcNow.AddSeconds(5);
        var payloadJson = JsonSerializer.Serialize(request.Data ?? new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase));

        using var connection = dbConnectionFactory.CreateConnection();
        var notificationId = await connection.ExecuteScalarAsync<long>(new CommandDefinition(
            """
            INSERT INTO app_notifications
                (notification_type, title, message, payload_json, target_scope, target_user_id, target_role, target_canteen_id,
                 scheduled_for_utc, status, created_by_user_id, created_by_role, created_at_utc)
            VALUES
                (@notificationType, @title, @message, @payloadJson, @targetScope, @targetUserId, @targetRole, @targetCanteenId,
                 @scheduledForUtc, @status, @createdByUserId, @createdByRole, UTC_TIMESTAMP());
            SELECT LAST_INSERT_ID();
            """,
            new
            {
                notificationType = normalizedType,
                title = request.Title.Trim(),
                message = request.Message.Trim(),
                payloadJson,
                targetScope = normalizedScope,
                targetUserId = request.TargetUserId,
                targetRole = string.IsNullOrWhiteSpace(normalizedTargetRole) ? null : normalizedTargetRole,
                targetCanteenId = request.TargetCanteenId,
                scheduledForUtc,
                status = shouldSchedule ? "scheduled" : "pending",
                createdByUserId = request.CreatedByUserId <= 0 ? (int?)null : request.CreatedByUserId,
                createdByRole = string.IsNullOrWhiteSpace(normalizedCreatorRole) ? null : normalizedCreatorRole
            },
            cancellationToken: cancellationToken));

        if (shouldSchedule)
        {
            return new NotificationDispatchSummary
            {
                NotificationId = notificationId,
                Status = "scheduled"
            };
        }

        return await DispatchNotificationByIdAsync(notificationId, cancellationToken);
    }

    public async Task<int> DispatchDueScheduledAsync(CancellationToken cancellationToken)
    {
        using var connection = dbConnectionFactory.CreateConnection();
        var ids = (await connection.QueryAsync<long>(new CommandDefinition(
            """
            SELECT id
            FROM app_notifications
            WHERE status = 'scheduled'
              AND scheduled_for_utc IS NOT NULL
              AND scheduled_for_utc <= UTC_TIMESTAMP()
            ORDER BY scheduled_for_utc ASC
            LIMIT 30;
            """,
            cancellationToken: cancellationToken))).ToList();

        var processed = 0;
        foreach (var id in ids)
        {
            var result = await DispatchNotificationByIdAsync(id, cancellationToken);
            if (!string.Equals(result.Status, "scheduled", StringComparison.OrdinalIgnoreCase))
            {
                processed++;
            }
        }

        return processed;
    }

    public async Task NotifyOrderStatusAsync(NotificationOrderStatusRequest request, CancellationToken cancellationToken)
    {
        if (request.OrderId <= 0)
        {
            return;
        }

        using var connection = dbConnectionFactory.CreateConnection();
        var order = await connection.QuerySingleOrDefaultAsync<OrderNotificationRow>(new CommandDefinition(
            """
            SELECT
                o.id AS OrderId,
                o.order_number AS OrderNumber,
                o.user_id AS UserId,
                COALESCE(u.role, 'student') AS UserRole,
                COALESCE(u.email, '') AS UserEmail,
                COALESCE(NULLIF(TRIM(CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, ''))), ''), u.email, 'Customer') AS UserName,
                COALESCE(o.total_amount, 0.00) AS Subtotal,
                COALESCE(o.tax_amount, 0.00) AS Tax,
                COALESCE(o.final_amount, 0.00) AS Total,
                COALESCE(o.payment_method, 'cash') AS PaymentMethod,
                COALESCE(o.payment_status, 'pending') AS PaymentStatus,
                o.created_at AS CreatedAt,
                o.completed_at AS CompletedAt,
                COALESCE(c.name, 'Canteen') AS CanteenName
            FROM orders o
            INNER JOIN users u ON u.id = o.user_id
            LEFT JOIN canteens c ON c.id = o.canteen_id
            WHERE o.id = @orderId
            LIMIT 1;
            """,
            new { orderId = request.OrderId },
            cancellationToken: cancellationToken));

        if (order is null || order.UserId <= 0)
        {
            return;
        }

        var normalizedStatus = NormalizeOrderStatus(request.Status);
        var (title, body, action) = normalizedStatus switch
        {
            "pending" => (
                "Order Pending",
                $"Your order #{order.OrderNumber} is pending confirmation.",
                "order_details"),
            "confirmed" => (
                "Order Confirmed",
                $"Your order #{order.OrderNumber} has been confirmed by {order.CanteenName}.",
                "order_details"),
            "preparing" => (
                "Order Preparing",
                $"Your order #{order.OrderNumber} is being prepared.",
                "order_details"),
            "ready" => (
                "Ready for Pickup",
                $"Your order #{order.OrderNumber} is ready for pickup.",
                "order_details"),
            "completed" => (
                "Order Completed",
                $"Your order #{order.OrderNumber} is completed. Please share your feedback.",
                "feedback"),
            _ => (
                "Order Update",
                $"Your order #{order.OrderNumber} status changed to {normalizedStatus}.",
                "order_details")
        };

        var data = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["action"] = action,
            ["orderRef"] = order.OrderNumber,
            ["orderId"] = request.OrderId.ToString(),
            ["status"] = normalizedStatus,
        };

        if (request.EstimatedTime.HasValue)
        {
            data["estimatedTime"] = request.EstimatedTime.Value.ToString();
        }

        await CreateOrScheduleAsync(new NotificationCreateRequest
        {
            NotificationType = "order_update",
            Title = title,
            Message = body,
            TargetScope = "user",
            TargetUserId = order.UserId,
            TargetRole = order.UserRole,
            Data = data,
            CreatedByUserId = request.ChangedByUserId,
            CreatedByRole = request.ChangedByRole,
        }, cancellationToken);

        await TrySendOrderStatusEmailAsync(connection, order, normalizedStatus, cancellationToken);
    }

    private async Task TrySendOrderStatusEmailAsync(
        System.Data.IDbConnection connection,
        OrderNotificationRow order,
        string normalizedStatus,
        CancellationToken cancellationToken)
    {
        var toEmail = (order.UserEmail ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(toEmail) || !IsSmtpConfigured())
        {
            return;
        }

        cancellationToken.ThrowIfCancellationRequested();

        var completed = string.Equals(normalizedStatus, "completed", StringComparison.OrdinalIgnoreCase);
        var items = new List<OrderBillItemRow>();
        if (completed)
        {
            items = (await connection.QueryAsync<OrderBillItemRow>(new CommandDefinition(
                """
                SELECT
                    COALESCE(item_name, 'Item') AS ItemName,
                    COALESCE(quantity, 1) AS Quantity,
                    COALESCE(unit_price, 0.00) AS UnitPrice,
                    COALESCE(total_price, 0.00) AS TotalPrice
                FROM order_items
                WHERE order_id = @orderId
                ORDER BY id ASC;
                """,
                new { orderId = order.OrderId },
                cancellationToken: cancellationToken))).ToList();
        }

        var appPassword = new string((_smtpOptions.Password ?? string.Empty)
            .Where(ch => !char.IsWhiteSpace(ch))
            .ToArray());

        try
        {
            if (completed)
            {
                var feedbackFormUrl = BuildFeedbackFormUrl(order);

                await SendEmailAsync(
                    toEmail,
                    $"Order Bill - #{order.OrderNumber}",
                    BuildCompletedOrderEmailHtmlBody(order, items),
                    appPassword,
                    cancellationToken);

                logger.LogInformation(
                    "Order bill email delivered to {Email} for order {OrderNumber}",
                    toEmail,
                    order.OrderNumber);

                await SendEmailAsync(
                    toEmail,
                    $"Share Your Feedback - Order #{order.OrderNumber}",
                    BuildFeedbackRequestEmailHtmlBody(order, feedbackFormUrl),
                    appPassword,
                    cancellationToken);

                logger.LogInformation(
                    "Feedback request email delivered to {Email} for order {OrderNumber}",
                    toEmail,
                    order.OrderNumber);
            }
            else
            {
                await SendEmailAsync(
                    toEmail,
                    $"Order Status Update - #{order.OrderNumber}",
                    BuildOrderStatusEmailHtmlBody(order, normalizedStatus),
                    appPassword,
                    cancellationToken);

                logger.LogInformation(
                    "Order status email delivered to {Email} for order {OrderNumber} with status {Status}",
                    toEmail,
                    order.OrderNumber,
                    normalizedStatus);
            }
        }
        catch (SmtpException ex)
        {
            logger.LogWarning(
                ex,
                "Failed to deliver order status email to {Email} for order {OrderNumber} with status {Status}",
                toEmail,
                order.OrderNumber,
                normalizedStatus);
        }
    }

    private async Task SendEmailAsync(
        string toEmail,
        string subject,
        string body,
        string appPassword,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        using var message = new MailMessage
        {
            From = new MailAddress(_smtpOptions.FromEmail, _smtpOptions.FromName),
            Subject = subject,
            IsBodyHtml = true,
            Body = body
        };
        message.To.Add(toEmail);

        using var client = new SmtpClient(_smtpOptions.Host, _smtpOptions.Port)
        {
            EnableSsl = _smtpOptions.EnableSsl,
            UseDefaultCredentials = false,
            DeliveryMethod = SmtpDeliveryMethod.Network,
            Credentials = new NetworkCredential(_smtpOptions.UserName, appPassword)
        };

        await client.SendMailAsync(message);
    }

    private string BuildFeedbackFormUrl(OrderNotificationRow order)
    {
        var baseUrl = (_smtpOptions.FeedbackFormBaseUrl ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            return string.Empty;
        }

        var separator = baseUrl.Contains('?', StringComparison.Ordinal) ? "&" : "?";
        var orderRef = Uri.EscapeDataString(order.OrderNumber ?? string.Empty);
        var email = Uri.EscapeDataString(order.UserEmail ?? string.Empty);
        return $"{baseUrl}{separator}orderRef={orderRef}&email={email}";
    }

    private bool IsSmtpConfigured()
    {
        return !string.IsNullOrWhiteSpace(_smtpOptions.Host)
            && !string.IsNullOrWhiteSpace(_smtpOptions.UserName)
            && !string.IsNullOrWhiteSpace(_smtpOptions.Password)
            && !string.IsNullOrWhiteSpace(_smtpOptions.FromEmail);
    }

    private static string BuildCompletedOrderEmailHtmlBody(OrderNotificationRow order, IReadOnlyList<OrderBillItemRow> items)
    {
        var safeOrder = WebUtility.HtmlEncode(order.OrderNumber);
        var safeName = WebUtility.HtmlEncode(string.IsNullOrWhiteSpace(order.UserName) ? "Customer" : order.UserName);
        var safeCanteen = WebUtility.HtmlEncode(string.IsNullOrWhiteSpace(order.CanteenName) ? "CampusEatzz Canteen" : order.CanteenName);
        var createdAt = order.CreatedAt.ToLocalTime().ToString("dd MMM yyyy hh:mm tt", CultureInfo.InvariantCulture);
        var completedAt = (order.CompletedAt ?? DateTime.UtcNow).ToLocalTime().ToString("dd MMM yyyy hh:mm tt", CultureInfo.InvariantCulture);

        var rowsHtml = items.Count == 0
            ? "<tr><td colspan=\"4\" style=\"padding:10px 12px;border-bottom:1px solid #e5e7eb;color:#64748b;\">Item details are unavailable for this order.</td></tr>"
            : string.Join(string.Empty, items.Select((item, index) =>
                $"<tr>" +
                $"<td style=\"padding:10px 12px;border-bottom:1px solid #e5e7eb;color:#17253f;\">{index + 1}. {WebUtility.HtmlEncode(item.ItemName)}</td>" +
                $"<td style=\"padding:10px 12px;border-bottom:1px solid #e5e7eb;text-align:center;color:#17253f;\">{item.Quantity}</td>" +
                $"<td style=\"padding:10px 12px;border-bottom:1px solid #e5e7eb;text-align:right;color:#17253f;\">INR {item.UnitPrice:0.00}</td>" +
                $"<td style=\"padding:10px 12px;border-bottom:1px solid #e5e7eb;text-align:right;color:#17253f;font-weight:600;\">INR {item.TotalPrice:0.00}</td>" +
                $"</tr>"));

        var paymentMethod = WebUtility.HtmlEncode(ToTitleCaseLabel(order.PaymentMethod));
        var paymentStatus = WebUtility.HtmlEncode(ToTitleCaseLabel(order.PaymentStatus));

        return $"""
            <div style="font-family:Segoe UI,Arial,sans-serif;max-width:680px;margin:0 auto;background:#f5f9ff;padding:24px;color:#17253f;">
                <div style="background:linear-gradient(135deg,#0f274f,#1f4ea3);padding:18px 20px;border-radius:14px 14px 0 0;color:#ffffff;">
                    <h2 style="margin:0;font-size:22px;">CampusEatzz Order Bill</h2>
                    <p style="margin:6px 0 0 0;font-size:13px;opacity:0.9;">Order #{safeOrder} completed successfully</p>
                </div>

                <div style="background:#ffffff;border:1px solid #d7e3fb;border-top:none;border-radius:0 0 14px 14px;padding:20px;">
                    <p style="margin:0 0 10px 0;font-size:14px;">Hi <strong>{safeName}</strong>,</p>
                    <p style="margin:0 0 16px 0;font-size:14px;color:#475569;">Thank you for ordering from <strong>{safeCanteen}</strong>. Your order is completed. Here is your bill summary.</p>

                    <table role="presentation" style="width:100%;border-collapse:collapse;margin-bottom:16px;font-size:13px;">
                        <tr>
                            <td style="padding:6px 0;color:#64748b;">Order Number</td>
                            <td style="padding:6px 0;text-align:right;font-weight:600;">{safeOrder}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0;color:#64748b;">Order Time</td>
                            <td style="padding:6px 0;text-align:right;">{WebUtility.HtmlEncode(createdAt)}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0;color:#64748b;">Completed Time</td>
                            <td style="padding:6px 0;text-align:right;">{WebUtility.HtmlEncode(completedAt)}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0;color:#64748b;">Payment Method</td>
                            <td style="padding:6px 0;text-align:right;">{paymentMethod}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0;color:#64748b;">Payment Status</td>
                            <td style="padding:6px 0;text-align:right;">{paymentStatus}</td>
                        </tr>
                    </table>

                    <table role="presentation" style="width:100%;border-collapse:collapse;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden;font-size:13px;">
                        <thead>
                            <tr style="background:#eef4ff;">
                                <th align="left" style="padding:10px 12px;color:#334155;">Item</th>
                                <th align="center" style="padding:10px 12px;color:#334155;">Qty</th>
                                <th align="right" style="padding:10px 12px;color:#334155;">Unit</th>
                                <th align="right" style="padding:10px 12px;color:#334155;">Total</th>
                            </tr>
                        </thead>
                        <tbody>
                            {rowsHtml}
                        </tbody>
                    </table>

                    <table role="presentation" style="width:100%;margin-top:14px;border-collapse:collapse;font-size:14px;">
                        <tr>
                            <td style="padding:4px 0;color:#64748b;">Subtotal</td>
                            <td style="padding:4px 0;text-align:right;">INR {order.Subtotal:0.00}</td>
                        </tr>
                        <tr>
                            <td style="padding:4px 0;color:#64748b;">Tax</td>
                            <td style="padding:4px 0;text-align:right;">INR {order.Tax:0.00}</td>
                        </tr>
                        <tr>
                            <td style="padding:8px 0 0 0;font-weight:700;">Grand Total</td>
                            <td style="padding:8px 0 0 0;text-align:right;font-weight:700;color:#1f4ea3;">INR {order.Total:0.00}</td>
                        </tr>
                    </table>

                    <p style="margin:16px 0 0 0;font-size:13px;color:#475569;">Please open the CampusEatzz app and share your feedback for this order. Your feedback helps us improve.</p>
                </div>
            </div>
            """;
    }

    private static string BuildOrderStatusEmailHtmlBody(OrderNotificationRow order, string normalizedStatus)
    {
        var safeOrder = WebUtility.HtmlEncode(order.OrderNumber);
        var safeName = WebUtility.HtmlEncode(string.IsNullOrWhiteSpace(order.UserName) ? "Customer" : order.UserName);
        var safeCanteen = WebUtility.HtmlEncode(string.IsNullOrWhiteSpace(order.CanteenName) ? "CampusEatzz Canteen" : order.CanteenName);
        var statusLabel = ToTitleCaseLabel(normalizedStatus);

        var statusText = normalizedStatus switch
        {
            "pending" => "Your order is pending and waiting for canteen confirmation.",
            "confirmed" => "Your order has been confirmed by the canteen.",
            "preparing" => "Your order is being prepared.",
            "ready" => "Your order is ready for pickup.",
            "cancelled" => "Your order has been cancelled. Please contact support if required.",
            _ => $"Your order status is now {statusLabel}."
        };

        var createdAt = order.CreatedAt.ToLocalTime().ToString("dd MMM yyyy hh:mm tt", CultureInfo.InvariantCulture);

        return $"""
            <div style="font-family:Segoe UI,Arial,sans-serif;max-width:640px;margin:0 auto;background:#f5f9ff;padding:24px;color:#17253f;">
                <div style="background:linear-gradient(135deg,#0f274f,#1f4ea3);padding:18px 20px;border-radius:14px 14px 0 0;color:#ffffff;">
                    <h2 style="margin:0;font-size:22px;">CampusEatzz Order Update</h2>
                    <p style="margin:6px 0 0 0;font-size:13px;opacity:0.9;">Order #{safeOrder} - {WebUtility.HtmlEncode(statusLabel)}</p>
                </div>

                <div style="background:#ffffff;border:1px solid #d7e3fb;border-top:none;border-radius:0 0 14px 14px;padding:20px;">
                    <p style="margin:0 0 10px 0;font-size:14px;">Hi <strong>{safeName}</strong>,</p>
                    <p style="margin:0 0 14px 0;font-size:14px;color:#475569;">{WebUtility.HtmlEncode(statusText)}</p>

                    <table role="presentation" style="width:100%;border-collapse:collapse;margin-bottom:14px;font-size:13px;">
                        <tr>
                            <td style="padding:6px 0;color:#64748b;">Order Number</td>
                            <td style="padding:6px 0;text-align:right;font-weight:600;">{safeOrder}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0;color:#64748b;">Canteen</td>
                            <td style="padding:6px 0;text-align:right;">{safeCanteen}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0;color:#64748b;">Order Time</td>
                            <td style="padding:6px 0;text-align:right;">{WebUtility.HtmlEncode(createdAt)}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0;color:#64748b;">Current Status</td>
                            <td style="padding:6px 0;text-align:right;font-weight:700;color:#1f4ea3;">{WebUtility.HtmlEncode(statusLabel)}</td>
                        </tr>
                    </table>

                    <p style="margin:0;font-size:13px;color:#475569;">Open CampusEatzz app to see full order details and live updates.</p>
                </div>
            </div>
            """;
    }

    private static string BuildFeedbackRequestEmailHtmlBody(OrderNotificationRow order, string feedbackFormUrl)
    {
        var safeOrder = WebUtility.HtmlEncode(order.OrderNumber);
        var safeName = WebUtility.HtmlEncode(string.IsNullOrWhiteSpace(order.UserName) ? "Customer" : order.UserName);
        var safeCanteen = WebUtility.HtmlEncode(string.IsNullOrWhiteSpace(order.CanteenName) ? "CampusEatzz Canteen" : order.CanteenName);
        var safeUrl = WebUtility.HtmlEncode(feedbackFormUrl ?? string.Empty);

        var actionHtml = string.IsNullOrWhiteSpace(feedbackFormUrl)
            ? "<p style=\"margin:0 0 12px 0;font-size:14px;color:#475569;\">Open the CampusEatzz app and go to Notifications, then tap the <strong>Order Completed</strong> card to submit feedback.</p>"
            : $"<p style=\"margin:0 0 12px 0;font-size:14px;color:#475569;\">Tap the button below to open the feedback form with 5 stars, text field, and send button.</p><p style=\"margin:0 0 14px 0;\"><a href=\"{safeUrl}\" style=\"display:inline-block;background:#1f4ea3;color:#ffffff;text-decoration:none;padding:10px 16px;border-radius:8px;font-weight:600;\">Open Feedback Form</a></p>";

        return $"""
            <div style="font-family:Segoe UI,Arial,sans-serif;max-width:620px;margin:0 auto;background:#f5f9ff;padding:24px;color:#17253f;">
                <div style="background:linear-gradient(135deg,#0f274f,#1f4ea3);padding:18px 20px;border-radius:14px 14px 0 0;color:#ffffff;">
                    <h2 style="margin:0;font-size:22px;">Share Your Feedback</h2>
                    <p style="margin:6px 0 0 0;font-size:13px;opacity:0.9;">Order #{safeOrder} from {safeCanteen}</p>
                </div>

                <div style="background:#ffffff;border:1px solid #d7e3fb;border-top:none;border-radius:0 0 14px 14px;padding:20px;">
                    <p style="margin:0 0 10px 0;font-size:14px;">Hi <strong>{safeName}</strong>,</p>
                    <p style="margin:0 0 12px 0;font-size:14px;color:#475569;">Your order is completed. Please rate your experience and share feedback in the CampusEatzz app.</p>
                    {actionHtml}
                    <p style="margin:0;font-size:13px;color:#64748b;">Thanks for helping us improve CampusEatzz service quality.</p>
                </div>
            </div>
            """;
    }

    private static string ToTitleCaseLabel(string value)
    {
        var normalized = (value ?? string.Empty).Trim().Replace('_', ' ');
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return "Unknown";
        }

        return CultureInfo.InvariantCulture.TextInfo.ToTitleCase(normalized.ToLowerInvariant());
    }

    public async Task NotifySystemMaintenanceAsync(
        bool isActive,
        string message,
        int createdByUserId,
        string createdByRole,
        CancellationToken cancellationToken)
    {
        var title = isActive ? "Maintenance Alert" : "Service Restored";
        var body = string.IsNullOrWhiteSpace(message)
            ? (isActive
                ? "CampusEatzz is currently in maintenance mode."
                : "CampusEatzz services are now available.")
            : message.Trim();

        await CreateOrScheduleAsync(new NotificationCreateRequest
        {
            NotificationType = "general_alert",
            Title = title,
            Message = body,
            TargetScope = "all",
            Data = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["action"] = "home",
                ["alertType"] = "system_maintenance",
                ["isActive"] = isActive ? "true" : "false"
            },
            CreatedByUserId = createdByUserId,
            CreatedByRole = createdByRole,
        }, cancellationToken);
    }

    public async Task NotifyCanteenMaintenanceAsync(
        int canteenId,
        bool isActive,
        string reason,
        int createdByUserId,
        string createdByRole,
        CancellationToken cancellationToken)
    {
        if (canteenId <= 0)
        {
            return;
        }

        var title = isActive ? "Canteen Closed" : "Canteen Reopened";
        var body = string.IsNullOrWhiteSpace(reason)
            ? (isActive
                ? "A canteen is temporarily unavailable due to maintenance."
                : "A canteen is now open and accepting orders.")
            : reason.Trim();

        await CreateOrScheduleAsync(new NotificationCreateRequest
        {
            NotificationType = "general_alert",
            Title = title,
            Message = body,
            TargetScope = "canteen",
            TargetCanteenId = canteenId,
            Data = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["action"] = "menu",
                ["alertType"] = "canteen_maintenance",
                ["canteenId"] = canteenId.ToString(),
                ["isActive"] = isActive ? "true" : "false"
            },
            CreatedByUserId = createdByUserId,
            CreatedByRole = createdByRole,
        }, cancellationToken);
    }

    private async Task<NotificationDispatchSummary> DispatchNotificationByIdAsync(long notificationId, CancellationToken cancellationToken)
    {
        using var connection = dbConnectionFactory.CreateConnection();

        var row = await connection.QuerySingleOrDefaultAsync<NotificationRow>(new CommandDefinition(
            """
            SELECT
                id AS Id,
                COALESCE(notification_type, 'alert') AS NotificationType,
                COALESCE(title, '') AS Title,
                COALESCE(message, '') AS Message,
                COALESCE(payload_json, '{}') AS PayloadJson,
                COALESCE(target_scope, 'all') AS TargetScope,
                target_user_id AS TargetUserId,
                COALESCE(target_role, '') AS TargetRole,
                target_canteen_id AS TargetCanteenId,
                scheduled_for_utc AS ScheduledForUtc,
                COALESCE(status, 'pending') AS Status
            FROM app_notifications
            WHERE id = @notificationId
            LIMIT 1;
            """,
            new { notificationId },
            cancellationToken: cancellationToken));

        if (row is null)
        {
            return new NotificationDispatchSummary
            {
                NotificationId = notificationId,
                Status = "failed"
            };
        }

        if (string.Equals(row.Status, "sent", StringComparison.OrdinalIgnoreCase)
            || string.Equals(row.Status, "partial", StringComparison.OrdinalIgnoreCase)
            || string.Equals(row.Status, "failed", StringComparison.OrdinalIgnoreCase)
            || string.Equals(row.Status, "stored", StringComparison.OrdinalIgnoreCase))
        {
            return new NotificationDispatchSummary
            {
                NotificationId = row.Id,
                Status = row.Status
            };
        }

        var recipients = await ResolveRecipientsAsync(connection, row, cancellationToken);
        if (recipients.Count == 0)
        {
            await connection.ExecuteAsync(new CommandDefinition(
                """
                UPDATE app_notifications
                SET status = 'failed',
                    sent_at_utc = UTC_TIMESTAMP()
                WHERE id = @id;
                """,
                new { id = row.Id },
                cancellationToken: cancellationToken));

            return new NotificationDispatchSummary
            {
                NotificationId = row.Id,
                Status = "failed",
                RecipientCount = 0,
                FailedCount = 0,
                DeliveredCount = 0
            };
        }

        var payloadData = ParsePayload(row.PayloadJson);
        if (!payloadData.ContainsKey("notificationId"))
        {
            payloadData = payloadData
                .Concat(new[] { new KeyValuePair<string, string>("notificationId", row.Id.ToString()) })
                .ToDictionary(kv => kv.Key, kv => kv.Value, StringComparer.OrdinalIgnoreCase);
        }

        var deliveredCount = 0;
        var failedCount = 0;
        var storedCount = 0;

        foreach (var recipient in recipients)
        {
            await connection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO app_notification_recipients
                    (notification_id, recipient_user_id, recipient_role, delivery_status, created_at_utc)
                VALUES
                    (@notificationId, @recipientUserId, @recipientRole, 'pending', UTC_TIMESTAMP())
                ON DUPLICATE KEY UPDATE
                    recipient_user_id = VALUES(recipient_user_id);
                """,
                new
                {
                    notificationId = row.Id,
                    recipientUserId = recipient.UserId,
                    recipientRole = recipient.Role
                },
                cancellationToken: cancellationToken));

            var tokens = (await connection.QueryAsync<string>(new CommandDefinition(
                """
                SELECT token
                FROM user_device_tokens
                WHERE user_id = @userId
                  AND LOWER(COALESCE(role, '')) = @role
                  AND COALESCE(is_active, 1) = 1;
                """,
                new
                {
                    userId = recipient.UserId,
                    role = recipient.Role
                },
                cancellationToken: cancellationToken)))
                .Where(token => !string.IsNullOrWhiteSpace(token))
                .Select(token => token.Trim())
                .Distinct(StringComparer.Ordinal)
                .ToList();

            if (tokens.Count == 0)
            {
                failedCount++;
                await UpdateRecipientStatusAsync(
                    connection,
                    row.Id,
                    recipient,
                    "failed",
                    "No active device token is registered for this recipient.",
                    delivered: false,
                    cancellationToken);
                continue;
            }

            var sendResult = await fcmPushSender.SendToTokensAsync(
                row.Title,
                row.Message,
                payloadData,
                tokens,
                cancellationToken);

            if (!sendResult.Enabled)
            {
                storedCount++;
                await UpdateRecipientStatusAsync(
                    connection,
                    row.Id,
                    recipient,
                    "stored",
                    sendResult.Error,
                    delivered: false,
                    cancellationToken);
                continue;
            }

            if (sendResult.SuccessCount > 0)
            {
                deliveredCount++;
                await UpdateRecipientStatusAsync(
                    connection,
                    row.Id,
                    recipient,
                    "sent",
                    sendResult.FailureCount > 0 ? sendResult.Error : null,
                    delivered: true,
                    cancellationToken);
            }
            else
            {
                failedCount++;
                await UpdateRecipientStatusAsync(
                    connection,
                    row.Id,
                    recipient,
                    "failed",
                    sendResult.Error,
                    delivered: false,
                    cancellationToken);
            }
        }

        var finalStatus = deliveredCount > 0
            ? (failedCount > 0 || storedCount > 0 ? "partial" : "sent")
            : (storedCount > 0 && failedCount == 0 ? "stored" : "failed");

        await connection.ExecuteAsync(new CommandDefinition(
            """
            UPDATE app_notifications
            SET status = @status,
                sent_at_utc = UTC_TIMESTAMP()
            WHERE id = @id;
            """,
            new
            {
                id = row.Id,
                status = finalStatus
            },
            cancellationToken: cancellationToken));

        return new NotificationDispatchSummary
        {
            NotificationId = row.Id,
            Status = finalStatus,
            RecipientCount = recipients.Count,
            DeliveredCount = deliveredCount,
            FailedCount = failedCount,
            StoredCount = storedCount
        };
    }

    private async Task UpdateRecipientStatusAsync(
        System.Data.IDbConnection connection,
        long notificationId,
        NotificationRecipient recipient,
        string status,
        string? error,
        bool delivered,
        CancellationToken cancellationToken)
    {
        await connection.ExecuteAsync(new CommandDefinition(
            """
            UPDATE app_notification_recipients
            SET delivery_status = @status,
                delivery_error = @error,
                delivered_at_utc = CASE WHEN @delivered = 1 THEN COALESCE(delivered_at_utc, UTC_TIMESTAMP()) ELSE delivered_at_utc END
            WHERE notification_id = @notificationId
              AND recipient_user_id = @recipientUserId
              AND LOWER(COALESCE(recipient_role, '')) = @recipientRole;
            """,
            new
            {
                notificationId,
                recipientUserId = recipient.UserId,
                recipientRole = recipient.Role,
                status,
                error = string.IsNullOrWhiteSpace(error) ? null : error.Trim(),
                delivered = delivered ? 1 : 0
            },
            cancellationToken: cancellationToken));
    }

    private async Task<List<NotificationRecipient>> ResolveRecipientsAsync(
        System.Data.IDbConnection connection,
        NotificationRow row,
        CancellationToken cancellationToken)
    {
        var scope = NormalizeScope(row.TargetScope);
        var recipients = new List<NotificationRecipient>();

        switch (scope)
        {
            case "user":
                var targetUserId = row.TargetUserId.GetValueOrDefault();
                if (targetUserId <= 0)
                {
                    return recipients;
                }

                if (!string.IsNullOrWhiteSpace(row.TargetRole))
                {
                    recipients.Add(new NotificationRecipient(targetUserId, NormalizeRole(row.TargetRole)!));
                    return DeduplicateRecipients(recipients);
                }

                recipients.AddRange(await ResolveSingleUserRoleAsync(connection, targetUserId, cancellationToken));
                return DeduplicateRecipients(recipients);

            case "role":
                var role = NormalizeRole(row.TargetRole ?? string.Empty);
                if (string.IsNullOrWhiteSpace(role))
                {
                    return recipients;
                }

                recipients.AddRange(await ResolveByRoleAsync(connection, role, cancellationToken));
                return DeduplicateRecipients(recipients);

            case "canteen":
                var targetCanteenId = row.TargetCanteenId.GetValueOrDefault();
                if (targetCanteenId <= 0)
                {
                    return recipients;
                }

                recipients.AddRange(await ResolveCanteenRecipientsAsync(connection, targetCanteenId, cancellationToken));
                return DeduplicateRecipients(recipients);

            default:
                recipients.AddRange(await ResolveAllRecipientsAsync(connection, cancellationToken));
                return DeduplicateRecipients(recipients);
        }
    }

    private static List<NotificationRecipient> DeduplicateRecipients(List<NotificationRecipient> recipients)
    {
        return recipients
            .GroupBy(item => $"{item.UserId}:{item.Role}", StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .ToList();
    }

    private async Task<List<NotificationRecipient>> ResolveSingleUserRoleAsync(
        System.Data.IDbConnection connection,
        int userId,
        CancellationToken cancellationToken)
    {
        var recipients = new List<NotificationRecipient>();

        var userRole = await connection.ExecuteScalarAsync<string?>(new CommandDefinition(
            """
            SELECT LOWER(COALESCE(role, 'student'))
            FROM users
            WHERE id = @userId
              AND COALESCE(is_deleted, 0) = 0
              AND COALESCE(status, 'active') = 'active'
            LIMIT 1;
            """,
            new { userId },
            cancellationToken: cancellationToken));

        if (!string.IsNullOrWhiteSpace(userRole))
        {
            recipients.Add(new NotificationRecipient(userId, NormalizeRole(userRole) ?? "student"));
            return recipients;
        }

        var adminExists = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            "SELECT COUNT(1) FROM admin_users WHERE id = @userId;",
            new { userId },
            cancellationToken: cancellationToken));
        if (adminExists > 0)
        {
            recipients.Add(new NotificationRecipient(userId, "admin"));
            return recipients;
        }

        var canteenAdminExists = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            "SELECT COUNT(1) FROM canteen_admins WHERE id = @userId AND COALESCE(status, 'active') = 'active';",
            new { userId },
            cancellationToken: cancellationToken));
        if (canteenAdminExists > 0)
        {
            recipients.Add(new NotificationRecipient(userId, "canteen_admin"));
        }

        return recipients;
    }

    private async Task<List<NotificationRecipient>> ResolveByRoleAsync(
        System.Data.IDbConnection connection,
        string role,
        CancellationToken cancellationToken)
    {
        if (string.Equals(role, "admin", StringComparison.OrdinalIgnoreCase))
        {
            var adminIds = await connection.QueryAsync<int>(new CommandDefinition(
                "SELECT id FROM admin_users;",
                cancellationToken: cancellationToken));
            return adminIds.Select(id => new NotificationRecipient(id, "admin")).ToList();
        }

        if (string.Equals(role, "canteen_admin", StringComparison.OrdinalIgnoreCase))
        {
            var adminIds = await connection.QueryAsync<int>(new CommandDefinition(
                "SELECT id FROM canteen_admins WHERE COALESCE(status, 'active') = 'active';",
                cancellationToken: cancellationToken));
            return adminIds.Select(id => new NotificationRecipient(id, "canteen_admin")).ToList();
        }

        var rows = await connection.QueryAsync<NotificationRecipient>(new CommandDefinition(
            """
            SELECT id AS UserId, LOWER(COALESCE(role, 'student')) AS Role
            FROM users
            WHERE LOWER(COALESCE(role, 'student')) = @role
              AND COALESCE(is_deleted, 0) = 0
              AND COALESCE(status, 'active') = 'active';
            """,
            new { role },
            cancellationToken: cancellationToken));

        return rows.ToList();
    }

    private async Task<List<NotificationRecipient>> ResolveCanteenRecipientsAsync(
        System.Data.IDbConnection connection,
        int canteenId,
        CancellationToken cancellationToken)
    {
        var recipients = new List<NotificationRecipient>();

        var userRecipients = await connection.QueryAsync<NotificationRecipient>(new CommandDefinition(
            """
            SELECT DISTINCT u.id AS UserId, LOWER(COALESCE(u.role, 'student')) AS Role
            FROM orders o
            INNER JOIN users u ON u.id = o.user_id
            WHERE o.canteen_id = @canteenId
              AND COALESCE(u.is_deleted, 0) = 0
              AND COALESCE(u.status, 'active') = 'active';
            """,
            new { canteenId },
            cancellationToken: cancellationToken));
        recipients.AddRange(userRecipients);

        var canteenAdmins = await connection.QueryAsync<int>(new CommandDefinition(
            "SELECT id FROM canteen_admins WHERE canteen_id = @canteenId AND COALESCE(status, 'active') = 'active';",
            new { canteenId },
            cancellationToken: cancellationToken));
        recipients.AddRange(canteenAdmins.Select(id => new NotificationRecipient(id, "canteen_admin")));

        return recipients;
    }

    private async Task<List<NotificationRecipient>> ResolveAllRecipientsAsync(
        System.Data.IDbConnection connection,
        CancellationToken cancellationToken)
    {
        var recipients = new List<NotificationRecipient>();

        var users = await connection.QueryAsync<NotificationRecipient>(new CommandDefinition(
            """
            SELECT id AS UserId, LOWER(COALESCE(role, 'student')) AS Role
            FROM users
            WHERE COALESCE(is_deleted, 0) = 0
              AND COALESCE(status, 'active') = 'active';
            """,
            cancellationToken: cancellationToken));
        recipients.AddRange(users);

        var admins = await connection.QueryAsync<int>(new CommandDefinition(
            "SELECT id FROM admin_users;",
            cancellationToken: cancellationToken));
        recipients.AddRange(admins.Select(id => new NotificationRecipient(id, "admin")));

        return recipients;
    }

    private static void ValidateTarget(string scope, int? targetUserId, string? targetRole, int? targetCanteenId)
    {
        switch (scope)
        {
            case "user":
                if (targetUserId is null or <= 0)
                {
                    throw new InvalidOperationException("Target user id is required for user scope notifications.");
                }
                break;
            case "role":
                if (string.IsNullOrWhiteSpace(targetRole))
                {
                    throw new InvalidOperationException("Target role is required for role scope notifications.");
                }
                break;
            case "canteen":
                if (targetCanteenId is null or <= 0)
                {
                    throw new InvalidOperationException("Target canteen id is required for canteen scope notifications.");
                }
                break;
        }
    }

    private static string NormalizeScope(string? value)
    {
        var scope = (value ?? string.Empty).Trim().ToLowerInvariant();
        return scope switch
        {
            "user" => "user",
            "role" => "role",
            "canteen" => "canteen",
            _ => "all"
        };
    }

    private static string NormalizeType(string? value)
    {
        var type = (value ?? string.Empty).Trim().ToLowerInvariant();
        return type switch
        {
            "order_update" => "order_update",
            "offer" => "offer",
            "promotion" => "promotion",
            "general_alert" => "general_alert",
            _ => "general_alert"
        };
    }

    private static string NormalizeOrderStatus(string? value)
    {
        var status = (value ?? string.Empty).Trim().ToLowerInvariant();
        return status switch
        {
            "pending" => "pending",
            "confirmed" => "confirmed",
            "preparing" => "preparing",
            "ready" => "ready",
            "ready_to_pickup" => "ready",
            "ready for pickup" => "ready",
            "completed" => "completed",
            "cancelled" => "cancelled",
            "canceled" => "cancelled",
            _ => "updated"
        };
    }

    private static string? NormalizeRole(string? value)
    {
        var role = (value ?? string.Empty).Trim().ToLowerInvariant();
        return role switch
        {
            "student" => "student",
            "staff" => "staff",
            "admin" => "admin",
            "canteen_admin" => "canteen_admin",
            _ => string.IsNullOrWhiteSpace(role) ? null : role
        };
    }

    private static IReadOnlyDictionary<string, string> ParsePayload(string payloadJson)
    {
        if (string.IsNullOrWhiteSpace(payloadJson))
        {
            return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        }

        try
        {
            var parsed = JsonSerializer.Deserialize<Dictionary<string, string>>(payloadJson);
            return parsed ?? new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        }
        catch
        {
            return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        }
    }

    private sealed record NotificationRecipient(int UserId, string Role);

    private sealed class NotificationRow
    {
        public long Id { get; init; }
        public string NotificationType { get; init; } = string.Empty;
        public string Title { get; init; } = string.Empty;
        public string Message { get; init; } = string.Empty;
        public string PayloadJson { get; init; } = "{}";
        public string TargetScope { get; init; } = "all";
        public int? TargetUserId { get; init; }
        public string TargetRole { get; init; } = string.Empty;
        public int? TargetCanteenId { get; init; }
        public DateTime? ScheduledForUtc { get; init; }
        public string Status { get; init; } = "pending";
    }

    private sealed class NotificationHistoryRow
    {
        public long Id { get; init; }
        public string NotificationType { get; init; } = string.Empty;
        public string Title { get; init; } = string.Empty;
        public string Message { get; init; } = string.Empty;
        public string PayloadJson { get; init; } = "{}";
        public string DeliveryStatus { get; init; } = "pending";
        public DateTime CreatedAtUtc { get; init; }
        public DateTime? ReadAtUtc { get; init; }
    }

    private sealed class OrderNotificationRow
    {
        public int OrderId { get; init; }
        public string OrderNumber { get; init; } = string.Empty;
        public int UserId { get; init; }
        public string UserRole { get; init; } = "student";
        public string UserEmail { get; init; } = string.Empty;
        public string UserName { get; init; } = "Customer";
        public decimal Subtotal { get; init; }
        public decimal Tax { get; init; }
        public decimal Total { get; init; }
        public string PaymentMethod { get; init; } = "cash";
        public string PaymentStatus { get; init; } = "pending";
        public DateTime CreatedAt { get; init; }
        public DateTime? CompletedAt { get; init; }
        public string CanteenName { get; init; } = "Canteen";
    }

    private sealed class OrderBillItemRow
    {
        public string ItemName { get; init; } = "Item";
        public int Quantity { get; init; }
        public decimal UnitPrice { get; init; }
        public decimal TotalPrice { get; init; }
    }
}
