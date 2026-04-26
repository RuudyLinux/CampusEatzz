using Dapper;
using Microsoft.Extensions.Caching.Memory;
using UniversityCanteen.Api.Data;

namespace UniversityCanteen.Api.Services;

public sealed class RecommendationService(
    IDbConnectionFactory dbConnectionFactory,
    IMemoryCache cache) : IRecommendationService
{
    private static readonly TimeSpan TrendingCacheDuration = TimeSpan.FromMinutes(15);
    private static readonly TimeSpan BudgetCacheDuration = TimeSpan.FromMinutes(30);

    public async Task<IReadOnlyList<RecommendationItem>> GetTrendingAsync(int limit, CancellationToken ct)
    {
        var clampedLimit = Math.Clamp(limit, 1, 20);
        var cacheKey = $"trending:{clampedLimit}";

        if (cache.TryGetValue(cacheKey, out IReadOnlyList<RecommendationItem>? cached) && cached != null)
            return cached;

        using var connection = dbConnectionFactory.CreateConnection();
        var rows = (await connection.QueryAsync<RecommendationRow>(new CommandDefinition(
            """
            SELECT
                mi.id               AS Id,
                COALESCE(mi.name, '') AS Name,
                COALESCE(mi.price, 0) AS Price,
                COALESCE(mi.image_url, '') AS ImageUrl,
                COALESCE(mi.canteen_id, 0) AS CanteenId,
                COALESCE(c.name, '') AS CanteenName,
                COALESCE(mc.name, '') AS Category,
                COALESCE(mi.is_available, 1) AS IsAvailable,
                COALESCE(mi.spice_level, '') AS SpiceLevel,
                COALESCE(mi.preparation_time, 0) AS PreparationTime,
                COUNT(oi.id) AS OrderCount
            FROM menu_items mi
            LEFT JOIN order_items oi ON oi.menu_item_id = mi.id
            LEFT JOIN orders o ON o.id = oi.order_id
                AND o.created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)
            LEFT JOIN canteens c ON c.id = mi.canteen_id
            LEFT JOIN menu_categories mc ON mc.id = mi.category_id
            WHERE COALESCE(mi.is_available, 1) = 1
            GROUP BY mi.id, mi.name, mi.price, mi.image_url, mi.canteen_id, c.name, mc.name,
                     mi.is_available, mi.spice_level, mi.preparation_time
            ORDER BY OrderCount DESC, mi.id ASC
            LIMIT @limit;
            """,
            new { limit = clampedLimit },
            cancellationToken: ct))).ToList();

        var result = rows.Select((r, idx) => ToItem(r, TrendingReason(idx, r.OrderCount))).ToList();
        cache.Set(cacheKey, (IReadOnlyList<RecommendationItem>)result, TrendingCacheDuration);
        return result;
    }

    public async Task<IReadOnlyList<RecommendationItem>> GetBudgetMealsAsync(
        decimal maxPrice,
        int limit,
        CancellationToken ct)
    {
        var clampedMax = Math.Max(1, maxPrice);
        var clampedLimit = Math.Clamp(limit, 1, 20);
        var cacheKey = $"budget:{clampedMax}:{clampedLimit}";

        if (cache.TryGetValue(cacheKey, out IReadOnlyList<RecommendationItem>? cached) && cached != null)
            return cached;

        using var connection = dbConnectionFactory.CreateConnection();
        var rows = (await connection.QueryAsync<RecommendationRow>(new CommandDefinition(
            """
            SELECT
                mi.id               AS Id,
                COALESCE(mi.name, '') AS Name,
                COALESCE(mi.price, 0) AS Price,
                COALESCE(mi.image_url, '') AS ImageUrl,
                COALESCE(mi.canteen_id, 0) AS CanteenId,
                COALESCE(c.name, '') AS CanteenName,
                COALESCE(mc.name, '') AS Category,
                COALESCE(mi.is_available, 1) AS IsAvailable,
                COALESCE(mi.spice_level, '') AS SpiceLevel,
                COALESCE(mi.preparation_time, 0) AS PreparationTime,
                0 AS OrderCount
            FROM menu_items mi
            LEFT JOIN canteens c ON c.id = mi.canteen_id
            LEFT JOIN menu_categories mc ON mc.id = mi.category_id
            WHERE COALESCE(mi.is_available, 1) = 1
              AND COALESCE(mi.price, 0) <= @maxPrice
            ORDER BY mi.price ASC, mi.id ASC
            LIMIT @limit;
            """,
            new { maxPrice = clampedMax, limit = clampedLimit },
            cancellationToken: ct))).ToList();

        var result = rows.Select(r => ToItem(r, $"Great value at just ₹{r.Price:0}")).ToList();
        cache.Set(cacheKey, (IReadOnlyList<RecommendationItem>)result, BudgetCacheDuration);
        return result;
    }

    public async Task<IReadOnlyList<RecommendationItem>> GetPersonalAsync(int userId, int limit, CancellationToken ct)
    {
        if (userId <= 0)
            return await GetTrendingAsync(limit, ct);

        var clampedLimit = Math.Clamp(limit, 1, 20);

        using var connection = dbConnectionFactory.CreateConnection();

        // Items the user has ordered most
        var rows = (await connection.QueryAsync<RecommendationRow>(new CommandDefinition(
            """
            SELECT
                mi.id               AS Id,
                COALESCE(mi.name, '') AS Name,
                COALESCE(mi.price, 0) AS Price,
                COALESCE(mi.image_url, '') AS ImageUrl,
                COALESCE(mi.canteen_id, 0) AS CanteenId,
                COALESCE(c.name, '') AS CanteenName,
                COALESCE(mc.name, '') AS Category,
                COALESCE(mi.is_available, 1) AS IsAvailable,
                COALESCE(mi.spice_level, '') AS SpiceLevel,
                COALESCE(mi.preparation_time, 0) AS PreparationTime,
                COUNT(oi.id) AS OrderCount
            FROM menu_items mi
            LEFT JOIN order_items oi ON oi.menu_item_id = mi.id
            LEFT JOIN orders o ON o.id = oi.order_id AND o.user_id = @userId
            LEFT JOIN canteens c ON c.id = mi.canteen_id
            LEFT JOIN menu_categories mc ON mc.id = mi.category_id
            WHERE COALESCE(mi.is_available, 1) = 1
            GROUP BY mi.id, mi.name, mi.price, mi.image_url, mi.canteen_id, c.name, mc.name,
                     mi.is_available, mi.spice_level, mi.preparation_time
            ORDER BY OrderCount DESC, mi.id ASC
            LIMIT @limit;
            """,
            new { userId, limit = clampedLimit },
            cancellationToken: ct))).ToList();

        return rows.Select(r =>
        {
            var reason = r.OrderCount > 0
                ? $"You've ordered this {r.OrderCount} time{(r.OrderCount > 1 ? "s" : "")} — a personal favourite!"
                : "Highly rated on campus";
            return ToItem(r, reason);
        }).ToList();
    }

    public async Task<IReadOnlyList<RecommendationItem>> GetByCanteenAsync(int canteenId, int limit, CancellationToken ct)
    {
        var clampedLimit = Math.Clamp(limit, 1, 20);
        var cacheKey = $"canteen:{canteenId}:{clampedLimit}";

        if (cache.TryGetValue(cacheKey, out IReadOnlyList<RecommendationItem>? cached) && cached != null)
            return cached;

        using var connection = dbConnectionFactory.CreateConnection();
        var rows = (await connection.QueryAsync<RecommendationRow>(new CommandDefinition(
            """
            SELECT
                mi.id               AS Id,
                COALESCE(mi.name, '') AS Name,
                COALESCE(mi.price, 0) AS Price,
                COALESCE(mi.image_url, '') AS ImageUrl,
                COALESCE(mi.canteen_id, 0) AS CanteenId,
                COALESCE(c.name, '') AS CanteenName,
                COALESCE(mc.name, '') AS Category,
                COALESCE(mi.is_available, 1) AS IsAvailable,
                COALESCE(mi.spice_level, '') AS SpiceLevel,
                COALESCE(mi.preparation_time, 0) AS PreparationTime,
                COUNT(oi.id) AS OrderCount
            FROM menu_items mi
            LEFT JOIN order_items oi ON oi.menu_item_id = mi.id
            LEFT JOIN orders o ON o.id = oi.order_id
            LEFT JOIN canteens c ON c.id = mi.canteen_id
            LEFT JOIN menu_categories mc ON mc.id = mi.category_id
            WHERE COALESCE(mi.is_available, 1) = 1
              AND mi.canteen_id = @canteenId
            GROUP BY mi.id, mi.name, mi.price, mi.image_url, mi.canteen_id, c.name, mc.name,
                     mi.is_available, mi.spice_level, mi.preparation_time
            ORDER BY OrderCount DESC, mi.price ASC, mi.id ASC
            LIMIT @limit;
            """,
            new { canteenId, limit = clampedLimit },
            cancellationToken: ct))).ToList();

        var result = rows.Select((r, idx) =>
            ToItem(r, idx == 0 ? "Most popular here" : $"Popular at {r.CanteenName}")).ToList();

        cache.Set(cacheKey, (IReadOnlyList<RecommendationItem>)result, TrendingCacheDuration);
        return result;
    }

    private static RecommendationItem ToItem(RecommendationRow r, string reason) => new()
    {
        Id = r.Id,
        Name = r.Name,
        Price = r.Price,
        ImageUrl = r.ImageUrl,
        CanteenId = r.CanteenId,
        CanteenName = r.CanteenName,
        Category = r.Category,
        Reason = reason,
        OrderCount = r.OrderCount,
        IsAvailable = r.IsAvailable,
        SpiceLevel = r.SpiceLevel,
        PreparationTime = r.PreparationTime
    };

    private static string TrendingReason(int index, int orderCount) => index switch
    {
        0 => "Most ordered on campus right now",
        1 => "Second most popular — students love it",
        2 => "Consistently trending this month",
        _ => orderCount > 0 ? $"Ordered {orderCount} times this month" : "Popular campus pick"
    };

    private sealed class RecommendationRow
    {
        public int Id { get; init; }
        public string Name { get; init; } = string.Empty;
        public decimal Price { get; init; }
        public string ImageUrl { get; init; } = string.Empty;
        public int CanteenId { get; init; }
        public string CanteenName { get; init; } = string.Empty;
        public string Category { get; init; } = string.Empty;
        public bool IsAvailable { get; init; }
        public string SpiceLevel { get; init; } = string.Empty;
        public int PreparationTime { get; init; }
        public int OrderCount { get; init; }
    }
}
