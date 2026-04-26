namespace UniversityCanteen.Api.Services;

public interface IRecommendationService
{
    Task<IReadOnlyList<RecommendationItem>> GetTrendingAsync(int limit, CancellationToken ct);
    Task<IReadOnlyList<RecommendationItem>> GetBudgetMealsAsync(decimal maxPrice, int limit, CancellationToken ct);
    Task<IReadOnlyList<RecommendationItem>> GetPersonalAsync(int userId, int limit, CancellationToken ct);
    Task<IReadOnlyList<RecommendationItem>> GetByCanteenAsync(int canteenId, int limit, CancellationToken ct);
}

public sealed class RecommendationItem
{
    public int Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public decimal Price { get; init; }
    public string ImageUrl { get; init; } = string.Empty;
    public int CanteenId { get; init; }
    public string CanteenName { get; init; } = string.Empty;
    public string Category { get; init; } = string.Empty;
    public string Reason { get; init; } = string.Empty;
    public int OrderCount { get; init; }
    public bool IsAvailable { get; init; }
    public string SpiceLevel { get; init; } = string.Empty;
    public int PreparationTime { get; init; }
}
