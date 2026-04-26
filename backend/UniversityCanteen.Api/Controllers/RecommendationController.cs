using Microsoft.AspNetCore.Mvc;
using UniversityCanteen.Api.Services;

namespace UniversityCanteen.Api.Controllers;

[ApiController]
[Route("api/recommendations")]
public sealed class RecommendationController(
    IRecommendationService recommendationService,
    ILogger<RecommendationController> logger) : ControllerBase
{
    [HttpGet("trending")]
    public async Task<IActionResult> GetTrending(
        [FromQuery] int limit = 6,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var items = await recommendationService.GetTrendingAsync(
                Math.Clamp(limit, 1, 20),
                cancellationToken);

            return Ok(new
            {
                success = true,
                message = "Trending items fetched successfully.",
                data = new
                {
                    type = "trending",
                    title = "Trending Now",
                    subtitle = "Most ordered by students this month",
                    items = items.Select(MapItem),
                    total = items.Count
                }
            });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error fetching trending recommendations.");
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                success = false,
                message = "Internal server error while fetching trending items."
            });
        }
    }

    [HttpGet("budget")]
    public async Task<IActionResult> GetBudgetMeals(
        [FromQuery] decimal maxPrice = 150,
        [FromQuery] int limit = 6,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var items = await recommendationService.GetBudgetMealsAsync(
                Math.Max(1, maxPrice),
                Math.Clamp(limit, 1, 20),
                cancellationToken);

            return Ok(new
            {
                success = true,
                message = "Budget meals fetched successfully.",
                data = new
                {
                    type = "budget",
                    title = "Budget Meals",
                    subtitle = $"Tasty meals under ₹{maxPrice:0}",
                    items = items.Select(MapItem),
                    total = items.Count
                }
            });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error fetching budget meal recommendations.");
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                success = false,
                message = "Internal server error while fetching budget meals."
            });
        }
    }

    [HttpGet("personal")]
    public async Task<IActionResult> GetPersonal(
        [FromQuery] int userId = 0,
        [FromQuery] int limit = 6,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var items = await recommendationService.GetPersonalAsync(
                userId,
                Math.Clamp(limit, 1, 20),
                cancellationToken);

            return Ok(new
            {
                success = true,
                message = "Personal recommendations fetched successfully.",
                data = new
                {
                    type = "personal",
                    title = "Recommended For You",
                    subtitle = userId > 0 ? "Based on your order history" : "Popular picks on campus",
                    items = items.Select(MapItem),
                    total = items.Count
                }
            });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error fetching personal recommendations.");
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                success = false,
                message = "Internal server error while fetching personal recommendations."
            });
        }
    }

    [HttpGet("canteen/{canteenId:int}")]
    public async Task<IActionResult> GetByCanteen(
        int canteenId,
        [FromQuery] int limit = 6,
        CancellationToken cancellationToken = default)
    {
        if (canteenId <= 0)
            return BadRequest(new { success = false, message = "Valid canteenId is required." });

        try
        {
            var items = await recommendationService.GetByCanteenAsync(
                canteenId,
                Math.Clamp(limit, 1, 20),
                cancellationToken);

            return Ok(new
            {
                success = true,
                message = "Canteen recommendations fetched successfully.",
                data = new
                {
                    type = "canteen",
                    title = "Popular Here",
                    subtitle = "Top picks from this canteen",
                    canteenId,
                    items = items.Select(MapItem),
                    total = items.Count
                }
            });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error fetching canteen recommendations for canteen {CanteenId}", canteenId);
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                success = false,
                message = "Internal server error while fetching canteen recommendations."
            });
        }
    }

    private static object MapItem(RecommendationItem item) => new
    {
        id = item.Id,
        name = item.Name,
        price = item.Price,
        imageUrl = item.ImageUrl,
        canteenId = item.CanteenId,
        canteenName = item.CanteenName,
        category = item.Category,
        reason = item.Reason,
        orderCount = item.OrderCount,
        isAvailable = item.IsAvailable,
        spiceLevel = item.SpiceLevel,
        preparationTime = item.PreparationTime
    };
}
