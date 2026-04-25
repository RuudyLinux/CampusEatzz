using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using UniversityCanteen.Api.Configuration;
using UniversityCanteen.Api.Data;
using UniversityCanteen.Api.Services;

namespace UniversityCanteen.Api.Controllers;

[ApiController]
[Authorize]
[Route("api")]
public sealed class OperationsController(
    IDbConnectionFactory dbConnectionFactory,
    IOptions<AuthOptions> authOptions,
    INotificationService notificationService,
    ILogger<OperationsController> logger) : ControllerBase
{
    private readonly AuthOptions _authOptions = authOptions.Value;

    [HttpGet("admin/orders")]
    [ResponseCache(Duration = 15, Location = ResponseCacheLocation.Any)]
    public async Task<IActionResult> GetAdminOrders(
        [FromQuery] string? status,
        [FromQuery] string? search,
        [FromQuery] int limit = 50,
        [FromQuery] int offset = 0,
        CancellationToken cancellationToken = default)
    {
        var normalizedStatus = NormalizeOrderStatus(status);
        var normalizedSearch = (search ?? string.Empty).Trim();
        var normalizedLimit = Math.Clamp(limit, 1, 100);
        var normalizedOffset = Math.Max(offset, 0);

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("You are not authorized to access admin order data."));
            }

            var rows = (await connection.QueryAsync<AdminOrderRow>(new CommandDefinition(
                """
                SELECT
                    o.id AS Id,
                    o.order_number AS OrderNumber,
                    o.user_id AS UserId,
                    o.canteen_id AS CanteenId,
                    COALESCE(o.total_amount, 0.00) AS Subtotal,
                    COALESCE(o.tax_amount, 0.00) AS Tax,
                    COALESCE(o.final_amount, 0.00) AS Total,
                    COALESCE(o.payment_method, 'cash') AS PaymentMethod,
                    COALESCE(o.payment_status, 'pending') AS PaymentStatus,
                    COALESCE(o.order_status, 'pending') AS OrderStatus,
                    COALESCE(o.customer_name, '') AS CustomerName,
                    COALESCE(o.customer_phone, '') AS CustomerPhone,
                    o.created_at AS CreatedAt,
                    COALESCE(u.first_name, '') AS UserFirstName,
                    COALESCE(u.last_name, '') AS UserLastName,
                    COALESCE(u.email, '') AS UserEmail,
                    COALESCE(c.name, 'Unknown') AS CanteenName
                FROM orders o
                LEFT JOIN users u ON o.user_id = u.id
                LEFT JOIN canteens c ON o.canteen_id = c.id
                WHERE (@status = '' OR o.order_status = @status)
                  AND (
                      @search = ''
                      OR o.order_number LIKE CONCAT('%', @search, '%')
                      OR COALESCE(o.customer_name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.email, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.first_name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.last_name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(c.name, '') LIKE CONCAT('%', @search, '%')
                  )
                ORDER BY o.created_at DESC
                LIMIT @limit OFFSET @offset;
                """,
                new
                {
                    status = normalizedStatus,
                    search = normalizedSearch,
                    limit = normalizedLimit,
                    offset = normalizedOffset
                },
                cancellationToken: cancellationToken))).ToList();

            var orderIds = rows.Select(row => row.Id).Distinct().ToList();
            var itemsByOrderId = await LoadOrderItemsMap(connection, orderIds, cancellationToken);

            var orders = rows.Select(row =>
            {
                var items = itemsByOrderId.TryGetValue(row.Id, out var values)
                    ? values
                    : [];

                return new
                {
                    id = row.Id,
                    orderNumber = row.OrderNumber,
                    userId = row.UserId,
                    customerName = BuildCustomerName(row),
                    customerPhone = string.IsNullOrWhiteSpace(row.CustomerPhone) ? "N/A" : row.CustomerPhone,
                    customerEmail = row.UserEmail,
                    canteenId = row.CanteenId,
                    canteenName = row.CanteenName,
                    subtotal = RoundMoney(row.Subtotal),
                    tax = RoundMoney(row.Tax),
                    total = RoundMoney(ResolveTotal(row.Total, row.Subtotal, row.Tax)),
                    paymentMethod = NormalizePaymentMethodForUi(row.PaymentMethod),
                    paymentStatus = NormalizePaymentStatusForUi(row.PaymentStatus),
                    status = row.OrderStatus,
                    createdAt = row.CreatedAt,
                    items,
                    itemCount = items.Count
                };
            }).ToList();

            return Ok(Success("Orders fetched successfully.", new
            {
                orders,
                count = orders.Count,
                limit = normalizedLimit,
                offset = normalizedOffset
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch admin orders.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching orders."));
        }
    }

    [HttpGet("admin/orders/{orderRef}")]
    public async Task<IActionResult> GetAdminOrderDetails(string orderRef, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(orderRef))
        {
            return BadRequest(Failure("Order reference is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("You are not authorized to access admin order data."));
            }

            var row = await connection.QuerySingleOrDefaultAsync<AdminOrderRow>(new CommandDefinition(
                """
                SELECT
                    o.id AS Id,
                    o.order_number AS OrderNumber,
                    o.user_id AS UserId,
                    o.canteen_id AS CanteenId,
                    COALESCE(o.total_amount, 0.00) AS Subtotal,
                    COALESCE(o.tax_amount, 0.00) AS Tax,
                    COALESCE(o.final_amount, 0.00) AS Total,
                    COALESCE(o.payment_method, 'cash') AS PaymentMethod,
                    COALESCE(o.payment_status, 'pending') AS PaymentStatus,
                    COALESCE(o.order_status, 'pending') AS OrderStatus,
                    COALESCE(o.customer_name, '') AS CustomerName,
                    COALESCE(o.customer_phone, '') AS CustomerPhone,
                    COALESCE(o.delivery_address, '') AS DeliveryAddress,
                    COALESCE(o.special_instructions, '') AS SpecialInstructions,
                    o.created_at AS CreatedAt,
                    COALESCE(u.first_name, '') AS UserFirstName,
                    COALESCE(u.last_name, '') AS UserLastName,
                    COALESCE(u.email, '') AS UserEmail,
                    COALESCE(c.name, 'Unknown') AS CanteenName
                FROM orders o
                LEFT JOIN users u ON o.user_id = u.id
                LEFT JOIN canteens c ON o.canteen_id = c.id
                WHERE o.order_number = @orderRef
                   OR CAST(o.id AS CHAR) = @orderRef
                LIMIT 1;
                """,
                new { orderRef = orderRef.Trim() },
                cancellationToken: cancellationToken));

            if (row is null)
            {
                return NotFound(Failure("Order not found."));
            }

            var itemsByOrderId = await LoadOrderItemsMap(connection, [row.Id], cancellationToken);
            var items = itemsByOrderId.TryGetValue(row.Id, out var values)
                ? values
                : [];

            return Ok(Success("Order fetched successfully.", new
            {
                id = row.Id,
                orderNumber = row.OrderNumber,
                userId = row.UserId,
                customerName = BuildCustomerName(row),
                customerPhone = string.IsNullOrWhiteSpace(row.CustomerPhone) ? "N/A" : row.CustomerPhone,
                customerEmail = row.UserEmail,
                canteenId = row.CanteenId,
                canteenName = row.CanteenName,
                subtotal = RoundMoney(row.Subtotal),
                tax = RoundMoney(row.Tax),
                total = RoundMoney(ResolveTotal(row.Total, row.Subtotal, row.Tax)),
                paymentMethod = NormalizePaymentMethodForUi(row.PaymentMethod),
                paymentStatus = NormalizePaymentStatusForUi(row.PaymentStatus),
                status = row.OrderStatus,
                deliveryAddress = row.DeliveryAddress,
                specialInstructions = row.SpecialInstructions,
                createdAt = row.CreatedAt,
                items
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch order details for {OrderRef}", orderRef);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching order details."));
        }
    }

    [HttpGet("admin/wallets")]
    [ResponseCache(Duration = 20, Location = ResponseCacheLocation.Any)]
    public async Task<IActionResult> GetAdminWallets(
        [FromQuery] string? search,
        [FromQuery] int limit = 50,
        [FromQuery] int offset = 0,
        CancellationToken cancellationToken = default)
    {
        var normalizedSearch = (search ?? string.Empty).Trim();
        var normalizedLimit = Math.Clamp(limit, 1, 200);
        var normalizedOffset = Math.Max(offset, 0);

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("You are not authorized to access wallet data."));
            }

            var rows = (await connection.QueryAsync<AdminWalletRow>(new CommandDefinition(
                """
                SELECT
                    u.id AS UserId,
                    COALESCE(u.first_name, '') AS FirstName,
                    COALESCE(u.last_name, '') AS LastName,
                    COALESCE(u.email, '') AS Email,
                    COALESCE(w.balance, 0.00) AS Balance,
                    COALESCE(w.created_at, u.created_at) AS CreatedAt
                FROM users u
                LEFT JOIN wallets w ON w.user_id = u.id
                WHERE COALESCE(u.is_deleted, 0) = 0
                  AND (
                      @search = ''
                      OR COALESCE(u.first_name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.last_name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.email, '') LIKE CONCAT('%', @search, '%')
                  )
                ORDER BY u.id DESC
                LIMIT @limit OFFSET @offset;
                """,
                new
                {
                    search = normalizedSearch,
                    limit = normalizedLimit,
                    offset = normalizedOffset
                },
                cancellationToken: cancellationToken))).ToList();

            var walletIds = rows.Select(row => row.UserId).Distinct().ToList();
            if (walletIds.Count > 0)
            {
                await connection.ExecuteAsync(new CommandDefinition(
                    """
                    INSERT INTO wallets (user_id, balance)
                    VALUES (@userId, 0.00)
                    ON DUPLICATE KEY UPDATE user_id = VALUES(user_id);
                    """,
                    walletIds.Select(userId => new { userId }),
                    cancellationToken: cancellationToken));
            }

            var totals = await connection.QuerySingleAsync<WalletStatsRow>(new CommandDefinition(
                """
                SELECT
                    COALESCE((SELECT SUM(balance) FROM wallets), 0.00) AS TotalBalance,
                    COALESCE((SELECT COUNT(1) FROM wallets WHERE COALESCE(balance, 0.00) > 0), 0) AS ActiveWallets,
                    COALESCE(SUM(CASE WHEN wt.type = 'credit' AND wt.status = 'completed' THEN wt.amount ELSE 0 END), 0.00) AS TotalCredits,
                    COALESCE(SUM(CASE WHEN wt.type = 'debit' AND wt.status = 'completed' THEN wt.amount ELSE 0 END), 0.00) AS TotalDebits
                FROM wallet_transactions wt
                WHERE 1=1;
                """,
                cancellationToken: cancellationToken));

            var wallets = rows.Select(row => new
            {
                userId = row.UserId,
                firstName = row.FirstName,
                lastName = row.LastName,
                email = row.Email,
                balance = RoundMoney(row.Balance),
                createdAt = row.CreatedAt
            }).ToList();

            return Ok(Success("Wallets fetched successfully.", new
            {
                wallets,
                count = wallets.Count,
                limit = normalizedLimit,
                offset = normalizedOffset,
                stats = new
                {
                    totalBalance = RoundMoney(totals.TotalBalance),
                    activeWallets = totals.ActiveWallets,
                    totalCredits = RoundMoney(totals.TotalCredits),
                    totalDebits = RoundMoney(totals.TotalDebits)
                }
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch admin wallets.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching wallets."));
        }
    }

    [HttpGet("admin/wallet-transactions")]
    [ResponseCache(Duration = 15, Location = ResponseCacheLocation.Any)]
    public async Task<IActionResult> GetAdminWalletTransactions(
        [FromQuery] string? type,
        [FromQuery] string? status,
        [FromQuery] string? search,
        [FromQuery] int? userId,
        [FromQuery] int limit = 50,
        [FromQuery] int offset = 0,
        CancellationToken cancellationToken = default)
    {
        var normalizedType = NormalizeTransactionType(type);
        var normalizedStatus = NormalizeTransactionStatus(status);
        var normalizedSearch = (search ?? string.Empty).Trim();
        var normalizedLimit = Math.Clamp(limit, 1, 200);
        var normalizedOffset = Math.Max(offset, 0);

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("You are not authorized to access wallet transaction data."));
            }

            var rows = (await connection.QueryAsync<AdminWalletTransactionRow>(new CommandDefinition(
                """
                SELECT
                    wt.id AS Id,
                    COALESCE(wt.transaction_id, '') AS TransactionId,
                    wt.user_id AS UserId,
                    COALESCE(wt.amount, 0.00) AS Amount,
                    COALESCE(wt.type, 'debit') AS Type,
                    COALESCE(wt.status, 'pending') AS Status,
                    COALESCE(wt.description, '') AS Description,
                    wt.order_id AS OrderId,
                    wt.created_at AS CreatedAt,
                    COALESCE(u.first_name, '') AS FirstName,
                    COALESCE(u.last_name, '') AS LastName,
                    COALESCE(u.email, '') AS Email
                FROM wallet_transactions wt
                LEFT JOIN users u ON wt.user_id = u.id
                WHERE (@type = '' OR wt.type = @type)
                  AND (@status = '' OR wt.status = @status)
                  AND (@userId IS NULL OR wt.user_id = @userId)
                  AND (
                      @search = ''
                      OR COALESCE(wt.transaction_id, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.first_name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.last_name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.email, '') LIKE CONCAT('%', @search, '%')
                  )
                ORDER BY wt.created_at DESC
                LIMIT @limit OFFSET @offset;
                """,
                new
                {
                    type = normalizedType,
                    status = normalizedStatus,
                    search = normalizedSearch,
                    userId,
                    limit = normalizedLimit,
                    offset = normalizedOffset
                },
                cancellationToken: cancellationToken))).ToList();

            var transactions = rows.Select(row => new
            {
                id = row.Id,
                transactionId = row.TransactionId,
                userId = row.UserId,
                firstName = row.FirstName,
                lastName = row.LastName,
                email = row.Email,
                amount = RoundMoney(row.Amount),
                type = row.Type,
                status = row.Status,
                description = row.Description,
                orderId = row.OrderId,
                createdAt = row.CreatedAt
            }).ToList();

            return Ok(Success("Wallet transactions fetched successfully.", new
            {
                transactions,
                count = transactions.Count,
                limit = normalizedLimit,
                offset = normalizedOffset
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch wallet transactions.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching wallet transactions."));
        }
    }

    [HttpGet("canteen/orders")]
    public async Task<IActionResult> GetCanteenOrders(
        [FromQuery] int canteenId,
        [FromQuery] string? status,
        [FromQuery] int limit = 200,
        CancellationToken cancellationToken = default)
    {
        if (canteenId <= 0)
        {
            return BadRequest(Failure("Valid canteenId is required."));
        }

        var normalizedStatus = NormalizeOrderStatus(status);
        var normalizedLimit = Math.Clamp(limit, 1, 500);

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureCanteenAccessAsync(connection, canteenId, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("You are not authorized to access this canteen order data."));
            }

            var rows = (await connection.QueryAsync<CanteenOrderRow>(new CommandDefinition(
                """
                SELECT
                    o.id AS Id,
                    o.order_number AS OrderNumber,
                    o.user_id AS UserId,
                    o.canteen_id AS CanteenId,
                    COALESCE(o.total_amount, 0.00) AS Subtotal,
                    COALESCE(o.tax_amount, 0.00) AS Tax,
                    COALESCE(o.final_amount, 0.00) AS Total,
                    COALESCE(o.payment_method, 'cash') AS PaymentMethod,
                    COALESCE(o.payment_status, 'pending') AS PaymentStatus,
                    COALESCE(o.order_status, 'pending') AS OrderStatus,
                    COALESCE(o.customer_name, '') AS CustomerName,
                    COALESCE(o.customer_phone, '') AS CustomerPhone,
                    COALESCE(o.special_instructions, '') AS SpecialInstructions,
                    COALESCE(o.estimated_time, 0) AS EstimatedTime,
                    o.created_at AS CreatedAt,
                    COALESCE(u.first_name, '') AS UserFirstName,
                    COALESCE(u.last_name, '') AS UserLastName,
                    COALESCE(u.email, '') AS UserEmail,
                    COALESCE(u.contact, '') AS UserContact,
                    COALESCE(c.name, 'Unknown') AS CanteenName
                FROM orders o
                LEFT JOIN users u ON o.user_id = u.id
                LEFT JOIN canteens c ON o.canteen_id = c.id
                WHERE o.canteen_id = @canteenId
                  AND (@status = '' OR o.order_status = @status)
                ORDER BY o.created_at DESC
                LIMIT @limit;
                """,
                new
                {
                    canteenId,
                    status = normalizedStatus,
                    limit = normalizedLimit
                },
                cancellationToken: cancellationToken))).ToList();

            var orderIds = rows.Select(row => row.Id).Distinct().ToList();
            var itemsByOrderId = await LoadOrderItemsMap(connection, orderIds, cancellationToken);

            var orders = rows.Select(row => new
            {
                id = row.Id,
                orderNumber = row.OrderNumber,
                canteenId = row.CanteenId,
                canteenName = row.CanteenName,
                userId = row.UserId,
                customerName = BuildCanteenCustomerName(row),
                customerPhone = BuildCanteenCustomerPhone(row),
                customerEmail = row.UserEmail,
                subtotal = RoundMoney(row.Subtotal),
                tax = RoundMoney(row.Tax),
                total = RoundMoney(ResolveTotal(row.Total, row.Subtotal, row.Tax)),
                paymentMethod = NormalizePaymentMethodForUi(row.PaymentMethod),
                paymentStatus = NormalizePaymentStatusForUi(row.PaymentStatus),
                status = row.OrderStatus,
                estimatedTime = row.EstimatedTime,
                specialInstructions = row.SpecialInstructions,
                createdAt = row.CreatedAt,
                items = itemsByOrderId.TryGetValue(row.Id, out var values) ? values : []
            }).ToList();

            return Ok(Success("Canteen orders fetched successfully.", new
            {
                orders,
                total = orders.Count
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch canteen orders for canteen {CanteenId}", canteenId);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching canteen orders."));
        }
    }

    [HttpPatch("canteen/orders/{orderId:int}/status")]
    public async Task<IActionResult> UpdateCanteenOrderStatus(
        int orderId,
        [FromBody] UpdateCanteenOrderStatusRequest request,
        CancellationToken cancellationToken)
    {
        if (orderId <= 0)
        {
            return BadRequest(Failure("Valid orderId is required."));
        }

        var normalizedStatus = NormalizeOrderStatus(request.Status);
        if (string.IsNullOrWhiteSpace(normalizedStatus))
        {
            return BadRequest(Failure("Valid status is required."));
        }

        if (!AllowedOrderStatuses.Contains(normalizedStatus))
        {
            return BadRequest(Failure("Unsupported order status."));
        }

        var estimatedTime = request.EstimatedTime;
        if (estimatedTime is < 0)
        {
            estimatedTime = 0;
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            var current = await connection.QuerySingleOrDefaultAsync<CanteenOrderStatusRow>(new CommandDefinition(
                "SELECT id AS Id, canteen_id AS CanteenId, COALESCE(order_status, 'pending') AS Status FROM orders WHERE id = @orderId LIMIT 1;",
                new { orderId },
                cancellationToken: cancellationToken));

            if (current is null)
            {
                return NotFound(Failure("Order not found."));
            }

            var requestedCanteenId = request.CanteenId is > 0
                ? request.CanteenId.Value
                : current.CanteenId.GetValueOrDefault();

            if (requestedCanteenId <= 0)
            {
                return BadRequest(Failure("Valid canteenId is required to update order status."));
            }

            if (current.CanteenId != requestedCanteenId)
            {
                return BadRequest(Failure("Order does not belong to the requested canteen."));
            }

            if (!await EnsureCanteenAccessAsync(connection, requestedCanteenId, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("You are not authorized to update this canteen order."));
            }

            await connection.ExecuteAsync(new CommandDefinition(
                """
                UPDATE orders
                SET order_status = @status,
                    estimated_time = @estimatedTime,
                    updated_at = UTC_TIMESTAMP(),
                    completed_at = CASE WHEN @status = 'completed' THEN UTC_TIMESTAMP() ELSE completed_at END
                WHERE id = @orderId;
                """,
                new
                {
                    orderId,
                    status = normalizedStatus,
                    estimatedTime
                },
                cancellationToken: cancellationToken));

            await connection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO order_status_history (order_id, previous_status, new_status, changed_by, notes, created_at)
                VALUES (@orderId, @previousStatus, @newStatus, @changedBy, @notes, UTC_TIMESTAMP());
                """,
                new
                {
                    orderId,
                    previousStatus = current.Status,
                    newStatus = normalizedStatus,
                    changedBy = request.ChangedBy,
                    notes = string.IsNullOrWhiteSpace(request.Notes) ? null : request.Notes.Trim()
                },
                cancellationToken: cancellationToken));

            var actor = GetRequesterIdentity();
            var actorUserId = ResolveRequesterUserId(request.ChangedBy);

            try
            {
                await notificationService.NotifyOrderStatusAsync(new NotificationOrderStatusRequest
                {
                    OrderId = orderId,
                    Status = normalizedStatus,
                    EstimatedTime = estimatedTime,
                    ChangedByUserId = actorUserId,
                    ChangedByRole = string.IsNullOrWhiteSpace(actor.Role) ? "canteen_admin" : actor.Role
                }, cancellationToken);
            }
            catch (Exception notificationEx)
            {
                logger.LogWarning(notificationEx, "Order status notification dispatch failed for order {OrderId}", orderId);
            }

            return Ok(Success("Order status updated successfully.", new
            {
                orderId,
                status = normalizedStatus,
                estimatedTime
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to update status for order {OrderId}", orderId);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while updating order status."));
        }
    }

    private async Task<bool> EnsureAdminAccessAsync(
        System.Data.IDbConnection connection,
        CancellationToken cancellationToken)
    {
        var identity = GetRequesterIdentity();
        if (identity.Email == string.Empty || !string.Equals(identity.Role, "admin", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        if (string.Equals(identity.Email, _authOptions.Admin.Email, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var count = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            """
            SELECT COUNT(1)
            FROM admin_users
            WHERE LOWER(email) = LOWER(@email);
            """,
            new { email = identity.Email },
            cancellationToken: cancellationToken));

        if (count > 0)
        {
            return true;
        }

        var legacyCount = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            """
            SELECT COUNT(1)
            FROM users
            WHERE LOWER(email) = LOWER(@email)
              AND role = 'admin'
              AND COALESCE(is_deleted, 0) = 0
              AND COALESCE(status, 'active') = 'active';
            """,
            new { email = identity.Email },
            cancellationToken: cancellationToken));

        return legacyCount > 0;
    }

    private async Task<bool> EnsureCanteenAccessAsync(
        System.Data.IDbConnection connection,
        int canteenId,
        CancellationToken cancellationToken)
    {
        var identity = GetRequesterIdentity();
        if (identity.Email == string.Empty || !string.Equals(identity.Role, "canteen_admin", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var configuredMatch = _authOptions.CanteenAdmins.Any(admin =>
            admin.CanteenId == canteenId
            && string.Equals(admin.Email, identity.Email, StringComparison.OrdinalIgnoreCase));
        if (configuredMatch)
        {
            return true;
        }

        var count = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            """
            SELECT COUNT(1)
            FROM users
            WHERE LOWER(email) = LOWER(@email)
              AND role = 'canteen_admin'
              AND canteen_id = @canteenId
              AND COALESCE(is_deleted, 0) = 0
              AND COALESCE(status, 'active') = 'active';
            """,
            new
            {
                email = identity.Email,
                canteenId
            },
            cancellationToken: cancellationToken));

        if (count > 0)
        {
            return true;
        }

        var canteenAdminCount = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            """
            SELECT COUNT(1)
            FROM canteen_admins
            WHERE LOWER(COALESCE(email, '')) = LOWER(@email)
              AND canteen_id = @canteenId
              AND COALESCE(status, 'active') = 'active';
            """,
            new
            {
                email = identity.Email,
                canteenId
            },
            cancellationToken: cancellationToken));

        return canteenAdminCount > 0;
    }

    private (string Email, string Role) GetRequesterIdentity()
    {
        var claimEmail = User.FindFirst(JwtRegisteredClaimNames.Email)?.Value
            ?? User.FindFirst(ClaimTypes.Email)?.Value
            ?? User.FindFirst("email")?.Value
            ?? string.Empty;
        var claimRole = User.FindFirst(ClaimTypes.Role)?.Value
            ?? User.FindFirst("role")?.Value
            ?? string.Empty;

        var email = string.IsNullOrWhiteSpace(claimEmail)
            ? ReadHeaderOrQuery("X-Requester-Email", "requesterEmail")
            : claimEmail;
        var role = string.IsNullOrWhiteSpace(claimRole)
            ? ReadHeaderOrQuery("X-Requester-Role", "requesterRole")
            : claimRole;

        return (email.Trim().ToLowerInvariant(), role.Trim().ToLowerInvariant());
    }

    private string ReadHeaderOrQuery(string headerName, string queryName)
    {
        var headerValue = Request.Headers[headerName].FirstOrDefault();
        if (!string.IsNullOrWhiteSpace(headerValue))
        {
            return headerValue.Trim();
        }

        var queryValue = Request.Query[queryName].FirstOrDefault();
        if (!string.IsNullOrWhiteSpace(queryValue))
        {
            return queryValue.Trim();
        }

        return string.Empty;
    }

    private int ResolveRequesterUserId(int? fallbackUserId)
    {
        var claimSubject = User.FindFirst(JwtRegisteredClaimNames.Sub)?.Value
            ?? User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? string.Empty;

        if (int.TryParse(claimSubject, NumberStyles.Integer, CultureInfo.InvariantCulture, out var fromClaim) && fromClaim > 0)
        {
            return fromClaim;
        }

        var headerValue = Request.Headers["X-Requester-Id"].FirstOrDefault();
        if (int.TryParse(headerValue, NumberStyles.Integer, CultureInfo.InvariantCulture, out var fromHeader) && fromHeader > 0)
        {
            return fromHeader;
        }

        var queryValue = Request.Query["requesterId"].FirstOrDefault();
        if (int.TryParse(queryValue, NumberStyles.Integer, CultureInfo.InvariantCulture, out var fromQuery) && fromQuery > 0)
        {
            return fromQuery;
        }

        return fallbackUserId.GetValueOrDefault();
    }

    private static async Task<Dictionary<int, List<object>>> LoadOrderItemsMap(
        System.Data.IDbConnection connection,
        List<int> orderIds,
        CancellationToken cancellationToken)
    {
        if (orderIds.Count == 0)
        {
            return [];
        }

        var rows = (await connection.QueryAsync<OrderItemRow>(new CommandDefinition(
            """
            SELECT
                oi.id AS Id,
                oi.order_id AS OrderId,
                oi.menu_item_id AS MenuItemId,
                COALESCE(oi.item_name, 'Item') AS ItemName,
                COALESCE(oi.quantity, 1) AS Quantity,
                COALESCE(oi.unit_price, 0.00) AS UnitPrice,
                COALESCE(oi.total_price, 0.00) AS TotalPrice
            FROM order_items oi
            WHERE oi.order_id IN @orderIds
            ORDER BY oi.id ASC;
            """,
            new { orderIds },
            cancellationToken: cancellationToken))).ToList();

        return rows
            .GroupBy(row => row.OrderId)
            .ToDictionary(
                group => group.Key,
                group => group.Select(item => (object)new
                {
                    id = item.Id,
                    orderId = item.OrderId,
                    menuItemId = item.MenuItemId,
                    itemName = item.ItemName,
                    quantity = item.Quantity,
                    unitPrice = RoundMoney(item.UnitPrice),
                    totalPrice = RoundMoney(item.TotalPrice)
                }).ToList());
    }

    private static decimal ResolveTotal(decimal total, decimal subtotal, decimal tax)
    {
        if (total > 0m)
        {
            return total;
        }

        return subtotal + tax;
    }

    private static string BuildCustomerName(AdminOrderRow row)
    {
        if (!string.IsNullOrWhiteSpace(row.CustomerName))
        {
            return row.CustomerName.Trim();
        }

        var combined = $"{row.UserFirstName} {row.UserLastName}".Trim();
        return string.IsNullOrWhiteSpace(combined) ? "Unknown" : combined;
    }

    private static string BuildCanteenCustomerName(CanteenOrderRow row)
    {
        if (!string.IsNullOrWhiteSpace(row.CustomerName))
        {
            return row.CustomerName.Trim();
        }

        var combined = $"{row.UserFirstName} {row.UserLastName}".Trim();
        return string.IsNullOrWhiteSpace(combined) ? "Unknown" : combined;
    }

    private static string BuildCanteenCustomerPhone(CanteenOrderRow row)
    {
        if (!string.IsNullOrWhiteSpace(row.CustomerPhone))
        {
            return row.CustomerPhone.Trim();
        }

        return string.IsNullOrWhiteSpace(row.UserContact) ? "N/A" : row.UserContact;
    }

    private static string NormalizeOrderStatus(string? value)
    {
        return (value ?? string.Empty).Trim().ToLowerInvariant() switch
        {
            "pending" => "pending",
            "confirmed" => "confirmed",
            "preparing" => "preparing",
            "ready" => "ready",
            "completed" => "completed",
            "cancelled" => "cancelled",
            _ => string.Empty
        };
    }

    private static string NormalizeTransactionType(string? value)
    {
        return (value ?? string.Empty).Trim().ToLowerInvariant() switch
        {
            "credit" => "credit",
            "debit" => "debit",
            _ => string.Empty
        };
    }

    private static string NormalizeTransactionStatus(string? value)
    {
        return (value ?? string.Empty).Trim().ToLowerInvariant() switch
        {
            "pending" => "pending",
            "completed" => "completed",
            "failed" => "failed",
            "refunded" => "refunded",
            _ => string.Empty
        };
    }

    private static string NormalizePaymentMethodForUi(string value)
    {
        return (value ?? string.Empty).Trim().ToLowerInvariant() switch
        {
            "online" => "wallet",
            "upi" => "upi",
            "card" => "card",
            "cash" => "cash",
            _ => "cash"
        };
    }

    private static string NormalizePaymentStatusForUi(string value)
    {
        return (value ?? string.Empty).Trim().ToLowerInvariant() switch
        {
            "paid" => "completed",
            "pending" => "pending",
            "failed" => "failed",
            "refunded" => "refunded",
            _ => "pending"
        };
    }

    private static decimal RoundMoney(decimal value)
    {
        return Math.Round(value, 2, MidpointRounding.AwayFromZero);
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

    private static readonly HashSet<string> AllowedOrderStatuses =
    [
        "pending",
        "confirmed",
        "preparing",
        "ready",
        "completed",
        "cancelled"
    ];

    private sealed class AdminOrderRow
    {
        public int Id { get; init; }
        public string OrderNumber { get; init; } = string.Empty;
        public int UserId { get; init; }
        public int? CanteenId { get; init; }
        public decimal Subtotal { get; init; }
        public decimal Tax { get; init; }
        public decimal Total { get; init; }
        public string PaymentMethod { get; init; } = string.Empty;
        public string PaymentStatus { get; init; } = string.Empty;
        public string OrderStatus { get; init; } = string.Empty;
        public string CustomerName { get; init; } = string.Empty;
        public string CustomerPhone { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
        public string UserFirstName { get; init; } = string.Empty;
        public string UserLastName { get; init; } = string.Empty;
        public string UserEmail { get; init; } = string.Empty;
        public string CanteenName { get; init; } = string.Empty;
        public string DeliveryAddress { get; init; } = string.Empty;
        public string SpecialInstructions { get; init; } = string.Empty;
    }

    private sealed class CanteenOrderRow
    {
        public int Id { get; init; }
        public string OrderNumber { get; init; } = string.Empty;
        public int UserId { get; init; }
        public int? CanteenId { get; init; }
        public decimal Subtotal { get; init; }
        public decimal Tax { get; init; }
        public decimal Total { get; init; }
        public string PaymentMethod { get; init; } = string.Empty;
        public string PaymentStatus { get; init; } = string.Empty;
        public string OrderStatus { get; init; } = string.Empty;
        public string CustomerName { get; init; } = string.Empty;
        public string CustomerPhone { get; init; } = string.Empty;
        public string SpecialInstructions { get; init; } = string.Empty;
        public int EstimatedTime { get; init; }
        public DateTime CreatedAt { get; init; }
        public string UserFirstName { get; init; } = string.Empty;
        public string UserLastName { get; init; } = string.Empty;
        public string UserEmail { get; init; } = string.Empty;
        public string UserContact { get; init; } = string.Empty;
        public string CanteenName { get; init; } = string.Empty;
    }

    private sealed class CanteenOrderStatusRow
    {
        public int Id { get; init; }
        public int? CanteenId { get; init; }
        public string Status { get; init; } = string.Empty;
    }

    private sealed class OrderItemRow
    {
        public int Id { get; init; }
        public int OrderId { get; init; }
        public int MenuItemId { get; init; }
        public string ItemName { get; init; } = string.Empty;
        public int Quantity { get; init; }
        public decimal UnitPrice { get; init; }
        public decimal TotalPrice { get; init; }
    }

    private sealed class AdminWalletRow
    {
        public int UserId { get; init; }
        public string FirstName { get; init; } = string.Empty;
        public string LastName { get; init; } = string.Empty;
        public string Email { get; init; } = string.Empty;
        public decimal Balance { get; init; }
        public DateTime CreatedAt { get; init; }
    }

    private sealed class WalletStatsRow
    {
        public decimal TotalBalance { get; init; }
        public int ActiveWallets { get; init; }
        public decimal TotalCredits { get; init; }
        public decimal TotalDebits { get; init; }
    }

    private sealed class AdminWalletTransactionRow
    {
        public int Id { get; init; }
        public string TransactionId { get; init; } = string.Empty;
        public int UserId { get; init; }
        public decimal Amount { get; init; }
        public string Type { get; init; } = string.Empty;
        public string Status { get; init; } = string.Empty;
        public string Description { get; init; } = string.Empty;
        public int? OrderId { get; init; }
        public DateTime CreatedAt { get; init; }
        public string FirstName { get; init; } = string.Empty;
        public string LastName { get; init; } = string.Empty;
        public string Email { get; init; } = string.Empty;
    }

    public sealed class UpdateCanteenOrderStatusRequest
    {
        public string Status { get; init; } = string.Empty;
        public int? EstimatedTime { get; init; }
        public int? ChangedBy { get; init; }
        public string? Notes { get; init; }
        public int? CanteenId { get; init; }
    }
}
