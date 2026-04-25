using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Data;
using System.Data.Common;
using UniversityCanteen.Api.Data;

namespace UniversityCanteen.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/customer")]
public sealed class CustomerController(
    IDbConnectionFactory dbConnectionFactory,
    ILogger<CustomerController> logger) : ControllerBase
{
    [HttpGet("wallet")]
    public async Task<IActionResult> GetWallet([FromQuery] string identifier, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(identifier))
        {
            return BadRequest(Failure("Identifier is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            await EnsureWalletInfrastructureExists(connection, cancellationToken);

            // Simple direct lookup without schema detection
            var user = await connection.QuerySingleOrDefaultAsync<dynamic>(new CommandDefinition(
                """
                SELECT id, email FROM users
                WHERE email = @identifier
                   OR CAST(id AS CHAR) = @identifier
                   OR COALESCE(UniversityId, '') = @identifier
                LIMIT 1;
                """,
                new { identifier = identifier.Trim() },
                cancellationToken: cancellationToken));

            if (user is null)
            {
                return NotFound(Failure("User not found."));
            }

            int userId = user.id;
            await EnsureWalletExists(connection, userId, cancellationToken);

            var balance = await connection.ExecuteScalarAsync<decimal?>(new CommandDefinition(
                "SELECT COALESCE(balance, 0.00) FROM wallets WHERE user_id = @userId LIMIT 1;",
                new { userId },
                cancellationToken: cancellationToken)) ?? 0m;

            return Ok(Success("Wallet fetched successfully.", new WalletSummaryDto
            {
                Balance = Math.Round(balance, 2, MidpointRounding.AwayFromZero),
                Currency = "INR"
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch wallet for identifier {Identifier}: {ExceptionMessage}", identifier, ex.Message);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching wallet."));
        }
    }

    [HttpGet("wallet/transactions")]
    public async Task<IActionResult> GetWalletTransactions(
        [FromQuery] string identifier,
        [FromQuery] int limit = 20,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(identifier))
        {
            return BadRequest(Failure("Identifier is required."));
        }

        var normalizedLimit = Math.Clamp(limit, 1, 100);

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            await EnsureWalletInfrastructureExists(connection, cancellationToken);

            var user = await FindUserByIdentifier(connection, identifier.Trim(), cancellationToken);
            if (user is null)
            {
                return NotFound(Failure("User not found."));
            }

            await EnsureWalletExists(connection, user.Id, cancellationToken);

            var rows = await connection.QueryAsync<WalletTransactionRow>(new CommandDefinition(
                """
                SELECT
                    id AS Id,
                    transaction_id AS TransactionId,
                    amount AS Amount,
                    type AS Type,
                    status AS Status,
                    COALESCE(description, '') AS Description,
                    order_id AS OrderId,
                    created_at AS CreatedAt
                FROM wallet_transactions
                WHERE user_id = @userId
                ORDER BY created_at DESC
                LIMIT @limit;
                """,
                new
                {
                    userId = user.Id,
                    limit = normalizedLimit
                },
                cancellationToken: cancellationToken));

            var transactions = rows.Select(row => new WalletTransactionDto
            {
                Id = row.Id,
                TransactionId = row.TransactionId,
                Amount = Math.Round(row.Amount, 2, MidpointRounding.AwayFromZero),
                Type = row.Type,
                Status = row.Status,
                Description = row.Description,
                OrderId = row.OrderId,
                CreatedAt = row.CreatedAt
            }).ToList();

            return Ok(Success("Wallet transactions fetched successfully.", new
            {
                transactions,
                total = transactions.Count
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch wallet transactions for identifier {Identifier}", identifier);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching wallet transactions."));
        }
    }

    [HttpPost("wallet/recharge")]
    public async Task<IActionResult> RechargeWallet([FromBody] WalletRechargeRequest request, CancellationToken cancellationToken)
    {
        var identifier = request.Identifier?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(identifier))
        {
            return BadRequest(Failure("Identifier is required."));
        }

        if (request.Amount < 10m)
        {
            return BadRequest(Failure("Minimum recharge amount is INR 10."));
        }

        if (request.Amount > 100000m)
        {
            return BadRequest(Failure("Maximum recharge amount is INR 100000."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (connection is not DbConnection dbConnection)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, Failure("Database connection is not transaction-capable."));
            }

            await dbConnection.OpenAsync(cancellationToken);
            await EnsureWalletInfrastructureExists(dbConnection, cancellationToken);
            await using var transaction = await dbConnection.BeginTransactionAsync(cancellationToken);

            var user = await FindUserByIdentifier(dbConnection, identifier, cancellationToken, transaction);
            if (user is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return NotFound(Failure("User not found."));
            }

            await EnsureWalletExists(dbConnection, user.Id, cancellationToken, transaction);

            await dbConnection.ExecuteAsync(new CommandDefinition(
                "UPDATE wallets SET balance = balance + @amount WHERE user_id = @userId;",
                new
                {
                    userId = user.Id,
                    amount = request.Amount
                },
                transaction: transaction,
                cancellationToken: cancellationToken));

            var transactionId = BuildWalletTransactionId("CR");
            await dbConnection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO wallet_transactions
                    (user_id, transaction_id, amount, type, status, payment_gateway, description, created_at)
                VALUES
                    (@userId, @transactionId, @amount, 'credit', 'completed', @paymentGateway, @description, UTC_TIMESTAMP());
                """,
                new
                {
                    userId = user.Id,
                    transactionId,
                    amount = request.Amount,
                    paymentGateway = string.IsNullOrWhiteSpace(request.PaymentGateway) ? "manual" : request.PaymentGateway.Trim(),
                    description = string.IsNullOrWhiteSpace(request.Description) ? "Wallet recharge" : request.Description.Trim()
                },
                transaction: transaction,
                cancellationToken: cancellationToken));

            var balance = await dbConnection.ExecuteScalarAsync<decimal?>(new CommandDefinition(
                "SELECT COALESCE(balance, 0.00) FROM wallets WHERE user_id = @userId LIMIT 1;",
                new { userId = user.Id },
                transaction: transaction,
                cancellationToken: cancellationToken)) ?? 0m;

            await transaction.CommitAsync(cancellationToken);

            return Ok(Success("Wallet recharged successfully.", new
            {
                balance = Math.Round(balance, 2, MidpointRounding.AwayFromZero),
                amount = Math.Round(request.Amount, 2, MidpointRounding.AwayFromZero),
                transactionId
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to recharge wallet for identifier {Identifier}", identifier);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while recharging wallet."));
        }
    }

    [HttpGet("orders")]
    public async Task<IActionResult> GetOrders(
        [FromQuery] string identifier,
        [FromQuery] int limit = 20,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(identifier))
        {
            return BadRequest(Failure("Identifier is required."));
        }

        var normalizedLimit = Math.Clamp(limit, 1, 100);

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var user = await FindUserByIdentifier(connection, identifier.Trim(), cancellationToken);
            if (user is null)
            {
                return NotFound(Failure("User not found."));
            }

            var rows = await connection.QueryAsync<OrderSummaryRow>(new CommandDefinition(
                """
                SELECT
                    o.id AS Id,
                    o.order_number AS OrderNumber,
                    COALESCE(o.total_amount, 0.00) AS Subtotal,
                    COALESCE(o.tax_amount, 0.00) AS Tax,
                    COALESCE(o.final_amount, 0.00) AS Total,
                    COALESCE(o.payment_method, 'cash') AS PaymentMethod,
                    COALESCE(o.payment_status, 'pending') AS PaymentStatus,
                    COALESCE(o.order_status, 'pending') AS OrderStatus,
                    o.created_at AS CreatedAt,
                    (
                        SELECT COUNT(1)
                        FROM order_items oi
                        WHERE oi.order_id = o.id
                    ) AS ItemCount
                FROM orders o
                WHERE o.user_id = @userId
                ORDER BY o.created_at DESC
                LIMIT @limit;
                """,
                new
                {
                    userId = user.Id,
                    limit = normalizedLimit
                },
                cancellationToken: cancellationToken));

            var orders = rows.Select(row => new OrderSummaryDto
            {
                Id = row.Id,
                OrderNumber = row.OrderNumber,
                Subtotal = Math.Round(row.Subtotal, 2, MidpointRounding.AwayFromZero),
                Tax = Math.Round(row.Tax, 2, MidpointRounding.AwayFromZero),
                Total = Math.Round(row.Total, 2, MidpointRounding.AwayFromZero),
                PaymentMethod = row.PaymentMethod,
                PaymentStatus = row.PaymentStatus,
                Status = row.OrderStatus,
                CreatedAt = row.CreatedAt,
                ItemCount = row.ItemCount
            }).ToList();

            return Ok(Success("Orders fetched successfully.", new
            {
                orders,
                total = orders.Count
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch orders for identifier {Identifier}", identifier);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching orders."));
        }
    }

    [HttpGet("orders/{orderRef}")]
    public async Task<IActionResult> GetOrderDetails(
        string orderRef,
        [FromQuery] string identifier,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(orderRef))
        {
            return BadRequest(Failure("Order reference is required."));
        }

        if (string.IsNullOrWhiteSpace(identifier))
        {
            return BadRequest(Failure("Identifier is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var user = await FindUserByIdentifier(connection, identifier.Trim(), cancellationToken);
            if (user is null)
            {
                return NotFound(Failure("User not found."));
            }

            var order = await connection.QuerySingleOrDefaultAsync<OrderDetailRow>(new CommandDefinition(
                """
                SELECT
                    o.id AS Id,
                    o.order_number AS OrderNumber,
                    COALESCE(o.total_amount, 0.00) AS Subtotal,
                    COALESCE(o.tax_amount, 0.00) AS Tax,
                    COALESCE(o.final_amount, 0.00) AS Total,
                    COALESCE(o.payment_method, 'cash') AS PaymentMethod,
                    COALESCE(o.payment_status, 'pending') AS PaymentStatus,
                    COALESCE(o.order_status, 'pending') AS OrderStatus,
                    o.created_at AS CreatedAt
                FROM orders o
                WHERE o.user_id = @userId
                  AND (o.order_number = @orderRef OR CAST(o.id AS CHAR) = @orderRef)
                LIMIT 1;
                """,
                new
                {
                    userId = user.Id,
                    orderRef = orderRef.Trim()
                },
                cancellationToken: cancellationToken));

            if (order is null)
            {
                return NotFound(Failure("Order not found."));
            }

            var items = (await connection.QueryAsync<OrderItemRow>(new CommandDefinition(
                """
                SELECT
                    oi.id AS Id,
                    oi.menu_item_id AS MenuItemId,
                    COALESCE(oi.item_name, 'Item') AS ItemName,
                    COALESCE(oi.quantity, 1) AS Quantity,
                    COALESCE(oi.unit_price, 0.00) AS UnitPrice,
                    COALESCE(oi.total_price, 0.00) AS TotalPrice
                FROM order_items oi
                WHERE oi.order_id = @orderId
                ORDER BY oi.id ASC;
                """,
                new { orderId = order.Id },
                cancellationToken: cancellationToken))).ToList();

            var historyRows = (await connection.QueryAsync<OrderHistoryRow>(new CommandDefinition(
                """
                SELECT
                    COALESCE(osh.new_status, 'pending') AS Status,
                    osh.created_at AS CreatedAt
                FROM order_status_history osh
                WHERE osh.order_id = @orderId
                ORDER BY osh.created_at ASC;
                """,
                new { orderId = order.Id },
                cancellationToken: cancellationToken))).ToList();

            var data = new OrderDetailDto
            {
                Id = order.Id,
                OrderNumber = order.OrderNumber,
                Subtotal = Math.Round(order.Subtotal, 2, MidpointRounding.AwayFromZero),
                Tax = Math.Round(order.Tax, 2, MidpointRounding.AwayFromZero),
                Total = Math.Round(order.Total, 2, MidpointRounding.AwayFromZero),
                PaymentMethod = order.PaymentMethod,
                PaymentStatus = order.PaymentStatus,
                Status = order.OrderStatus,
                CreatedAt = order.CreatedAt,
                Items = items.Select(item => new OrderItemDto
                {
                    Id = item.Id,
                    MenuItemId = item.MenuItemId,
                    ItemName = item.ItemName,
                    Quantity = item.Quantity,
                    UnitPrice = Math.Round(item.UnitPrice, 2, MidpointRounding.AwayFromZero),
                    TotalPrice = Math.Round(item.TotalPrice, 2, MidpointRounding.AwayFromZero)
                }).ToList(),
                StatusHistory = historyRows.Select(history => new OrderStatusHistoryDto
                {
                    Status = history.Status,
                    CreatedAt = history.CreatedAt
                }).ToList()
            };

            return Ok(Success("Order details fetched successfully.", data));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch order details for orderRef {OrderRef} and identifier {Identifier}", orderRef, identifier);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching order details."));
        }
    }

    [HttpPost("orders")]
    public async Task<IActionResult> PlaceOrder([FromBody] PlaceOrderRequest request, CancellationToken cancellationToken)
    {
        var identifier = request.Identifier?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(identifier))
        {
            return BadRequest(Failure("Identifier is required."));
        }

        if (request.Items is null || request.Items.Count == 0)
        {
            return BadRequest(Failure("At least one order item is required."));
        }

        var validatedItems = new List<ValidatedOrderItem>();
        decimal subtotal = 0m;

        foreach (var item in request.Items)
        {
            var menuItemId = item.MenuItemId ?? item.Id ?? 0;
            if (menuItemId <= 0)
            {
                return BadRequest(Failure("Each item must include a valid menu item id."));
            }

            var quantity = item.Quantity < 1 ? 1 : item.Quantity;
            var unitPrice = Math.Round(item.UnitPrice, 2, MidpointRounding.AwayFromZero);
            if (unitPrice < 0.01m)
            {
                return BadRequest(Failure("Each item must include a valid unit price."));
            }

            var lineTotal = Math.Round(unitPrice * quantity, 2, MidpointRounding.AwayFromZero);
            subtotal += lineTotal;

            validatedItems.Add(new ValidatedOrderItem
            {
                MenuItemId = menuItemId,
                ItemName = string.IsNullOrWhiteSpace(item.ItemName) ? $"Item {menuItemId}" : item.ItemName.Trim(),
                Quantity = quantity,
                UnitPrice = unitPrice,
                TotalPrice = lineTotal,
                SpecialInstructions = item.SpecialInstructions?.Trim()
            });
        }

        var tax = Math.Round(subtotal * 0.05m, 2, MidpointRounding.AwayFromZero);
        var total = Math.Round(subtotal + tax, 2, MidpointRounding.AwayFromZero);

        if (total <= 0m)
        {
            return BadRequest(Failure("Order total must be greater than zero."));
        }

        var walletRequested = string.Equals(request.PaymentMethod?.Trim(), "wallet", StringComparison.OrdinalIgnoreCase);
        var paymentMethod = NormalizePaymentMethod(request.PaymentMethod);
        var paymentStatus = paymentMethod == "cash" ? "pending" : "paid";
        var orderType = NormalizeOrderType(request.OrderType);

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (connection is not DbConnection dbConnection)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, Failure("Database connection is not transaction-capable."));
            }

            await dbConnection.OpenAsync(cancellationToken);
            await EnsureWalletInfrastructureExists(dbConnection, cancellationToken);
            await using var transaction = await dbConnection.BeginTransactionAsync(cancellationToken);

            var user = await FindUserByIdentifier(dbConnection, identifier, cancellationToken, transaction);
            if (user is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return NotFound(Failure("User not found."));
            }

            await EnsureWalletExists(dbConnection, user.Id, cancellationToken, transaction);

            decimal? remainingWalletBalance = null;
            if (walletRequested)
            {
                var walletBalance = await dbConnection.ExecuteScalarAsync<decimal?>(new CommandDefinition(
                    "SELECT COALESCE(balance, 0.00) FROM wallets WHERE user_id = @userId FOR UPDATE;",
                    new { userId = user.Id },
                    transaction: transaction,
                    cancellationToken: cancellationToken)) ?? 0m;

                if (walletBalance < total)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return BadRequest(Failure($"Insufficient wallet balance. Required INR {total:0.00}, available INR {walletBalance:0.00}."));
                }
            }

            var orderNumber = BuildOrderNumber();
            var orderId = await dbConnection.ExecuteScalarAsync<long>(new CommandDefinition(
                """
                INSERT INTO orders
                    (user_id, canteen_id, order_number, customer_name, customer_phone, delivery_address, order_type, table_number,
                     total_amount, discount_amount, tax_amount, final_amount, payment_method, payment_status, order_status,
                     special_instructions, estimated_time, created_at, updated_at)
                VALUES
                    (@userId, @canteenId, @orderNumber, @customerName, @customerPhone, @deliveryAddress, @orderType, @tableNumber,
                     @subtotal, 0.00, @tax, @total, @paymentMethod, @paymentStatus, 'pending',
                     @specialInstructions, NULL, UTC_TIMESTAMP(), UTC_TIMESTAMP());
                SELECT LAST_INSERT_ID();
                """,
                new
                {
                    userId = user.Id,
                    canteenId = request.CanteenId is > 0 ? request.CanteenId : null,
                    orderNumber,
                    customerName = string.IsNullOrWhiteSpace(request.CustomerName) ? user.Name : request.CustomerName.Trim(),
                    customerPhone = string.IsNullOrWhiteSpace(request.CustomerPhone) ? null : request.CustomerPhone.Trim(),
                    deliveryAddress = string.IsNullOrWhiteSpace(request.DeliveryAddress) ? null : request.DeliveryAddress.Trim(),
                    orderType,
                    tableNumber = string.IsNullOrWhiteSpace(request.TableNumber) ? null : request.TableNumber.Trim(),
                    subtotal,
                    tax,
                    total,
                    paymentMethod,
                    paymentStatus,
                    specialInstructions = string.IsNullOrWhiteSpace(request.SpecialInstructions) ? null : request.SpecialInstructions.Trim()
                },
                transaction: transaction,
                cancellationToken: cancellationToken));

            foreach (var item in validatedItems)
            {
                await dbConnection.ExecuteAsync(new CommandDefinition(
                    """
                    INSERT INTO order_items
                        (order_id, menu_item_id, item_name, quantity, unit_price, total_price, special_instructions, created_at)
                    VALUES
                        (@orderId, @menuItemId, @itemName, @quantity, @unitPrice, @totalPrice, @specialInstructions, UTC_TIMESTAMP());
                    """,
                    new
                    {
                        orderId,
                        menuItemId = item.MenuItemId,
                        itemName = item.ItemName,
                        quantity = item.Quantity,
                        unitPrice = item.UnitPrice,
                        totalPrice = item.TotalPrice,
                        specialInstructions = string.IsNullOrWhiteSpace(item.SpecialInstructions) ? null : item.SpecialInstructions
                    },
                    transaction: transaction,
                    cancellationToken: cancellationToken));
            }

            if (walletRequested)
            {
                await dbConnection.ExecuteAsync(new CommandDefinition(
                    "UPDATE wallets SET balance = balance - @amount WHERE user_id = @userId;",
                    new
                    {
                        userId = user.Id,
                        amount = total
                    },
                    transaction: transaction,
                    cancellationToken: cancellationToken));

                var transactionId = BuildWalletTransactionId("DB");
                await dbConnection.ExecuteAsync(new CommandDefinition(
                    """
                    INSERT INTO wallet_transactions
                        (user_id, transaction_id, amount, type, status, payment_gateway, description, order_id, created_at)
                    VALUES
                        (@userId, @transactionId, @amount, 'debit', 'completed', 'wallet', @description, @orderId, UTC_TIMESTAMP());
                    """,
                    new
                    {
                        userId = user.Id,
                        transactionId,
                        amount = total,
                        description = $"Order payment - {orderNumber}",
                        orderId
                    },
                    transaction: transaction,
                    cancellationToken: cancellationToken));

                remainingWalletBalance = await dbConnection.ExecuteScalarAsync<decimal?>(new CommandDefinition(
                    "SELECT COALESCE(balance, 0.00) FROM wallets WHERE user_id = @userId LIMIT 1;",
                    new { userId = user.Id },
                    transaction: transaction,
                    cancellationToken: cancellationToken));
            }

            await transaction.CommitAsync(cancellationToken);

            var response = new
            {
                id = orderId,
                orderNumber,
                subtotal,
                tax,
                total,
                paymentMethod = walletRequested ? "wallet" : paymentMethod,
                paymentStatus,
                status = "pending",
                createdAt = DateTime.UtcNow,
                walletBalance = remainingWalletBalance.HasValue
                    ? Math.Round(remainingWalletBalance.Value, 2, MidpointRounding.AwayFromZero)
                    : (decimal?)null
            };

            return Ok(Success("Order placed successfully.", response));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to place order for identifier {Identifier}", identifier);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while placing order."));
        }
    }

    [AllowAnonymous]
    [HttpPost("reviews")]
    public async Task<IActionResult> SubmitReview([FromBody] SubmitReviewRequest request, CancellationToken cancellationToken = default)
    {
        var identifier = request.Identifier?.Trim() ?? string.Empty;
        var orderRef = request.OrderRef?.Trim() ?? string.Empty;
        var reviewText = request.ReviewText?.Trim() ?? string.Empty;

        if (string.IsNullOrWhiteSpace(identifier))
        {
            return BadRequest(Failure("Identifier is required."));
        }

        if (string.IsNullOrWhiteSpace(orderRef))
        {
            return BadRequest(Failure("Order reference is required."));
        }

        if (request.Rating is < 1 or > 5)
        {
            return BadRequest(Failure("Rating must be between 1 and 5."));
        }

        if (string.IsNullOrWhiteSpace(reviewText))
        {
            return BadRequest(Failure("Review text is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var user = await FindUserByIdentifier(connection, identifier, cancellationToken);
            if (user is null)
            {
                return NotFound(Failure("User not found."));
            }

            var order = await connection.QuerySingleOrDefaultAsync<OrderReviewLookupRow>(new CommandDefinition(
                """
                SELECT
                    o.id AS OrderId,
                    COALESCE(o.canteen_id, 0) AS CanteenId
                FROM orders o
                WHERE o.user_id = @userId
                  AND (o.order_number = @orderRef OR CAST(o.id AS CHAR) = @orderRef)
                LIMIT 1;
                """,
                new
                {
                    userId = user.Id,
                    orderRef
                },
                cancellationToken: cancellationToken));

            if (order is null)
            {
                return NotFound(Failure("Order not found."));
            }

            if (order.CanteenId <= 0)
            {
                return BadRequest(Failure("This order is not linked to a canteen."));
            }

            var alreadyExists = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
                "SELECT COUNT(1) FROM reviews WHERE user_id = @userId AND order_id = @orderId;",
                new
                {
                    userId = user.Id,
                    orderId = order.OrderId
                },
                cancellationToken: cancellationToken));

            if (alreadyExists > 0)
            {
                return BadRequest(Failure("Feedback already submitted for this order."));
            }

            await connection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO reviews
                    (user_id, canteen_id, order_id, rating, review_text, status, created_at)
                VALUES
                    (@userId, @canteenId, @orderId, @rating, @reviewText, 'active', UTC_TIMESTAMP());
                """,
                new
                {
                    userId = user.Id,
                    canteenId = order.CanteenId,
                    orderId = order.OrderId,
                    rating = request.Rating,
                    reviewText
                },
                cancellationToken: cancellationToken));

            return Ok(Success("Thank you! Your review has been submitted.", new
            {
                orderId = order.OrderId,
                rating = request.Rating
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to submit review for identifier {Identifier} and orderRef {OrderRef}", identifier, orderRef);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while submitting review."));
        }
    }

    [HttpPost("contact-messages")]
    public async Task<IActionResult> SubmitContactMessage([FromBody] SubmitContactMessageRequest request, CancellationToken cancellationToken = default)
    {
        var identifier = request.Identifier?.Trim() ?? string.Empty;
        var subject = request.Subject?.Trim() ?? string.Empty;
        var message = request.Message?.Trim() ?? string.Empty;

        if (string.IsNullOrWhiteSpace(identifier))
        {
            return BadRequest(Failure("Identifier is required."));
        }

        if (string.IsNullOrWhiteSpace(message))
        {
            return BadRequest(Failure("Message is required."));
        }

        if (string.IsNullOrWhiteSpace(subject))
        {
            subject = "Customer Support Request";
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var user = await FindUserByIdentifier(connection, identifier, cancellationToken);
            if (user is null)
            {
                return NotFound(Failure("User not found."));
            }

            var name = string.IsNullOrWhiteSpace(request.Name) ? user.Name : request.Name.Trim();
            var email = string.IsNullOrWhiteSpace(request.Email) ? user.Email : request.Email.Trim();

            if (string.IsNullOrWhiteSpace(email))
            {
                return BadRequest(Failure("Email is required."));
            }

            await connection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO contact_messages
                    (name, email, subject, message, status, created_at)
                VALUES
                    (@name, @email, @subject, @message, 'unread', UTC_TIMESTAMP());
                """,
                new
                {
                    name,
                    email,
                    subject,
                    message
                },
                cancellationToken: cancellationToken));

            return Ok(Success("Contact message sent successfully.", new
            {
                name,
                email,
                subject
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to submit contact message for identifier {Identifier}", identifier);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while sending contact message."));
        }
    }

    private static async Task EnsureWalletExists(
        IDbConnection connection,
        int userId,
        CancellationToken cancellationToken,
        IDbTransaction? transaction = null)
    {
        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO wallets (user_id, balance)
            VALUES (@userId, 0.00)
            ON DUPLICATE KEY UPDATE user_id = VALUES(user_id);
            """,
            new { userId },
            transaction: transaction,
            cancellationToken: cancellationToken));
    }

    private static async Task EnsureWalletInfrastructureExists(
        IDbConnection connection,
        CancellationToken cancellationToken)
    {
        // CREATE TABLE requires CREATE privilege. If the DB user only has DML privileges,
        // MySQL throws error 1142 even when IF NOT EXISTS would be a no-op.
        // The startup migration in Program.cs already creates these tables; this is a safety net.
        // Swallow the privilege error so wallet requests don't fail when tables already exist.
        try
        {
            await connection.ExecuteAsync(new CommandDefinition(
                """
                CREATE TABLE IF NOT EXISTS wallets (
                    id INT NOT NULL AUTO_INCREMENT,
                    user_id INT NOT NULL,
                    balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    UNIQUE KEY uq_wallets_user_id (user_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
                """,
                cancellationToken: cancellationToken));

            await connection.ExecuteAsync(new CommandDefinition(
                """
                CREATE TABLE IF NOT EXISTS wallet_transactions (
                    id BIGINT NOT NULL AUTO_INCREMENT,
                    user_id INT NOT NULL,
                    transaction_id VARCHAR(100) NOT NULL,
                    amount DECIMAL(10,2) NOT NULL,
                    type ENUM('credit','debit') NOT NULL,
                    status ENUM('pending','completed','failed','refunded') NOT NULL DEFAULT 'pending',
                    payment_gateway VARCHAR(50) NULL,
                    gateway_order_id VARCHAR(100) NULL,
                    gateway_payment_id VARCHAR(100) NULL,
                    gateway_signature VARCHAR(255) NULL,
                    description TEXT NULL,
                    order_id INT NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    UNIQUE KEY uq_wallet_transactions_txn_id (transaction_id),
                    KEY ix_wallet_transactions_user (user_id),
                    KEY ix_wallet_transactions_created (created_at)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
                """,
                cancellationToken: cancellationToken));
        }
        catch (MySqlConnector.MySqlException)
        {
            // Best-effort safety net. Startup migration (Program.cs) owns table creation.
            // Any MySQL failure here (privilege denied, table exists, connection blip) is
            // ignored; subsequent wallet queries will surface the real error if tables are missing.
        }
    }

    private static async Task<UserLookupRow?> FindUserByIdentifier(
        IDbConnection connection,
        string identifier,
        CancellationToken cancellationToken,
        IDbTransaction? transaction = null)
    {
        try
        {
            var schema = await ResolveUsersSchema(connection, cancellationToken, transaction);
            var sql = BuildUserLookupSql(schema);

            return await connection.QuerySingleOrDefaultAsync<UserLookupRow>(new CommandDefinition(
                sql,
                new { identifier },
                transaction: transaction,
                cancellationToken: cancellationToken));
        }
        catch (Exception ex)
        {
            // Log the error but don't throw - let the caller handle the null return
            throw new InvalidOperationException($"Failed to find user by identifier {identifier}: {ex.Message}", ex);
        }
    }

    private static async Task<UsersSchemaInfo> ResolveUsersSchema(
        IDbConnection connection,
        CancellationToken cancellationToken,
        IDbTransaction? transaction)
    {
        try
        {
            var hasCafeId = await ColumnExistsByProbe(connection, "id", cancellationToken, transaction);
            var hasCafeEmail = await ColumnExistsByProbe(connection, "email", cancellationToken, transaction);
            var hasCafeColumns = hasCafeId && hasCafeEmail;
            if (!hasCafeColumns)
            {
                throw new InvalidOperationException("Unsupported users schema for customer operations. Expected users.id and users.email columns.");
            }

            var hasFirstName = await ColumnExistsByProbe(connection, "first_name", cancellationToken, transaction);
            var hasLastName = await ColumnExistsByProbe(connection, "last_name", cancellationToken, transaction);

            return new UsersSchemaInfo
            {
                HasEnrollmentNo = await ColumnExistsByProbe(connection, "enrollment_no", cancellationToken, transaction),
                HasUniversityId = await ColumnExistsByProbe(connection, "UniversityId", cancellationToken, transaction),
                HasFirstName = hasFirstName,
                HasLastName = hasLastName
            };
        }
        catch (Exception ex)
        {
            // Schema detection failed, use sensible defaults that assume standard schema
            // Assumes: id, email, UniversityId exist (for enrollment lookup)
            return new UsersSchemaInfo
            {
                HasEnrollmentNo = false,
                HasUniversityId = true,  // Assume UniversityId exists (enrollment numbers)
                HasFirstName = false,
                HasLastName = false
            };
        }
    }

    private static async Task<bool> ColumnExistsByProbe(
        IDbConnection connection,
        string columnName,
        CancellationToken cancellationToken,
        IDbTransaction? transaction)
    {
        var sql = $"SELECT `{columnName}` FROM users LIMIT 1;";

        try
        {
            await connection.ExecuteScalarAsync(new CommandDefinition(
                sql,
                transaction: transaction,
                cancellationToken: cancellationToken));

            return true;
        }
        catch (Exception ex) when (ex.Message.Contains("Unknown column", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }
        catch
        {
            // If any other error occurs during column detection, treat as column doesn't exist
            // rather than failing the entire wallet request
            return false;
        }
    }

    private static string BuildUserLookupSql(UsersSchemaInfo schema)
    {
        var firstNameExpression = schema.HasFirstName ? "COALESCE(u.first_name, '')" : "''";
        var lastNameExpression = schema.HasLastName ? "COALESCE(u.last_name, '')" : "''";

        var fullNameExpression = schema.HasFirstName || schema.HasLastName
            ? $"COALESCE(NULLIF(TRIM(CONCAT({firstNameExpression}, ' ', {lastNameExpression})), ''), u.email)"
            : "u.email";

        var universityIdExpression = schema.HasUniversityId
            ? "COALESCE(u.UniversityId, CAST(u.id AS CHAR))"
            : "CAST(u.id AS CHAR)";

        var enrollmentCondition = schema.HasEnrollmentNo
            ? "\n               OR COALESCE(u.enrollment_no, '') = @identifier"
            : string.Empty;

        var universityIdCondition = schema.HasUniversityId
            ? "\n               OR COALESCE(u.UniversityId, '') = @identifier"
            : string.Empty;

        return $"""
            SELECT
                u.id AS Id,
                {universityIdExpression} AS UniversityId,
                COALESCE(u.email, '') AS Email,
                {fullNameExpression} AS Name
            FROM users u
            WHERE u.email = @identifier
               OR CAST(u.id AS CHAR) = @identifier{enrollmentCondition}{universityIdCondition}
            LIMIT 1;
            """;
    }

    private static string NormalizePaymentMethod(string? paymentMethod)
    {
        var value = paymentMethod?.Trim().ToLowerInvariant();

        return value switch
        {
            "wallet" => "online",
            "online" => "online",
            "upi" => "upi",
            "card" => "card",
            "cash" => "cash",
            _ => "cash"
        };
    }

    private static string NormalizeOrderType(string? orderType)
    {
        var value = orderType?.Trim().ToLowerInvariant();

        return value switch
        {
            "dine_in" => "dine_in",
            "takeaway" => "takeaway",
            "delivery" => "delivery",
            _ => "dine_in"
        };
    }

    private static string BuildOrderNumber()
    {
        return $"FO{DateTime.UtcNow:yyMMddHHmmss}{Random.Shared.Next(100, 999)}";
    }

    private static string BuildWalletTransactionId(string prefix)
    {
        return $"{prefix}{DateTime.UtcNow:yyyyMMddHHmmss}{Random.Shared.Next(1000, 9999)}";
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

    private sealed class UsersSchemaInfo
    {
        public bool HasEnrollmentNo { get; init; }
        public bool HasUniversityId { get; init; }
        public bool HasFirstName { get; init; }
        public bool HasLastName { get; init; }
    }

    private sealed class UserLookupRow
    {
        public int Id { get; init; }
        public string UniversityId { get; init; } = string.Empty;
        public string Email { get; init; } = string.Empty;
        public string Name { get; init; } = string.Empty;
    }

    public sealed class WalletRechargeRequest
    {
        public string Identifier { get; init; } = string.Empty;
        public decimal Amount { get; init; }
        public string? PaymentGateway { get; init; }
        public string? Description { get; init; }
    }

    public sealed class PlaceOrderRequest
    {
        public string Identifier { get; init; } = string.Empty;
        public int? CanteenId { get; init; }
        public string? CustomerName { get; init; }
        public string? CustomerPhone { get; init; }
        public string? DeliveryAddress { get; init; }
        public string? OrderType { get; init; }
        public string? TableNumber { get; init; }
        public string? PaymentMethod { get; init; }
        public string? SpecialInstructions { get; init; }
        public List<PlaceOrderItemRequest> Items { get; init; } = [];
    }

    public sealed class PlaceOrderItemRequest
    {
        public int? Id { get; init; }
        public int? MenuItemId { get; init; }
        public string? ItemName { get; init; }
        public int Quantity { get; init; } = 1;
        public decimal UnitPrice { get; init; }
        public string? SpecialInstructions { get; init; }
    }

    public sealed class SubmitReviewRequest
    {
        public string Identifier { get; init; } = string.Empty;
        public string OrderRef { get; init; } = string.Empty;
        public int Rating { get; init; }
        public string ReviewText { get; init; } = string.Empty;
    }

    public sealed class SubmitContactMessageRequest
    {
        public string Identifier { get; init; } = string.Empty;
        public string? Name { get; init; }
        public string? Email { get; init; }
        public string? Subject { get; init; }
        public string Message { get; init; } = string.Empty;
    }

    private sealed class ValidatedOrderItem
    {
        public int MenuItemId { get; init; }
        public string ItemName { get; init; } = string.Empty;
        public int Quantity { get; init; }
        public decimal UnitPrice { get; init; }
        public decimal TotalPrice { get; init; }
        public string? SpecialInstructions { get; init; }
    }

    private sealed class WalletSummaryDto
    {
        public decimal Balance { get; init; }
        public string Currency { get; init; } = "INR";
    }

    private sealed class WalletTransactionRow
    {
        public int Id { get; init; }
        public string TransactionId { get; init; } = string.Empty;
        public decimal Amount { get; init; }
        public string Type { get; init; } = string.Empty;
        public string Status { get; init; } = string.Empty;
        public string Description { get; init; } = string.Empty;
        public int? OrderId { get; init; }
        public DateTime CreatedAt { get; init; }
    }

    private sealed class WalletTransactionDto
    {
        public int Id { get; init; }
        public string TransactionId { get; init; } = string.Empty;
        public decimal Amount { get; init; }
        public string Type { get; init; } = string.Empty;
        public string Status { get; init; } = string.Empty;
        public string Description { get; init; } = string.Empty;
        public int? OrderId { get; init; }
        public DateTime CreatedAt { get; init; }
    }

    private sealed class OrderSummaryRow
    {
        public int Id { get; init; }
        public string OrderNumber { get; init; } = string.Empty;
        public decimal Subtotal { get; init; }
        public decimal Tax { get; init; }
        public decimal Total { get; init; }
        public string PaymentMethod { get; init; } = string.Empty;
        public string PaymentStatus { get; init; } = string.Empty;
        public string OrderStatus { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
        public int ItemCount { get; init; }
    }

    private sealed class OrderSummaryDto
    {
        public int Id { get; init; }
        public string OrderNumber { get; init; } = string.Empty;
        public decimal Subtotal { get; init; }
        public decimal Tax { get; init; }
        public decimal Total { get; init; }
        public string PaymentMethod { get; init; } = string.Empty;
        public string PaymentStatus { get; init; } = string.Empty;
        public string Status { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
        public int ItemCount { get; init; }
    }

    private sealed class OrderDetailRow
    {
        public int Id { get; init; }
        public string OrderNumber { get; init; } = string.Empty;
        public decimal Subtotal { get; init; }
        public decimal Tax { get; init; }
        public decimal Total { get; init; }
        public string PaymentMethod { get; init; } = string.Empty;
        public string PaymentStatus { get; init; } = string.Empty;
        public string OrderStatus { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
    }

    private sealed class OrderItemRow
    {
        public int Id { get; init; }
        public int MenuItemId { get; init; }
        public string ItemName { get; init; } = string.Empty;
        public int Quantity { get; init; }
        public decimal UnitPrice { get; init; }
        public decimal TotalPrice { get; init; }
    }

    private sealed class OrderHistoryRow
    {
        public string Status { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
    }

    private sealed class OrderReviewLookupRow
    {
        public int OrderId { get; init; }
        public int CanteenId { get; init; }
    }

    private sealed class OrderDetailDto
    {
        public int Id { get; init; }
        public string OrderNumber { get; init; } = string.Empty;
        public decimal Subtotal { get; init; }
        public decimal Tax { get; init; }
        public decimal Total { get; init; }
        public string PaymentMethod { get; init; } = string.Empty;
        public string PaymentStatus { get; init; } = string.Empty;
        public string Status { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
        public List<OrderItemDto> Items { get; init; } = [];
        public List<OrderStatusHistoryDto> StatusHistory { get; init; } = [];
    }

    private sealed class OrderItemDto
    {
        public int Id { get; init; }
        public int MenuItemId { get; init; }
        public string ItemName { get; init; } = string.Empty;
        public int Quantity { get; init; }
        public decimal UnitPrice { get; init; }
        public decimal TotalPrice { get; init; }
    }

    private sealed class OrderStatusHistoryDto
    {
        public string Status { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
    }
}
