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
[Route("api/canteen")]
public sealed class CanteenController(
    IDbConnectionFactory dbConnectionFactory,
    IOptions<AuthOptions> authOptions,
    INotificationService notificationService,
    ILogger<CanteenController> logger) : ControllerBase
{
    private readonly AuthOptions _authOptions = authOptions.Value;

    // ── Dashboard ────────────────────────────────────────────────────────────

    [HttpGet("dashboard")]
    public async Task<IActionResult> GetDashboard(
        [FromQuery] int canteenId,
        CancellationToken cancellationToken = default)
    {
        if (canteenId <= 0)
            return BadRequest(Failure("Valid canteenId is required."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureCanteenAccess(connection, canteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            const string moneyExpr = "COALESCE(NULLIF(o.final_amount, 0.00), o.total_amount, 0.00)";

            var stats = await connection.QuerySingleAsync<DashboardStatsRow>(new CommandDefinition(
                $"""
                SELECT
                    COUNT(CASE WHEN o.order_status = 'pending' THEN 1 END)                                  AS PendingCount,
                    COUNT(CASE WHEN o.order_status IN ('confirmed','preparing','ready') THEN 1 END)          AS ActiveCount,
                    COUNT(CASE WHEN o.order_status = 'completed' THEN 1 END)                                AS CompletedCount,
                    COUNT(CASE WHEN o.order_status = 'cancelled' THEN 1 END)                                AS CancelledCount,
                    COALESCE(SUM(CASE WHEN o.order_status = 'completed' THEN {moneyExpr} ELSE 0 END), 0.00) AS TodayRevenue
                FROM orders o
                WHERE o.canteen_id = @canteenId
                  AND DATE(o.created_at) = CURDATE();
                """,
                new { canteenId },
                cancellationToken: cancellationToken));

            var totalRevenue = await connection.ExecuteScalarAsync<decimal>(new CommandDefinition(
                $"""
                SELECT COALESCE(SUM({moneyExpr}), 0.00)
                FROM orders o
                WHERE o.canteen_id = @canteenId
                  AND o.order_status = 'completed';
                """,
                new { canteenId },
                cancellationToken: cancellationToken));

            var totalMenuItems = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
                "SELECT COUNT(1) FROM menu_items WHERE canteen_id = @canteenId AND COALESCE(is_deleted, 0) = 0;",
                new { canteenId },
                cancellationToken: cancellationToken));

            var recentOrders = (await connection.QueryAsync<RecentOrderRow>(new CommandDefinition(
                """
                SELECT
                    o.id AS Id,
                    o.order_number AS OrderNumber,
                    COALESCE(o.customer_name, CONCAT(COALESCE(u.first_name,''), ' ', COALESCE(u.last_name,'')), 'Unknown') AS CustomerName,
                    COALESCE(o.customer_phone, COALESCE(u.contact, 'N/A')) AS CustomerPhone,
                    COALESCE(NULLIF(o.final_amount, 0.00), o.total_amount, 0.00) AS Total,
                    COALESCE(o.order_status, 'pending') AS OrderStatus,
                    COALESCE(o.payment_status, 'pending') AS PaymentStatus,
                    COALESCE(o.payment_method, 'cash') AS PaymentMethod,
                    o.created_at AS CreatedAt,
                    (SELECT GROUP_CONCAT(COALESCE(oi.item_name, 'Item'), ' x', oi.quantity ORDER BY oi.id SEPARATOR ', ')
                     FROM order_items oi WHERE oi.order_id = o.id) AS ItemsSummary
                FROM orders o
                LEFT JOIN users u ON u.id = o.user_id
                WHERE o.canteen_id = @canteenId
                ORDER BY o.created_at DESC
                LIMIT 10;
                """,
                new { canteenId },
                cancellationToken: cancellationToken))).ToList();

            return Ok(Success("Dashboard loaded.", new
            {
                stats = new
                {
                    pendingOrders = stats.PendingCount,
                    activeOrders = stats.ActiveCount,
                    completedOrdersToday = stats.CompletedCount,
                    cancelledOrdersToday = stats.CancelledCount,
                    revenueToday = Math.Round(stats.TodayRevenue, 2),
                    totalRevenue = Math.Round(totalRevenue, 2),
                    totalMenuItems
                },
                recentOrders = recentOrders.Select(o => new
                {
                    id = o.Id,
                    orderNumber = o.OrderNumber,
                    customerName = o.CustomerName.Trim(),
                    customerPhone = o.CustomerPhone,
                    total = Math.Round(o.Total, 2),
                    status = o.OrderStatus,
                    paymentStatus = o.PaymentStatus,
                    paymentMethod = o.PaymentMethod,
                    createdAt = o.CreatedAt,
                    itemsSummary = o.ItemsSummary ?? ""
                })
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Dashboard failed for canteen {Id}", canteenId);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    // ── Menu Items ───────────────────────────────────────────────────────────

    [HttpGet("menu-items")]
    [AllowAnonymous]
    public async Task<IActionResult> GetMenuItems(
        [FromQuery] int canteenId,
        CancellationToken cancellationToken = default)
    {
        if (canteenId <= 0)
            return BadRequest(Failure("Valid canteenId is required."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            var items = (await connection.QueryAsync<MenuItemRow>(new CommandDefinition(
                """
                SELECT
                    mi.id AS Id,
                    mi.name AS Name,
                    COALESCE(mi.description, '') AS Description,
                    mi.price AS Price,
                    COALESCE(mc.name, 'Uncategorized') AS Category,
                    mi.category_id AS CategoryId,
                    COALESCE(mi.is_available, 1) AS IsAvailable,
                    COALESCE(mi.is_vegetarian, 0) AS IsVegetarian,
                    COALESCE(mi.image_url, '') AS ImageUrl,
                    mi.created_at AS CreatedAt
                FROM menu_items mi
                LEFT JOIN menu_categories mc ON mc.id = mi.category_id
                WHERE mi.canteen_id = @canteenId
                  AND COALESCE(mi.is_deleted, 0) = 0
                ORDER BY mi.display_order ASC, mi.id ASC;
                """,
                new { canteenId },
                cancellationToken: cancellationToken))).ToList();

            return Ok(Success("Menu items fetched.", new
            {
                items = items.Select(i => new
                {
                    id = i.Id,
                    name = i.Name,
                    description = i.Description,
                    price = Math.Round(i.Price, 2),
                    category = i.Category,
                    categoryId = i.CategoryId,
                    isAvailable = i.IsAvailable,
                    isVegetarian = i.IsVegetarian,
                    imageUrl = i.ImageUrl,
                    createdAt = i.CreatedAt
                }),
                total = items.Count
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "GetMenuItems failed for canteen {Id}", canteenId);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    [HttpGet("menu-categories")]
    public async Task<IActionResult> GetMenuCategories(CancellationToken cancellationToken = default)
    {
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var categories = await connection.QueryAsync<CategoryRow>(new CommandDefinition(
                """
                SELECT id AS Id, name AS Name
                FROM menu_categories
                WHERE COALESCE(is_active, 1) = 1
                ORDER BY display_order ASC, name ASC;
                """,
                cancellationToken: cancellationToken));

            return Ok(Success("Categories fetched.", new
            {
                categories = categories.Select(c => new { id = c.Id, name = c.Name })
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "GetMenuCategories failed.");
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    [HttpPost("menu-items/upload-image")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> UploadMenuItemImage(
        [FromForm] int canteenId,
        IFormFile? image,
        CancellationToken cancellationToken = default)
    {
        if (canteenId <= 0) return BadRequest(Failure("Valid canteenId is required."));
        if (image == null || image.Length == 0) return BadRequest(Failure("No image file provided."));

        const long maxBytes = 20 * 1024 * 1024; // 20 MB
        if (image.Length > maxBytes) return BadRequest(Failure("Image must be smaller than 20 MB."));

        var ext = Path.GetExtension(image.FileName).ToLowerInvariant();
        if (ext is not (".jpg" or ".jpeg" or ".png" or ".webp"))
            return BadRequest(Failure("Only JPG, PNG, or WebP images are allowed."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureCanteenAccess(connection, canteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            var uploadDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "menu");
            Directory.CreateDirectory(uploadDir);

            var fileName = $"item_{canteenId}_{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}{ext}";
            var filePath = Path.Combine(uploadDir, fileName);

            await using (var stream = System.IO.File.Create(filePath))
            {
                await image.CopyToAsync(stream, cancellationToken);
            }

            var relativePath = $"uploads/menu/{fileName}";
            var absoluteUrl = $"{Request.Scheme}://{Request.Host}/{relativePath}";

            return Ok(Success("Image uploaded.", new { url = absoluteUrl, relativePath }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Image upload failed for canteen {Id}", canteenId);
            return StatusCode(500, Failure("Internal server error during upload."));
        }
    }

    [HttpPost("menu-items")]
    public async Task<IActionResult> AddMenuItem(
        [FromBody] MenuItemRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.CanteenId <= 0)
            return BadRequest(Failure("Valid canteenId is required."));
        if (string.IsNullOrWhiteSpace(request.Name))
            return BadRequest(Failure("Item name is required."));
        if (request.Price < 0)
            return BadRequest(Failure("Price must be non-negative."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureCanteenAccess(connection, request.CanteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            var categoryId = await ResolveCategoryId(connection, request.Category, cancellationToken);

            var newId = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
                """
                INSERT INTO menu_items (canteen_id, category_id, name, description, price, image_url, is_available, is_vegetarian, created_at, updated_at)
                VALUES (@canteenId, @categoryId, @name, @description, @price, @imageUrl, @isAvailable, @isVegetarian, UTC_TIMESTAMP(), UTC_TIMESTAMP());
                SELECT LAST_INSERT_ID();
                """,
                new
                {
                    canteenId = request.CanteenId,
                    categoryId,
                    name = request.Name.Trim(),
                    description = (request.Description ?? string.Empty).Trim(),
                    price = request.Price,
                    imageUrl = string.IsNullOrWhiteSpace(request.ImageUrl) ? null : request.ImageUrl.Trim(),
                    isAvailable = request.IsAvailable ? 1 : 0,
                    isVegetarian = request.IsVegetarian ? 1 : 0
                },
                cancellationToken: cancellationToken));

            return Ok(Success("Menu item added.", new { id = newId }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "AddMenuItem failed for canteen {Id}", request.CanteenId);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    [HttpPut("menu-items/{id:int}")]
    public async Task<IActionResult> UpdateMenuItem(
        int id,
        [FromBody] MenuItemRequest request,
        CancellationToken cancellationToken = default)
    {
        if (id <= 0) return BadRequest(Failure("Valid item id is required."));
        if (request.CanteenId <= 0) return BadRequest(Failure("Valid canteenId is required."));
        if (string.IsNullOrWhiteSpace(request.Name)) return BadRequest(Failure("Item name is required."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureCanteenAccess(connection, request.CanteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            var categoryId = await ResolveCategoryId(connection, request.Category, cancellationToken);

            var updateImageSql = string.IsNullOrWhiteSpace(request.ImageUrl)
                ? string.Empty
                : ", image_url = @imageUrl";

            var rows = await connection.ExecuteAsync(new CommandDefinition(
                $"""
                UPDATE menu_items
                SET name = @name,
                    description = @description,
                    price = @price,
                    category_id = @categoryId,
                    is_available = @isAvailable,
                    is_vegetarian = @isVegetarian{updateImageSql},
                    updated_at = UTC_TIMESTAMP()
                WHERE id = @id
                  AND canteen_id = @canteenId
                  AND COALESCE(is_deleted, 0) = 0;
                """,
                new
                {
                    id,
                    canteenId = request.CanteenId,
                    name = request.Name.Trim(),
                    description = (request.Description ?? string.Empty).Trim(),
                    price = request.Price,
                    categoryId,
                    imageUrl = string.IsNullOrWhiteSpace(request.ImageUrl) ? null : request.ImageUrl.Trim(),
                    isAvailable = request.IsAvailable ? 1 : 0,
                    isVegetarian = request.IsVegetarian ? 1 : 0
                },
                cancellationToken: cancellationToken));

            if (rows == 0)
                return NotFound(Failure("Item not found or does not belong to this canteen."));

            return Ok(Success("Menu item updated.", new { id }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "UpdateMenuItem {Id} failed", id);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    [HttpDelete("menu-items/{id:int}")]
    public async Task<IActionResult> DeleteMenuItem(
        int id,
        [FromQuery] int canteenId,
        CancellationToken cancellationToken = default)
    {
        if (id <= 0) return BadRequest(Failure("Valid item id is required."));
        if (canteenId <= 0) return BadRequest(Failure("Valid canteenId is required."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureCanteenAccess(connection, canteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            var rows = await connection.ExecuteAsync(new CommandDefinition(
                """
                UPDATE menu_items
                SET is_deleted = 1, deleted_at = UTC_TIMESTAMP(), updated_at = UTC_TIMESTAMP()
                WHERE id = @id AND canteen_id = @canteenId AND COALESCE(is_deleted, 0) = 0;
                """,
                new { id, canteenId },
                cancellationToken: cancellationToken));

            if (rows == 0)
                return NotFound(Failure("Item not found or already deleted."));

            return Ok(Success("Menu item deleted.", new { id }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "DeleteMenuItem {Id} failed", id);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    [HttpPatch("menu-items/{id:int}/availability")]
    public async Task<IActionResult> ToggleAvailability(
        int id,
        [FromBody] AvailabilityRequest request,
        CancellationToken cancellationToken = default)
    {
        if (id <= 0) return BadRequest(Failure("Valid item id is required."));
        if (request.CanteenId <= 0) return BadRequest(Failure("Valid canteenId is required."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureCanteenAccess(connection, request.CanteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            var rows = await connection.ExecuteAsync(new CommandDefinition(
                """
                UPDATE menu_items
                SET is_available = @isAvailable, updated_at = UTC_TIMESTAMP()
                WHERE id = @id AND canteen_id = @canteenId AND COALESCE(is_deleted, 0) = 0;
                """,
                new { id, canteenId = request.CanteenId, isAvailable = request.IsAvailable ? 1 : 0 },
                cancellationToken: cancellationToken));

            if (rows == 0)
                return NotFound(Failure("Item not found."));

            return Ok(Success("Availability updated.", new { id, isAvailable = request.IsAvailable }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "ToggleAvailability {Id} failed", id);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    // ── Reviews ──────────────────────────────────────────────────────────────

    [HttpGet("reviews")]
    public async Task<IActionResult> GetReviews(
        [FromQuery] int canteenId,
        CancellationToken cancellationToken = default)
    {
        if (canteenId <= 0)
            return BadRequest(Failure("Valid canteenId is required."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureCanteenAccess(connection, canteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            var reviews = (await connection.QueryAsync<ReviewRow>(new CommandDefinition(
                """
                SELECT
                    r.id AS Id,
                    r.user_id AS UserId,
                    r.order_id AS OrderId,
                    r.rating AS Rating,
                    r.review_text AS ReviewText,
                    COALESCE(r.admin_response, '') AS AdminResponse,
                    r.response_date AS ResponseDate,
                    r.status AS Status,
                    r.created_at AS CreatedAt,
                    CONCAT(COALESCE(u.first_name,''), ' ', COALESCE(u.last_name,'')),
                    COALESCE(TRIM(CONCAT(COALESCE(u.first_name,''), ' ', COALESCE(u.last_name,''))), u.email, 'Anonymous') AS UserName
                FROM reviews r
                LEFT JOIN users u ON u.id = r.user_id
                WHERE r.canteen_id = @canteenId
                  AND COALESCE(r.status, 'active') = 'active'
                ORDER BY r.created_at DESC;
                """,
                new { canteenId },
                cancellationToken: cancellationToken))).ToList();

            var total = reviews.Count;
            var avgRating = total > 0 ? reviews.Average(r => r.Rating) : 0.0;
            var fiveStar = reviews.Count(r => r.Rating == 5);
            var pendingResponse = reviews.Count(r => string.IsNullOrWhiteSpace(r.AdminResponse));

            return Ok(Success("Reviews fetched.", new
            {
                stats = new
                {
                    totalReviews = total,
                    avgRating = Math.Round(avgRating, 1),
                    fiveStarCount = fiveStar,
                    pendingResponse
                },
                reviews = reviews.Select(r => new
                {
                    id = r.Id,
                    userId = r.UserId,
                    orderId = r.OrderId,
                    rating = r.Rating,
                    reviewText = r.ReviewText,
                    adminResponse = r.AdminResponse,
                    responseDate = r.ResponseDate,
                    createdAt = r.CreatedAt,
                    userName = r.UserName
                })
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "GetReviews failed for canteen {Id}", canteenId);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    [HttpPost("reviews/{id:int}/respond")]
    public async Task<IActionResult> RespondToReview(
        int id,
        [FromBody] ReviewResponseRequest request,
        CancellationToken cancellationToken = default)
    {
        if (id <= 0) return BadRequest(Failure("Valid review id is required."));
        if (request.CanteenId <= 0) return BadRequest(Failure("Valid canteenId is required."));
        if (string.IsNullOrWhiteSpace(request.Response)) return BadRequest(Failure("Response text is required."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureCanteenAccess(connection, request.CanteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            var rows = await connection.ExecuteAsync(new CommandDefinition(
                """
                UPDATE reviews
                SET admin_response = @response, response_date = UTC_TIMESTAMP()
                WHERE id = @id AND canteen_id = @canteenId;
                """,
                new { id, canteenId = request.CanteenId, response = request.Response.Trim() },
                cancellationToken: cancellationToken));

            if (rows == 0)
                return NotFound(Failure("Review not found."));

            return Ok(Success("Response saved.", new { id }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "RespondToReview {Id} failed", id);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    // ── Settings ─────────────────────────────────────────────────────────────

    [HttpGet("settings")]
    public async Task<IActionResult> GetSettings(
        [FromQuery] int canteenId,
        CancellationToken cancellationToken = default)
    {
        if (canteenId <= 0)
            return BadRequest(Failure("Valid canteenId is required."));

        var identity = GetIdentity();

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureCanteenAccess(connection, canteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            var canteen = await connection.QuerySingleOrDefaultAsync<CanteenRow>(new CommandDefinition(
                "SELECT id AS Id, name AS Name, COALESCE(description,'') AS Description FROM canteens WHERE id = @canteenId LIMIT 1;",
                new { canteenId },
                cancellationToken: cancellationToken));

            if (canteen is null)
                return NotFound(Failure("Canteen not found."));

            var adminRow = await connection.QuerySingleOrDefaultAsync<AdminProfileRow>(new CommandDefinition(
                """
                                SELECT name AS Name, email AS Email, COALESCE(contact,'') AS Contact, COALESCE(image_url,'') AS ImageUrl
                FROM canteen_admins
                WHERE canteen_id = @canteenId
                  AND LOWER(COALESCE(email,'')) = LOWER(@email)
                  AND COALESCE(status,'active') = 'active'
                LIMIT 1;
                """,
                new { canteenId, email = identity.Email },
                cancellationToken: cancellationToken));

            var openingTime = await GetSetting(connection, $"canteen_{canteenId}_opening_time", "08:00", cancellationToken);
            var closingTime = await GetSetting(connection, $"canteen_{canteenId}_closing_time", "20:00", cancellationToken);
            var phone = await GetSetting(connection, $"canteen_{canteenId}_phone",
                adminRow?.Contact ?? string.Empty, cancellationToken);

            return Ok(Success("Settings fetched.", new
            {
                canteen = new
                {
                    id = canteen.Id,
                    name = canteen.Name,
                    phone,
                    openingTime,
                    closingTime
                },
                admin = new
                {
                    name = adminRow?.Name ?? string.Empty,
                    email = adminRow?.Email ?? identity.Email,
                    imageUrl = ToClientImageUrl(adminRow?.ImageUrl)
                }
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "GetSettings failed for canteen {Id}", canteenId);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    [HttpPut("settings/canteen")]
    public async Task<IActionResult> UpdateCanteenInfo(
        [FromBody] CanteenInfoRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.CanteenId <= 0) return BadRequest(Failure("Valid canteenId is required."));
        if (string.IsNullOrWhiteSpace(request.Name)) return BadRequest(Failure("Canteen name is required."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureCanteenAccess(connection, request.CanteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            await connection.ExecuteAsync(new CommandDefinition(
                "UPDATE canteens SET name = @name WHERE id = @canteenId;",
                new { canteenId = request.CanteenId, name = request.Name.Trim() },
                cancellationToken: cancellationToken));

            await UpsertSetting(connection, $"canteen_{request.CanteenId}_phone",
                request.Phone ?? string.Empty, "Canteen phone number", cancellationToken);
            await UpsertSetting(connection, $"canteen_{request.CanteenId}_opening_time",
                request.OpeningTime ?? "08:00", "Canteen opening time", cancellationToken);
            await UpsertSetting(connection, $"canteen_{request.CanteenId}_closing_time",
                request.ClosingTime ?? "20:00", "Canteen closing time", cancellationToken);

            return Ok(Success("Canteen info updated.", null!));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "UpdateCanteenInfo failed for canteen {Id}", request.CanteenId);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    [HttpPut("settings/profile")]
    public async Task<IActionResult> UpdateAdminProfile(
        [FromBody] AdminProfileRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.CanteenId <= 0) return BadRequest(Failure("Valid canteenId is required."));
        if (string.IsNullOrWhiteSpace(request.Name)) return BadRequest(Failure("Name is required."));
        if (string.IsNullOrWhiteSpace(request.Email)) return BadRequest(Failure("Email is required."));

        var identity = GetIdentity();

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureCanteenAccess(connection, request.CanteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            await connection.ExecuteAsync(new CommandDefinition(
                """
                UPDATE canteen_admins
                                SET name = @name, email = @email, image_url = @imageUrl, updated_at = UTC_TIMESTAMP()
                WHERE canteen_id = @canteenId
                  AND LOWER(COALESCE(email,'')) = LOWER(@currentEmail)
                  AND COALESCE(status,'active') = 'active';
                """,
                new
                {
                    canteenId = request.CanteenId,
                    name = request.Name.Trim(),
                    email = request.Email.Trim(),
                    imageUrl = string.IsNullOrWhiteSpace(request.ImageUrl) ? null : request.ImageUrl.Trim(),
                    currentEmail = identity.Email
                },
                cancellationToken: cancellationToken));

            return Ok(Success("Profile updated.", null!));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "UpdateAdminProfile failed for canteen {Id}", request.CanteenId);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    [HttpPost("settings/change-password")]
    public async Task<IActionResult> ChangePassword(
        [FromBody] ChangePasswordRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.CanteenId <= 0) return BadRequest(Failure("Valid canteenId is required."));
        if (string.IsNullOrWhiteSpace(request.CurrentPassword)) return BadRequest(Failure("Current password is required."));
        if (string.IsNullOrWhiteSpace(request.NewPassword)) return BadRequest(Failure("New password is required."));
        if (request.NewPassword.Length < 6) return BadRequest(Failure("New password must be at least 6 characters."));
        if (request.NewPassword != request.ConfirmPassword) return BadRequest(Failure("New passwords do not match."));

        var identity = GetIdentity();

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            if (!await EnsureCanteenAccess(connection, request.CanteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            var adminRow = await connection.QuerySingleOrDefaultAsync<PasswordRow>(new CommandDefinition(
                """
                SELECT id AS Id, COALESCE(password,'') AS PasswordHash, COALESCE(plain_password,'') AS PlainPassword
                FROM canteen_admins
                WHERE canteen_id = @canteenId
                  AND LOWER(COALESCE(email,'')) = LOWER(@email)
                  AND COALESCE(status,'active') = 'active'
                LIMIT 1;
                """,
                new { canteenId = request.CanteenId, email = identity.Email },
                cancellationToken: cancellationToken));

            if (adminRow is null)
                return NotFound(Failure("Admin account not found."));

            var passwordMatch = (!string.IsNullOrWhiteSpace(adminRow.PlainPassword)
                                 && adminRow.PlainPassword == request.CurrentPassword)
                                || (!string.IsNullOrWhiteSpace(adminRow.PasswordHash)
                                    && VerifyBcrypt(request.CurrentPassword, adminRow.PasswordHash));

            if (!passwordMatch)
                return BadRequest(Failure("Current password is incorrect."));

            var newHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);

            await connection.ExecuteAsync(new CommandDefinition(
                """
                UPDATE canteen_admins
                SET password = @hash, plain_password = @plain, updated_at = UTC_TIMESTAMP()
                WHERE id = @id;
                """,
                new { id = adminRow.Id, hash = newHash, plain = request.NewPassword },
                cancellationToken: cancellationToken));

            return Ok(Success("Password changed successfully.", null!));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "ChangePassword failed for canteen {Id}", request.CanteenId);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    // ── Wallet ───────────────────────────────────────────────────────────────

    [HttpGet("wallet")]
    public async Task<IActionResult> GetWalletSummary(
        [FromQuery] int canteenId,
        CancellationToken cancellationToken = default)
    {
        if (canteenId <= 0) return BadRequest(Failure("Valid canteenId is required."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureCanteenAccess(connection, canteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            const string money = "COALESCE(NULLIF(o.final_amount, 0.00), o.total_amount, 0.00)";

            var revenue = await connection.QuerySingleAsync<RevenueRow>(new CommandDefinition(
                $"""
                SELECT
                    COALESCE(SUM(CASE WHEN DATE(o.created_at) = CURDATE()                              THEN {money} ELSE 0 END), 0) AS Today,
                    COALESCE(SUM(CASE WHEN o.created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)         THEN {money} ELSE 0 END), 0) AS Week,
                    COALESCE(SUM(CASE WHEN MONTH(o.created_at) = MONTH(CURDATE())
                                       AND YEAR(o.created_at) = YEAR(CURDATE())                        THEN {money} ELSE 0 END), 0) AS Month,
                    COALESCE(SUM({money}), 0)                                                                                       AS AllTime,
                    COUNT(CASE WHEN DATE(o.created_at) = CURDATE() THEN 1 END)                                                      AS OrdersToday,
                    COUNT(1)                                                                                                         AS OrdersTotal
                FROM orders o
                WHERE o.canteen_id = @canteenId AND o.order_status = 'completed';
                """,
                new { canteenId },
                cancellationToken: cancellationToken));

            var paymentBreakdown = (await connection.QueryAsync<PaymentBreakRow>(new CommandDefinition(
                $"""
                SELECT
                    LOWER(COALESCE(o.payment_method, 'cash')) AS Method,
                    COUNT(1)                                   AS OrderCount,
                    COALESCE(SUM({money}), 0)                  AS Revenue
                FROM orders o
                WHERE o.canteen_id = @canteenId AND o.order_status = 'completed'
                GROUP BY LOWER(COALESCE(o.payment_method, 'cash'))
                ORDER BY Revenue DESC;
                """,
                new { canteenId },
                cancellationToken: cancellationToken))).ToList();

            var recentOrders = (await connection.QueryAsync<RecentOrderRow>(new CommandDefinition(
                $"""
                SELECT
                    o.id AS Id,
                    o.order_number AS OrderNumber,
                    COALESCE(o.customer_name, CONCAT(COALESCE(u.first_name,''), ' ', COALESCE(u.last_name,'')), 'Customer') AS CustomerName,
                    {money}                                       AS Total,
                    LOWER(COALESCE(o.payment_method, 'cash'))     AS PaymentMethod,
                    o.created_at                                   AS CreatedAt
                FROM orders o
                LEFT JOIN users u ON u.id = o.user_id
                WHERE o.canteen_id = @canteenId AND o.order_status = 'completed'
                ORDER BY o.created_at DESC
                LIMIT 20;
                """,
                new { canteenId },
                cancellationToken: cancellationToken))).ToList();

            return Ok(Success("Wallet summary loaded.", new
            {
                revenue = new
                {
                    today    = Math.Round(revenue.Today,   2),
                    week     = Math.Round(revenue.Week,    2),
                    month    = Math.Round(revenue.Month,   2),
                    allTime  = Math.Round(revenue.AllTime, 2),
                    ordersToday = revenue.OrdersToday,
                    ordersTotal = revenue.OrdersTotal
                },
                paymentBreakdown = paymentBreakdown.Select(p => new
                {
                    method     = p.Method,
                    orderCount = p.OrderCount,
                    revenue    = Math.Round(p.Revenue, 2)
                }),
                recentTransactions = recentOrders.Select(o => new
                {
                    id            = o.Id,
                    orderNumber   = o.OrderNumber,
                    customerName  = o.CustomerName.Trim(),
                    total         = Math.Round(o.Total, 2),
                    paymentMethod = o.PaymentMethod,
                    createdAt     = o.CreatedAt
                })
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "GetWalletSummary failed for canteen {Id}", canteenId);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    // ── Maintenance ───────────────────────────────────────────────────────────

    [HttpGet("maintenance")]
    public async Task<IActionResult> GetMaintenanceStatus(
        [FromQuery] int canteenId,
        CancellationToken cancellationToken = default)
    {
        if (canteenId <= 0) return BadRequest(Failure("Valid canteenId is required."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureCanteenAccess(connection, canteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            var systemRow = await connection.QuerySingleOrDefaultAsync<SystemMaintenanceRow>(new CommandDefinition(
                "SELECT is_active AS IsActive, COALESCE(maintenance_message,'') AS Message FROM website_maintenance WHERE id = 1 LIMIT 1;",
                cancellationToken: cancellationToken));

            var canteenRow = await connection.QuerySingleOrDefaultAsync<CanteenMaintenanceRow>(new CommandDefinition(
                "SELECT is_active AS IsActive, COALESCE(reason,'') AS Reason FROM maintenance_mode WHERE canteen_id = @canteenId LIMIT 1;",
                new { canteenId },
                cancellationToken: cancellationToken));

            return Ok(Success("Maintenance status loaded.", new
            {
                system = new
                {
                    isActive = systemRow?.IsActive ?? false,
                    message  = systemRow?.Message ?? "We are currently performing maintenance. Please check back soon."
                },
                canteen = new
                {
                    isActive = canteenRow?.IsActive ?? false,
                    reason   = canteenRow?.Reason ?? string.Empty
                }
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "GetMaintenanceStatus failed for canteen {Id}", canteenId);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    [HttpPut("maintenance/system")]
    public async Task<IActionResult> UpdateSystemMaintenance(
        [FromBody] SystemMaintenanceRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.CanteenId <= 0) return BadRequest(Failure("Valid canteenId is required."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureCanteenAccess(connection, request.CanteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            await connection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO website_maintenance (id, is_active, maintenance_message)
                VALUES (1, @isActive, @message)
                ON DUPLICATE KEY UPDATE is_active = @isActive, maintenance_message = @message;
                """,
                new
                {
                    isActive = request.IsActive ? 1 : 0,
                    message  = string.IsNullOrWhiteSpace(request.Message)
                               ? "We are currently performing maintenance. Please check back soon."
                               : request.Message.Trim()
                },
                cancellationToken: cancellationToken));

            var actorId = GetRequesterUserId();
            try
            {
                await notificationService.NotifySystemMaintenanceAsync(
                    request.IsActive,
                    string.IsNullOrWhiteSpace(request.Message)
                        ? "We are currently performing maintenance. Please check back soon."
                        : request.Message.Trim(),
                    actorId,
                    "canteen_admin",
                    cancellationToken);
            }
            catch (Exception notificationEx)
            {
                logger.LogWarning(notificationEx, "Failed to publish system maintenance notification from canteen controller.");
            }

            return Ok(Success($"System maintenance {(request.IsActive ? "enabled" : "disabled")}.", null!));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "UpdateSystemMaintenance failed");
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    [HttpPut("maintenance/canteen")]
    public async Task<IActionResult> UpdateCanteenMaintenance(
        [FromBody] CanteenMaintenanceRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.CanteenId <= 0) return BadRequest(Failure("Valid canteenId is required."));

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureCanteenAccess(connection, request.CanteenId, cancellationToken))
                return StatusCode(403, Failure("Access denied."));

            var p = new
            {
                canteenId = request.CanteenId,
                isActive  = request.IsActive ? 1 : 0,
                reason    = (request.Reason ?? string.Empty).Trim()
            };

            var updated = await connection.ExecuteAsync(new CommandDefinition(
                "UPDATE maintenance_mode SET is_active = @isActive, reason = @reason, updated_at = UTC_TIMESTAMP() WHERE canteen_id = @canteenId;",
                p, cancellationToken: cancellationToken));

            if (updated == 0)
            {
                await connection.ExecuteAsync(new CommandDefinition(
                    "INSERT IGNORE INTO maintenance_mode (canteen_id, is_active, reason, started_at) VALUES (@canteenId, @isActive, @reason, UTC_TIMESTAMP());",
                    p, cancellationToken: cancellationToken));
            }

            var actorId = GetRequesterUserId();
            try
            {
                await notificationService.NotifyCanteenMaintenanceAsync(
                    request.CanteenId,
                    request.IsActive,
                    p.reason,
                    actorId,
                    "canteen_admin",
                    cancellationToken);
            }
            catch (Exception notificationEx)
            {
                logger.LogWarning(notificationEx, "Failed to publish canteen maintenance notification for canteen {CanteenId}.", request.CanteenId);
            }

            return Ok(Success($"Canteen maintenance {(request.IsActive ? "enabled" : "disabled")}.", null!));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "UpdateCanteenMaintenance failed for canteen {Id}", request.CanteenId);
            return StatusCode(500, Failure("Internal server error."));
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private async Task<bool> EnsureCanteenAccess(
        System.Data.IDbConnection connection,
        int canteenId,
        CancellationToken cancellationToken)
    {
        var identity = GetIdentity();
        if (string.IsNullOrEmpty(identity.Email)
            || !string.Equals(identity.Role, "canteen_admin", StringComparison.OrdinalIgnoreCase))
            return false;

        if (_authOptions.CanteenAdmins.Any(a =>
            a.CanteenId == canteenId
            && string.Equals(a.Email, identity.Email, StringComparison.OrdinalIgnoreCase)))
            return true;

        var count = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            """
            SELECT COUNT(1) FROM canteen_admins
            WHERE canteen_id = @canteenId
              AND LOWER(COALESCE(email,'')) = LOWER(@email)
              AND COALESCE(status,'active') = 'active';
            """,
            new { canteenId, email = identity.Email },
            cancellationToken: cancellationToken));

        return count > 0;
    }

    private (string Email, string Role) GetIdentity()
    {
        var claimEmail = User.FindFirst(JwtRegisteredClaimNames.Email)?.Value
            ?? User.FindFirst(ClaimTypes.Email)?.Value
            ?? User.FindFirst("email")?.Value
            ?? string.Empty;
        var claimRole = User.FindFirst(ClaimTypes.Role)?.Value
            ?? User.FindFirst("role")?.Value
            ?? string.Empty;

        var email = string.IsNullOrWhiteSpace(claimEmail)
            ? (Request.Headers["X-Requester-Email"].FirstOrDefault() ?? Request.Query["requesterEmail"].FirstOrDefault() ?? string.Empty).Trim()
            : claimEmail.Trim();
        var role = string.IsNullOrWhiteSpace(claimRole)
            ? (Request.Headers["X-Requester-Role"].FirstOrDefault() ?? Request.Query["requesterRole"].FirstOrDefault() ?? string.Empty).Trim()
            : claimRole.Trim();

        return (email.ToLowerInvariant(), role.ToLowerInvariant());
    }

    private int GetRequesterUserId()
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

        return 0;
    }

    private static async Task<string> GetSetting(
        System.Data.IDbConnection connection,
        string key,
        string defaultValue,
        CancellationToken cancellationToken)
    {
        var value = await connection.ExecuteScalarAsync<string?>(new CommandDefinition(
            "SELECT setting_value FROM system_settings WHERE setting_key = @key LIMIT 1;",
            new { key },
            cancellationToken: cancellationToken));
        return string.IsNullOrWhiteSpace(value) ? defaultValue : value;
    }

    private static async Task UpsertSetting(
        System.Data.IDbConnection connection,
        string key,
        string value,
        string description,
        CancellationToken cancellationToken)
    {
        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO system_settings (setting_key, setting_value, description, updated_at)
            VALUES (@key, @value, @description, UTC_TIMESTAMP())
            ON DUPLICATE KEY UPDATE setting_value = @value, updated_at = UTC_TIMESTAMP();
            """,
            new { key, value, description },
            cancellationToken: cancellationToken));
    }

    private static async Task<int> ResolveCategoryId(
        System.Data.IDbConnection connection,
        string? categoryName,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(categoryName))
            return 1;

        var id = await connection.ExecuteScalarAsync<int?>(new CommandDefinition(
            "SELECT id FROM menu_categories WHERE LOWER(name) = LOWER(@name) LIMIT 1;",
            new { name = categoryName.Trim() },
            cancellationToken: cancellationToken));

        return id ?? 1;
    }

    private static bool VerifyBcrypt(string input, string hash)
    {
        try { return BCrypt.Net.BCrypt.Verify(input, hash); }
        catch { return false; }
    }

    private string ToClientImageUrl(string? value)
    {
        var raw = (value ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(raw))
        {
            return string.Empty;
        }

        if (raw.StartsWith("data:", StringComparison.OrdinalIgnoreCase))
        {
            return raw;
        }

        if (Uri.TryCreate(raw, UriKind.Absolute, out var absolute)
            && (absolute.Scheme.Equals("http", StringComparison.OrdinalIgnoreCase)
                || absolute.Scheme.Equals("https", StringComparison.OrdinalIgnoreCase)))
        {
            return raw;
        }

        var normalized = raw.TrimStart('/');
        return $"{Request.Scheme}://{Request.Host}/{normalized}";
    }

    private static object Success(string message, object? data) =>
        new { success = true, message, data };

    private static object Failure(string message) =>
        new { success = false, message };

    // ── Row DTOs ──────────────────────────────────────────────────────────────

    private sealed class DashboardStatsRow
    {
        public int PendingCount { get; init; }
        public int ActiveCount { get; init; }
        public int CompletedCount { get; init; }
        public int CancelledCount { get; init; }
        public decimal TodayRevenue { get; init; }
    }

    private sealed class RecentOrderRow
    {
        public int Id { get; init; }
        public string OrderNumber { get; init; } = string.Empty;
        public string CustomerName { get; init; } = string.Empty;
        public string CustomerPhone { get; init; } = string.Empty;
        public decimal Total { get; init; }
        public string OrderStatus { get; init; } = string.Empty;
        public string PaymentStatus { get; init; } = string.Empty;
        public string PaymentMethod { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
        public string? ItemsSummary { get; init; }
    }

    private sealed class MenuItemRow
    {
        public int Id { get; init; }
        public string Name { get; init; } = string.Empty;
        public string Description { get; init; } = string.Empty;
        public decimal Price { get; init; }
        public string Category { get; init; } = string.Empty;
        public int CategoryId { get; init; }
        public bool IsAvailable { get; init; }
        public bool IsVegetarian { get; init; }
        public string ImageUrl { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
    }

    private sealed class CategoryRow
    {
        public int Id { get; init; }
        public string Name { get; init; } = string.Empty;
    }

    private sealed class ReviewRow
    {
        public int Id { get; init; }
        public int UserId { get; init; }
        public int? OrderId { get; init; }
        public int Rating { get; init; }
        public string ReviewText { get; init; } = string.Empty;
        public string AdminResponse { get; init; } = string.Empty;
        public DateTime? ResponseDate { get; init; }
        public string Status { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
        public string UserName { get; init; } = string.Empty;
    }

    private sealed class CanteenRow
    {
        public int Id { get; init; }
        public string Name { get; init; } = string.Empty;
        public string Description { get; init; } = string.Empty;
    }

    private sealed class SystemMaintenanceRow
    {
        public bool IsActive { get; init; }
        public string Message { get; init; } = string.Empty;
    }

    private sealed class CanteenMaintenanceRow
    {
        public bool IsActive { get; init; }
        public string Reason { get; init; } = string.Empty;
    }

    private sealed class RevenueRow
    {
        public decimal Today { get; init; }
        public decimal Week { get; init; }
        public decimal Month { get; init; }
        public decimal AllTime { get; init; }
        public int OrdersToday { get; init; }
        public int OrdersTotal { get; init; }
    }

    private sealed class PaymentBreakRow
    {
        public string Method { get; init; } = string.Empty;
        public int OrderCount { get; init; }
        public decimal Revenue { get; init; }
    }

    private sealed class AdminProfileRow
    {
        public string Name { get; init; } = string.Empty;
        public string Email { get; init; } = string.Empty;
        public string Contact { get; init; } = string.Empty;
        public string ImageUrl { get; init; } = string.Empty;
    }

    private sealed class PasswordRow
    {
        public int Id { get; init; }
        public string PasswordHash { get; init; } = string.Empty;
        public string PlainPassword { get; init; } = string.Empty;
    }

    // ── Request Models ────────────────────────────────────────────────────────

    public sealed class MenuItemRequest
    {
        public int CanteenId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public decimal Price { get; set; }
        public string? Category { get; set; }
        public string? ImageUrl { get; set; }
        public bool IsAvailable { get; set; } = true;
        public bool IsVegetarian { get; set; }
    }

    public sealed class AvailabilityRequest
    {
        public int CanteenId { get; set; }
        public bool IsAvailable { get; set; }
    }

    public sealed class ReviewResponseRequest
    {
        public int CanteenId { get; set; }
        public string Response { get; set; } = string.Empty;
    }

    public sealed class CanteenInfoRequest
    {
        public int CanteenId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Phone { get; set; }
        public string? OpeningTime { get; set; }
        public string? ClosingTime { get; set; }
    }

    public sealed class AdminProfileRequest
    {
        public int CanteenId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? ImageUrl { get; set; }
    }

    public sealed class SystemMaintenanceRequest
    {
        public int CanteenId { get; set; }
        public bool IsActive { get; set; }
        public string? Message { get; set; }
    }

    public sealed class CanteenMaintenanceRequest
    {
        public int CanteenId { get; set; }
        public bool IsActive { get; set; }
        public string? Reason { get; set; }
    }

    public sealed class ChangePasswordRequest
    {
        public int CanteenId { get; set; }
        public string CurrentPassword { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
        public string ConfirmPassword { get; set; } = string.Empty;
    }
}
