using System.Data;
using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using UniversityCanteen.Api.Configuration;
using UniversityCanteen.Api.Data;

namespace UniversityCanteen.Api.Controllers;

[ApiController]
[Authorize]
[Route("api")]
public sealed class ReportsController(
    IDbConnectionFactory dbConnectionFactory,
    IOptions<AuthOptions> authOptions,
    ILogger<ReportsController> logger) : ControllerBase
{
    private static readonly HashSet<string> AllowedOrderStatuses =
    [
        "pending",
        "confirmed",
        "preparing",
        "ready",
        "completed",
        "cancelled"
    ];

    private readonly AuthOptions _authOptions = authOptions.Value;

    [HttpGet("admin/reports")]
    public async Task<IActionResult> GetAdminReports(
        [FromQuery] string? fromDate,
        [FromQuery] string? toDate,
        [FromQuery] int? canteenId,
        [FromQuery] string? status,
        CancellationToken cancellationToken = default)
    {
        if (!TryResolveDateRange(fromDate, toDate, out var startDate, out var endDate, out var endExclusive, out var rangeError))
        {
            return BadRequest(Failure(rangeError ?? "Invalid date range."));
        }

        var normalizedStatus = NormalizeReportStatus(status);
        if (!string.IsNullOrWhiteSpace(status) && normalizedStatus == string.Empty)
        {
            return BadRequest(Failure("Invalid status filter supplied."));
        }

        var normalizedCanteenId = canteenId.GetValueOrDefault();
        if (normalizedCanteenId < 0)
        {
            return BadRequest(Failure("Invalid canteen filter supplied."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("You are not authorized to view admin reports."));
            }

            var whereClauses = new List<string>
            {
                "o.created_at >= @fromDate",
                "o.created_at < @toDate"
            };

            if (normalizedCanteenId > 0)
            {
                whereClauses.Add("o.canteen_id = @canteenId");
            }

            if (normalizedStatus == "all")
            {
                // explicit all status selection keeps all orders in analytics
            }
            else if (normalizedStatus != string.Empty)
            {
                whereClauses.Add("o.order_status = @status");
            }
            else
            {
                whereClauses.Add("o.order_status <> 'cancelled'");
            }

            var whereSql = string.Join(" AND ", whereClauses);
            const string moneyExpression = "COALESCE(NULLIF(o.final_amount, 0.00), o.total_amount, 0.00)";

            var parameters = new DynamicParameters();
            parameters.Add("fromDate", startDate);
            parameters.Add("toDate", endExclusive);
            parameters.Add("canteenId", normalizedCanteenId > 0 ? normalizedCanteenId : null);
            parameters.Add("status", normalizedStatus == string.Empty || normalizedStatus == "all" ? null : normalizedStatus);

            var summary = await connection.QuerySingleAsync<AdminSummaryRow>(new CommandDefinition(
                $"""
                SELECT
                    COUNT(1) AS TotalOrders,
                    COALESCE(SUM({moneyExpression}), 0.00) AS TotalRevenue,
                    COALESCE(SUM(COALESCE(o.tax_amount, 0.00)), 0.00) AS TotalTax
                FROM orders o
                WHERE {whereSql};
                """,
                parameters,
                cancellationToken: cancellationToken));

            var dailyTrend = (await connection.QueryAsync<DailyTrendRow>(new CommandDefinition(
                $"""
                SELECT
                    DATE(o.created_at) AS DayDate,
                    COUNT(1) AS TotalOrders,
                    COALESCE(SUM({moneyExpression}), 0.00) AS Revenue
                FROM orders o
                WHERE {whereSql}
                GROUP BY DATE(o.created_at)
                ORDER BY DayDate ASC;
                """,
                parameters,
                cancellationToken: cancellationToken))).ToList();

            var paymentBreakdown = (await connection.QueryAsync<PaymentBreakdownRow>(new CommandDefinition(
                $"""
                SELECT
                    LOWER(COALESCE(o.payment_method, 'cash')) AS PaymentMethod,
                    COUNT(1) AS TotalOrders,
                    COALESCE(SUM({moneyExpression}), 0.00) AS Revenue
                FROM orders o
                WHERE {whereSql}
                GROUP BY LOWER(COALESCE(o.payment_method, 'cash'))
                ORDER BY Revenue DESC;
                """,
                parameters,
                cancellationToken: cancellationToken))).ToList();

            var canteenSales = (await connection.QueryAsync<CanteenSalesRow>(new CommandDefinition(
                $"""
                SELECT
                    COALESCE(o.canteen_id, 0) AS CanteenId,
                    COALESCE(c.name, 'Unknown') AS CanteenName,
                    COUNT(1) AS TotalOrders,
                    COALESCE(SUM({moneyExpression}), 0.00) AS Revenue
                FROM orders o
                LEFT JOIN canteens c ON c.id = o.canteen_id
                WHERE {whereSql}
                GROUP BY COALESCE(o.canteen_id, 0), COALESCE(c.name, 'Unknown')
                ORDER BY Revenue DESC;
                """,
                parameters,
                cancellationToken: cancellationToken))).ToList();

            var walletSummary = await connection.QuerySingleAsync<WalletMetricRow>(new CommandDefinition(
                """
                SELECT
                    COALESCE(SUM(CASE WHEN wt.type = 'credit' AND wt.status = 'completed' THEN wt.amount ELSE 0 END), 0.00) AS TotalCredits,
                    COALESCE(SUM(CASE WHEN wt.type = 'debit' AND wt.status = 'completed' THEN wt.amount ELSE 0 END), 0.00) AS TotalDebits,
                    COUNT(1) AS TransactionCount
                FROM wallet_transactions wt
                WHERE wt.created_at >= @fromDate
                  AND wt.created_at < @toDate;
                """,
                new
                {
                    fromDate = startDate,
                    toDate = endExclusive
                },
                cancellationToken: cancellationToken));

            var totalWalletBalance = await connection.ExecuteScalarAsync<decimal>(new CommandDefinition(
                "SELECT COALESCE(SUM(balance), 0.00) FROM wallets;",
                cancellationToken: cancellationToken));

            var canteens = (await connection.QueryAsync<CanteenOptionRow>(new CommandDefinition(
                """
                SELECT id AS Id, name AS Name
                FROM canteens
                WHERE status = 'active'
                ORDER BY display_order ASC, name ASC;
                """,
                cancellationToken: cancellationToken))).ToList();

            var avgOrderValue = summary.TotalOrders > 0
                ? summary.TotalRevenue / summary.TotalOrders
                : 0m;

            var data = new
            {
                filters = new
                {
                    fromDate = startDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                    toDate = endDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                    canteenId = normalizedCanteenId > 0 ? normalizedCanteenId : (int?)null,
                    status = normalizedStatus == string.Empty ? "non_cancelled" : normalizedStatus
                },
                summary = new
                {
                    totalOrders = summary.TotalOrders,
                    totalRevenue = RoundMoney(summary.TotalRevenue),
                    totalTax = RoundMoney(summary.TotalTax),
                    avgOrderValue = RoundMoney(avgOrderValue)
                },
                walletMetrics = new
                {
                    totalCredits = RoundMoney(walletSummary.TotalCredits),
                    totalDebits = RoundMoney(walletSummary.TotalDebits),
                    transactionCount = walletSummary.TransactionCount,
                    currentBalance = RoundMoney(totalWalletBalance)
                },
                canteenSales = canteenSales.Select(row => new
                {
                    canteenId = row.CanteenId,
                    canteenName = row.CanteenName,
                    totalOrders = row.TotalOrders,
                    revenue = RoundMoney(row.Revenue),
                    avgOrderValue = RoundMoney(row.TotalOrders > 0 ? row.Revenue / row.TotalOrders : 0m)
                }),
                paymentMethods = paymentBreakdown.Select(row => new
                {
                    method = NormalizePaymentMethodForUi(row.PaymentMethod),
                    totalOrders = row.TotalOrders,
                    revenue = RoundMoney(row.Revenue)
                }),
                dailyTrend = dailyTrend.Select(row => new
                {
                    date = row.DayDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                    totalOrders = row.TotalOrders,
                    revenue = RoundMoney(row.Revenue)
                }),
                canteens = canteens.Select(row => new
                {
                    id = row.Id,
                    name = row.Name
                })
            };

            return Ok(Success("Admin reports generated successfully.", data));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to generate admin reports.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while generating admin reports."));
        }
    }

    [HttpGet("canteen/reports")]
    public async Task<IActionResult> GetCanteenReports(
        [FromQuery] int canteenId,
        [FromQuery] string? fromDate,
        [FromQuery] string? toDate,
        [FromQuery] string? status,
        CancellationToken cancellationToken = default)
    {
        if (canteenId <= 0)
        {
            return BadRequest(Failure("Valid canteenId is required."));
        }

        if (!TryResolveDateRange(fromDate, toDate, out var startDate, out var endDate, out var endExclusive, out var rangeError))
        {
            return BadRequest(Failure(rangeError ?? "Invalid date range."));
        }

        var normalizedStatus = NormalizeReportStatus(status);
        if (!string.IsNullOrWhiteSpace(status) && normalizedStatus == string.Empty)
        {
            return BadRequest(Failure("Invalid status filter supplied."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureCanteenAccessAsync(connection, canteenId, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("You are not authorized to view this canteen report."));
            }

            var whereClauses = new List<string>
            {
                "o.canteen_id = @canteenId",
                "o.created_at >= @fromDate",
                "o.created_at < @toDate"
            };

            if (normalizedStatus == "all")
            {
                // include all statuses for this canteen
            }
            else if (normalizedStatus != string.Empty)
            {
                whereClauses.Add("o.order_status = @status");
            }
            else
            {
                whereClauses.Add("o.order_status = 'completed'");
            }

            var whereSql = string.Join(" AND ", whereClauses);
            const string moneyExpression = "COALESCE(NULLIF(o.final_amount, 0.00), o.total_amount, 0.00)";

            var parameters = new DynamicParameters();
            parameters.Add("canteenId", canteenId);
            parameters.Add("fromDate", startDate);
            parameters.Add("toDate", endExclusive);
            parameters.Add("status", normalizedStatus == string.Empty || normalizedStatus == "all" ? null : normalizedStatus);

            var canteenName = await connection.ExecuteScalarAsync<string?>(new CommandDefinition(
                "SELECT name FROM canteens WHERE id = @canteenId LIMIT 1;",
                new { canteenId },
                cancellationToken: cancellationToken)) ?? "Canteen";

            var summary = await connection.QuerySingleAsync<CanteenSummaryRow>(new CommandDefinition(
                $"""
                SELECT
                    COUNT(1) AS TotalOrders,
                    COALESCE(SUM({moneyExpression}), 0.00) AS TotalRevenue
                FROM orders o
                WHERE {whereSql};
                """,
                parameters,
                cancellationToken: cancellationToken));

            var totalItemsSold = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
                $"""
                SELECT COALESCE(SUM(oi.quantity), 0)
                FROM order_items oi
                INNER JOIN orders o ON o.id = oi.order_id
                WHERE {whereSql};
                """,
                parameters,
                cancellationToken: cancellationToken));

            var dailyTrend = (await connection.QueryAsync<DailyTrendRow>(new CommandDefinition(
                $"""
                SELECT
                    DATE(o.created_at) AS DayDate,
                    COUNT(1) AS TotalOrders,
                    COALESCE(SUM({moneyExpression}), 0.00) AS Revenue
                FROM orders o
                WHERE {whereSql}
                GROUP BY DATE(o.created_at)
                ORDER BY DayDate ASC;
                """,
                parameters,
                cancellationToken: cancellationToken))).ToList();

            var topItems = (await connection.QueryAsync<TopItemRow>(new CommandDefinition(
                $"""
                SELECT
                    oi.menu_item_id AS MenuItemId,
                    COALESCE(mi.name, oi.item_name, 'Item') AS ItemName,
                    COALESCE(mc.name, 'Uncategorized') AS Category,
                    COALESCE(SUM(oi.quantity), 0) AS QuantitySold,
                    COALESCE(SUM(oi.total_price), 0.00) AS Revenue
                FROM order_items oi
                INNER JOIN orders o ON o.id = oi.order_id
                LEFT JOIN menu_items mi ON mi.id = oi.menu_item_id
                LEFT JOIN menu_categories mc ON mc.id = mi.category_id
                WHERE {whereSql}
                GROUP BY oi.menu_item_id, COALESCE(mi.name, oi.item_name, 'Item'), COALESCE(mc.name, 'Uncategorized')
                ORDER BY QuantitySold DESC, Revenue DESC
                LIMIT 10;
                """,
                parameters,
                cancellationToken: cancellationToken))).ToList();

            var statusBreakdown = (await connection.QueryAsync<StatusBreakdownRow>(new CommandDefinition(
                $"""
                SELECT
                    COALESCE(o.order_status, 'pending') AS Status,
                    COUNT(1) AS TotalOrders,
                    COALESCE(SUM({moneyExpression}), 0.00) AS Revenue
                FROM orders o
                WHERE {whereSql}
                GROUP BY COALESCE(o.order_status, 'pending')
                ORDER BY TotalOrders DESC;
                """,
                parameters,
                cancellationToken: cancellationToken))).ToList();

            var avgOrderValue = summary.TotalOrders > 0
                ? summary.TotalRevenue / summary.TotalOrders
                : 0m;

            var data = new
            {
                filters = new
                {
                    canteenId,
                    fromDate = startDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                    toDate = endDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                    status = normalizedStatus == string.Empty ? "completed" : normalizedStatus
                },
                canteen = new
                {
                    id = canteenId,
                    name = canteenName
                },
                summary = new
                {
                    totalOrders = summary.TotalOrders,
                    totalRevenue = RoundMoney(summary.TotalRevenue),
                    avgOrderValue = RoundMoney(avgOrderValue),
                    totalItemsSold
                },
                dailyTrend = dailyTrend.Select(row => new
                {
                    date = row.DayDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                    totalOrders = row.TotalOrders,
                    revenue = RoundMoney(row.Revenue)
                }),
                topItems = topItems.Select(row => new
                {
                    menuItemId = row.MenuItemId,
                    itemName = row.ItemName,
                    category = row.Category,
                    quantitySold = row.QuantitySold,
                    revenue = RoundMoney(row.Revenue)
                }),
                statusBreakdown = statusBreakdown.Select(row => new
                {
                    status = row.Status,
                    totalOrders = row.TotalOrders,
                    revenue = RoundMoney(row.Revenue)
                })
            };

            return Ok(Success("Canteen reports generated successfully.", data));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to generate canteen report for canteen {CanteenId}", canteenId);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while generating canteen reports."));
        }
    }

    private async Task<bool> EnsureAdminAccessAsync(IDbConnection connection, CancellationToken cancellationToken)
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

    private async Task<bool> EnsureCanteenAccessAsync(IDbConnection connection, int canteenId, CancellationToken cancellationToken)
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

    private static bool TryResolveDateRange(
        string? fromDate,
        string? toDate,
        out DateTime startDate,
        out DateTime endDate,
        out DateTime endExclusive,
        out string? error)
    {
        error = null;
        var today = DateTime.UtcNow.Date;
        var defaultStart = today.AddDays(-29);

        startDate = defaultStart;
        endDate = today;

        if (!string.IsNullOrWhiteSpace(fromDate)
            && !DateTime.TryParseExact(fromDate, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out startDate))
        {
            error = "Invalid fromDate format. Use yyyy-MM-dd.";
            endExclusive = default;
            return false;
        }

        if (!string.IsNullOrWhiteSpace(toDate)
            && !DateTime.TryParseExact(toDate, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out endDate))
        {
            error = "Invalid toDate format. Use yyyy-MM-dd.";
            endExclusive = default;
            return false;
        }

        startDate = startDate.Date;
        endDate = endDate.Date;

        if (startDate > endDate)
        {
            error = "fromDate cannot be after toDate.";
            endExclusive = default;
            return false;
        }

        if ((endDate - startDate).TotalDays > 366)
        {
            error = "Date range is too large. Please keep it within 366 days.";
            endExclusive = default;
            return false;
        }

        endExclusive = endDate.AddDays(1);
        return true;
    }

    private static string NormalizeReportStatus(string? value)
    {
        var normalized = (value ?? string.Empty).Trim().ToLowerInvariant();
        if (normalized == string.Empty)
        {
            return string.Empty;
        }

        if (normalized == "all")
        {
            return "all";
        }

        return AllowedOrderStatuses.Contains(normalized)
            ? normalized
            : string.Empty;
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

    private sealed class AdminSummaryRow
    {
        public int TotalOrders { get; init; }
        public decimal TotalRevenue { get; init; }
        public decimal TotalTax { get; init; }
    }

    private sealed class CanteenSummaryRow
    {
        public int TotalOrders { get; init; }
        public decimal TotalRevenue { get; init; }
    }

    private sealed class DailyTrendRow
    {
        public DateTime DayDate { get; init; }
        public int TotalOrders { get; init; }
        public decimal Revenue { get; init; }
    }

    private sealed class CanteenSalesRow
    {
        public int CanteenId { get; init; }
        public string CanteenName { get; init; } = string.Empty;
        public int TotalOrders { get; init; }
        public decimal Revenue { get; init; }
    }

    private sealed class PaymentBreakdownRow
    {
        public string PaymentMethod { get; init; } = string.Empty;
        public int TotalOrders { get; init; }
        public decimal Revenue { get; init; }
    }

    private sealed class WalletMetricRow
    {
        public decimal TotalCredits { get; init; }
        public decimal TotalDebits { get; init; }
        public int TransactionCount { get; init; }
    }

    private sealed class CanteenOptionRow
    {
        public int Id { get; init; }
        public string Name { get; init; } = string.Empty;
    }

    private sealed class TopItemRow
    {
        public int MenuItemId { get; init; }
        public string ItemName { get; init; } = string.Empty;
        public string Category { get; init; } = string.Empty;
        public int QuantitySold { get; init; }
        public decimal Revenue { get; init; }
    }

    private sealed class StatusBreakdownRow
    {
        public string Status { get; init; } = string.Empty;
        public int TotalOrders { get; init; }
        public decimal Revenue { get; init; }
    }
}
