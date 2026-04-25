using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using UniversityCanteen.Api.Data;
using UniversityCanteen.Api.Services;
using UniversityCanteen.Api.Utils;

namespace UniversityCanteen.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/admin")]
public sealed class AdminManagementController(
    IDbConnectionFactory dbConnectionFactory,
    INotificationService notificationService,
    ILogger<AdminManagementController> logger) : ControllerBase
{
    private static readonly HashSet<string> EditableSettingKeys = new(StringComparer.OrdinalIgnoreCase)
    {
        "app_name",
        "logo_url",
        "tax_percentage",
        "delivery_charge",
        "min_order_delivery",
        "operating_hours_open",
        "operating_hours_close"
    };

    private static readonly (string Key, string DefaultValue, string Description)[] RequiredSettings =
    {
        ("app_name", "CampusEatzz", "Application display name"),
        ("logo_url", string.Empty, "Application logo URL"),
        ("tax_percentage", "5", "Tax percentage for orders"),
        ("delivery_charge", "50", "Delivery charge amount"),
        ("min_order_delivery", "200", "Minimum order amount for delivery"),
        ("operating_hours_open", "09:00", "Opening time"),
        ("operating_hours_close", "22:00", "Closing time")
    };

    [HttpGet("dashboard")]
    [ResponseCache(Duration = 30, Location = ResponseCacheLocation.Any)]
    public async Task<IActionResult> GetDashboard(CancellationToken cancellationToken)
    {
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var stats = await connection.QuerySingleAsync<DashboardStats>(new CommandDefinition(
                """
                SELECT
                    (SELECT COUNT(1) FROM orders) AS TotalOrders,
                    (SELECT COUNT(1) FROM orders WHERE order_status = 'pending') AS PendingOrders,
                    (SELECT COUNT(1) FROM orders WHERE DATE(created_at) = CURDATE()) AS TodayOrders,
                    (SELECT COUNT(1) FROM users WHERE COALESCE(is_deleted,0)=0) AS TotalUsers,
                    (SELECT COUNT(1) FROM canteens WHERE COALESCE(status,'active')='active') AS ActiveCanteens,
                    (SELECT COUNT(1) FROM contact_messages WHERE COALESCE(status,'unread')='unread') AS UnreadMessages,
                    (SELECT COUNT(1) FROM reviews) AS TotalReviews,
                    (SELECT COUNT(1) FROM orders WHERE order_status = 'completed') AS CompletedOrders,
                    (SELECT COUNT(1) FROM orders WHERE order_status = 'cancelled') AS CancelledOrders,
                    COALESCE((SELECT SUM(COALESCE(NULLIF(final_amount,0.00), total_amount, 0.00)) FROM orders WHERE order_status = 'completed'), 0.00) AS TotalRevenue;
                """,
                cancellationToken: cancellationToken));

            return Ok(Success("Dashboard loaded.", new
            {
                totalOrders = stats.TotalOrders,
                pendingOrders = stats.PendingOrders,
                todayOrders = stats.TodayOrders,
                totalRevenue = Math.Round(stats.TotalRevenue, 2),
                totalUsers = stats.TotalUsers,
                activeCanteens = stats.ActiveCanteens,
                unreadMessages = stats.UnreadMessages,
                totalReviews = stats.TotalReviews,
                completedOrders = stats.CompletedOrders,
                cancelledOrders = stats.CancelledOrders
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to load admin dashboard.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while loading dashboard."));
        }
    }

    [HttpGet("users")]
    [ResponseCache(Duration = 20, Location = ResponseCacheLocation.Any)]
    public async Task<IActionResult> GetUsers([FromQuery] string? search, [FromQuery] string? status, [FromQuery] int limit = 100, [FromQuery] int offset = 0, CancellationToken cancellationToken = default)
    {
        var normalizedSearch = (search ?? string.Empty).Trim();
        var normalizedStatus = (status ?? string.Empty).Trim().ToLowerInvariant();
        var normalizedLimit = Math.Clamp(limit, 1, 200);
        var normalizedOffset = Math.Max(offset, 0);

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var users = (await connection.QueryAsync<UserRow>(new CommandDefinition(
                """
                SELECT
                    u.id AS Id,
                    COALESCE(u.first_name, '') AS FirstName,
                    COALESCE(u.last_name, '') AS LastName,
                    COALESCE(u.email, '') AS Email,
                    COALESCE(u.contact, '') AS Contact,
                    COALESCE(u.department, '') AS Department,
                    COALESCE(u.role, 'student') AS Role,
                    u.canteen_id AS CanteenId,
                    COALESCE(u.status, 'active') AS Status,
                    COALESCE(u.created_at, UTC_TIMESTAMP()) AS CreatedAt,
                    0 AS TotalOrders,
                    0.00 AS TotalSpent
                FROM users u
                WHERE COALESCE(u.is_deleted, 0) = 0
                  AND (@status = '' OR LOWER(COALESCE(u.status, 'active')) = @status)
                  AND (
                      @search = ''
                      OR COALESCE(u.first_name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.last_name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.email, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.contact, '') LIKE CONCAT('%', @search, '%')
                  )
                ORDER BY u.id DESC
                LIMIT @limit OFFSET @offset;
                """,
                new
                {
                    search = normalizedSearch,
                    status = normalizedStatus,
                    limit = normalizedLimit,
                    offset = normalizedOffset
                },
                cancellationToken: cancellationToken))).ToList();

            var totalCount = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
                """
                SELECT COUNT(1) FROM users u
                WHERE COALESCE(u.is_deleted, 0) = 0
                  AND (@status = '' OR LOWER(COALESCE(u.status, 'active')) = @status)
                  AND (
                      @search = ''
                      OR COALESCE(u.first_name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.last_name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.email, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.contact, '') LIKE CONCAT('%', @search, '%')
                  );
                """,
                new
                {
                    search = normalizedSearch,
                    status = normalizedStatus
                },
                cancellationToken: cancellationToken));

            return Ok(Success("Users fetched.", new
            {
                users = users.Select(MapUser),
                total = totalCount,
                count = users.Count,
                limit = normalizedLimit,
                offset = normalizedOffset,
                active = users.Count(u => string.Equals(u.Status, "active", StringComparison.OrdinalIgnoreCase))
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch users.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching users."));
        }
    }

    [HttpPost("users")]
    public async Task<IActionResult> CreateUser([FromBody] UserUpsertRequest request, CancellationToken cancellationToken)
    {
        var validation = ValidateUserRequest(request, requirePassword: true);
        if (validation is not null)
        {
            return BadRequest(Failure(validation));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var exists = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
                "SELECT COUNT(1) FROM users WHERE LOWER(email) = LOWER(@email) AND COALESCE(is_deleted,0)=0;",
                new { email = request.Email!.Trim() },
                cancellationToken: cancellationToken));
            if (exists > 0)
            {
                return Conflict(Failure("A user with this email already exists."));
            }

            var role = NormalizeRole(request.Role);
            var status = NormalizeStatus(request.Status);
            var passwordHash = BCrypt.Net.BCrypt.HashPassword(request.Password!.Trim());

            var id = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
                """
                INSERT INTO users
                    (UniversityId, first_name, last_name, email, contact, department, password_hash, role, canteen_id, status, is_deleted, created_at)
                VALUES
                    (@universityId, @firstName, @lastName, @email, @contact, @department, @passwordHash, @role, @canteenId, @status, 0, UTC_TIMESTAMP());
                SELECT LAST_INSERT_ID();
                """,
                new
                {
                    universityId = string.IsNullOrWhiteSpace(request.UniversityId) ? null : request.UniversityId.Trim(),
                    firstName = request.FirstName!.Trim(),
                    lastName = request.LastName!.Trim(),
                    email = request.Email!.Trim(),
                    contact = request.Contact?.Trim() ?? string.Empty,
                    department = request.Department?.Trim() ?? string.Empty,
                    passwordHash,
                    role,
                    canteenId = request.CanteenId,
                    status
                },
                cancellationToken: cancellationToken));

            return Ok(Success("User created successfully.", new { id }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to create user.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while creating user."));
        }
    }

    [HttpPut("users/{id:int}")]
    public async Task<IActionResult> UpdateUser(int id, [FromBody] UserUpsertRequest request, CancellationToken cancellationToken)
    {
        if (id <= 0)
        {
            return BadRequest(Failure("Valid user id is required."));
        }

        var validation = ValidateUserRequest(request, requirePassword: false);
        if (validation is not null)
        {
            return BadRequest(Failure(validation));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var exists = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
                "SELECT COUNT(1) FROM users WHERE id = @id AND COALESCE(is_deleted,0)=0;",
                new { id },
                cancellationToken: cancellationToken));
            if (exists == 0)
            {
                return NotFound(Failure("User not found."));
            }

            var role = NormalizeRole(request.Role);
            var status = NormalizeStatus(request.Status);
            var setPasswordSql = string.IsNullOrWhiteSpace(request.Password)
                ? string.Empty
                : ", password_hash = @passwordHash";

            await connection.ExecuteAsync(new CommandDefinition(
                $"""
                UPDATE users
                SET UniversityId = @universityId,
                    first_name = @firstName,
                    last_name = @lastName,
                    email = @email,
                    contact = @contact,
                    department = @department,
                    role = @role,
                    canteen_id = @canteenId,
                    status = @status
                    {setPasswordSql}
                WHERE id = @id;
                """,
                new
                {
                    id,
                    universityId = string.IsNullOrWhiteSpace(request.UniversityId) ? null : request.UniversityId.Trim(),
                    firstName = request.FirstName!.Trim(),
                    lastName = request.LastName!.Trim(),
                    email = request.Email!.Trim(),
                    contact = request.Contact?.Trim() ?? string.Empty,
                    department = request.Department?.Trim() ?? string.Empty,
                    role,
                    canteenId = request.CanteenId,
                    status,
                    passwordHash = string.IsNullOrWhiteSpace(request.Password) ? null : BCrypt.Net.BCrypt.HashPassword(request.Password.Trim())
                },
                cancellationToken: cancellationToken));

            return Ok(Success("User updated successfully."));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to update user {UserId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while updating user."));
        }
    }

    [HttpDelete("users/{id:int}")]
    public async Task<IActionResult> DeleteUser(int id, CancellationToken cancellationToken)
    {
        if (id <= 0)
        {
            return BadRequest(Failure("Valid user id is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var rows = await connection.ExecuteAsync(new CommandDefinition(
                """
                UPDATE users
                SET is_deleted = 1,
                    deleted_at = UTC_TIMESTAMP(),
                    status = 'inactive'
                WHERE id = @id
                  AND COALESCE(is_deleted,0) = 0;
                """,
                new { id },
                cancellationToken: cancellationToken));

            if (rows == 0)
            {
                return NotFound(Failure("User not found."));
            }

            return Ok(Success("User removed successfully."));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to delete user {UserId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while deleting user."));
        }
    }

    [HttpGet("canteens")]
    [ResponseCache(Duration = 30, Location = ResponseCacheLocation.Any)]
    public async Task<IActionResult> GetCanteens(CancellationToken cancellationToken)
    {
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var canteens = await connection.QueryAsync<CanteenRow>(new CommandDefinition(
                """
                SELECT
                    c.id AS Id,
                    c.name AS Name,
                    COALESCE(c.description, '') AS Description,
                    COALESCE(c.image_url, '') AS ImageUrl,
                    COALESCE(c.status, 'active') AS Status,
                    COALESCE(c.display_order, 0) AS DisplayOrder,
                    COALESCE(c.created_at, UTC_TIMESTAMP()) AS CreatedAt,
                    COALESCE(ua.AdminCount, 0) AS AdminCount
                FROM canteens c
                LEFT JOIN (
                    SELECT canteen_id, COUNT(1) AS AdminCount
                    FROM users
                    WHERE role='canteen_admin' AND COALESCE(is_deleted,0)=0
                    GROUP BY canteen_id
                ) ua ON c.id = ua.canteen_id
                ORDER BY c.display_order ASC, c.id ASC;
                """,
                cancellationToken: cancellationToken));

            var list = canteens.ToList();
            return Ok(Success("Canteens fetched.", new
            {
                canteens = list.Select(c => new
                {
                    id = c.Id,
                    name = c.Name,
                    description = c.Description,
                    imageUrl = ToClientImageUrl(c.ImageUrl),
                    status = c.Status,
                    displayOrder = c.DisplayOrder,
                    createdAt = c.CreatedAt,
                    adminCount = c.AdminCount
                }),
                total = list.Count
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch canteens.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching canteens."));
        }
    }

    [HttpPost("canteens/upload-image")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> UploadCanteenImage(IFormFile? image, CancellationToken cancellationToken)
    {
        if (image == null || image.Length == 0)
        {
            return BadRequest(Failure("No image file provided."));
        }

        const long maxBytes = 20 * 1024 * 1024; // 20 MB
        if (image.Length > maxBytes)
        {
            return BadRequest(Failure("Image must be smaller than 20 MB."));
        }

        var ext = Path.GetExtension(image.FileName).ToLowerInvariant();
        if (ext is not (".jpg" or ".jpeg" or ".png" or ".webp"))
        {
            return BadRequest(Failure("Only JPG, PNG, or WebP images are allowed."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var uploadDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "canteens");
            Directory.CreateDirectory(uploadDir);

            var fileName = $"canteen_{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}_{Guid.NewGuid():N}{ext}";
            var filePath = Path.Combine(uploadDir, fileName);

            await using (var stream = System.IO.File.Create(filePath))
            {
                await image.CopyToAsync(stream, cancellationToken);
            }

            var relativePath = $"uploads/canteens/{fileName}";
            var absoluteUrl = $"{Request.Scheme}://{Request.Host}/{relativePath}";

            return Ok(Success("Image uploaded.", new { url = absoluteUrl, relativePath }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Admin canteen image upload failed.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error during upload."));
        }
    }

    [HttpPost("canteens")]
    public async Task<IActionResult> CreateCanteen([FromBody] CanteenUpsertRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return BadRequest(Failure("Canteen name is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var status = request.IsActive ? "active" : "deactive";
            var id = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
                """
                INSERT INTO canteens (name, description, image_url, status, display_order, created_at)
                VALUES (@name, @description, @imageUrl, @status, @displayOrder, UTC_TIMESTAMP());
                SELECT LAST_INSERT_ID();
                """,
                new
                {
                    name = request.Name.Trim(),
                    description = request.Description?.Trim(),
                    imageUrl = request.ImageUrl?.Trim(),
                    status,
                    displayOrder = request.DisplayOrder
                },
                cancellationToken: cancellationToken));

            return Ok(Success("Canteen created successfully.", new { id }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to create canteen.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while creating canteen."));
        }
    }

    [HttpPut("canteens/{id:int}")]
    public async Task<IActionResult> UpdateCanteen(int id, [FromBody] CanteenUpsertRequest request, CancellationToken cancellationToken)
    {
        if (id <= 0)
        {
            return BadRequest(Failure("Valid canteen id is required."));
        }

        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return BadRequest(Failure("Canteen name is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var rows = await connection.ExecuteAsync(new CommandDefinition(
                """
                UPDATE canteens
                SET name = @name,
                    description = @description,
                    image_url = @imageUrl,
                    status = @status,
                    display_order = @displayOrder
                WHERE id = @id;
                """,
                new
                {
                    id,
                    name = request.Name.Trim(),
                    description = request.Description?.Trim(),
                    imageUrl = request.ImageUrl?.Trim(),
                    status = request.IsActive ? "active" : "deactive",
                    displayOrder = request.DisplayOrder
                },
                cancellationToken: cancellationToken));

            if (rows == 0)
            {
                return NotFound(Failure("Canteen not found."));
            }

            return Ok(Success("Canteen updated successfully."));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to update canteen {CanteenId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while updating canteen."));
        }
    }

    [HttpDelete("canteens/{id:int}")]
    public async Task<IActionResult> DeleteCanteen(int id, CancellationToken cancellationToken)
    {
        if (id <= 0)
        {
            return BadRequest(Failure("Valid canteen id is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var rows = await connection.ExecuteAsync(new CommandDefinition(
                "DELETE FROM canteens WHERE id = @id;",
                new { id },
                cancellationToken: cancellationToken));

            if (rows == 0)
            {
                return NotFound(Failure("Canteen not found."));
            }

            return Ok(Success("Canteen deleted successfully."));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to delete canteen {CanteenId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while deleting canteen."));
        }
    }

    [HttpGet("canteen-admins")]
    public async Task<IActionResult> GetCanteenAdmins(CancellationToken cancellationToken)
    {
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var admins = await connection.QueryAsync<CanteenAdminRow>(new CommandDefinition(
                """
                SELECT
                    ca.id AS Id,
                    ca.canteen_id AS CanteenId,
                    COALESCE(c.name, 'Unknown') AS CanteenName,
                    COALESCE(ca.username, '') AS Username,
                    COALESCE(ca.name, '') AS Name,
                    COALESCE(ca.email, '') AS Email,
                    COALESCE(ca.contact, '') AS Contact,
                    COALESCE(ca.image_url, '') AS ImageUrl,
                    COALESCE(ca.status, 'active') AS Status,
                    COALESCE(ca.created_at, UTC_TIMESTAMP()) AS CreatedAt
                FROM canteen_admins ca
                LEFT JOIN canteens c ON c.id = ca.canteen_id
                ORDER BY ca.id DESC;
                """,
                cancellationToken: cancellationToken));

            var list = admins.ToList();
            return Ok(Success("Canteen admins fetched.", new
            {
                admins = list.Select(a => new
                {
                    id = a.Id,
                    canteenId = a.CanteenId,
                    canteenName = a.CanteenName,
                    username = a.Username,
                    name = a.Name,
                    email = a.Email,
                    contact = a.Contact,
                    imageUrl = ToClientImageUrl(a.ImageUrl),
                    status = a.Status,
                    createdAt = a.CreatedAt
                }),
                total = list.Count
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch canteen admins.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching canteen admins."));
        }
    }

    [HttpPost("canteen-admins")]
    public async Task<IActionResult> CreateCanteenAdmin([FromBody] CanteenAdminUpsertRequest request, CancellationToken cancellationToken)
    {
        var validation = ValidateCanteenAdminRequest(request, requirePassword: true);
        if (validation is not null)
        {
            return BadRequest(Failure(validation));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var hashedPassword = BCrypt.Net.BCrypt.HashPassword(request.Password!.Trim());
            var id = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
                """
                INSERT INTO canteen_admins
                    (canteen_id, username, password, plain_password, name, email, contact, image_url, status, created_at, updated_at)
                VALUES
                    (@canteenId, @username, @password, @plainPassword, @name, @email, @contact, @imageUrl, @status, UTC_TIMESTAMP(), UTC_TIMESTAMP());
                SELECT LAST_INSERT_ID();
                """,
                new
                {
                    canteenId = request.CanteenId,
                    username = request.Username!.Trim(),
                    password = hashedPassword,
                    plainPassword = request.Password!.Trim(),
                    name = request.Name!.Trim(),
                    email = request.Email?.Trim(),
                    contact = request.Contact?.Trim(),
                    imageUrl = request.ImageUrl?.Trim(),
                    status = NormalizeStatus(request.Status)
                },
                cancellationToken: cancellationToken));

            return Ok(Success("Canteen admin created successfully.", new { id }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to create canteen admin.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while creating canteen admin."));
        }
    }

    [HttpPut("canteen-admins/{id:int}")]
    public async Task<IActionResult> UpdateCanteenAdmin(int id, [FromBody] CanteenAdminUpsertRequest request, CancellationToken cancellationToken)
    {
        if (id <= 0)
        {
            return BadRequest(Failure("Valid canteen admin id is required."));
        }

        var validation = ValidateCanteenAdminRequest(request, requirePassword: false);
        if (validation is not null)
        {
            return BadRequest(Failure(validation));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var setPasswordSql = string.IsNullOrWhiteSpace(request.Password)
                ? string.Empty
                : ", password = @password, plain_password = @plainPassword";

            var rows = await connection.ExecuteAsync(new CommandDefinition(
                $"""
                UPDATE canteen_admins
                SET canteen_id = @canteenId,
                    username = @username,
                    name = @name,
                    email = @email,
                    contact = @contact,
                    image_url = @imageUrl,
                    status = @status,
                    updated_at = UTC_TIMESTAMP()
                    {setPasswordSql}
                WHERE id = @id;
                """,
                new
                {
                    id,
                    canteenId = request.CanteenId,
                    username = request.Username!.Trim(),
                    name = request.Name!.Trim(),
                    email = request.Email?.Trim(),
                    contact = request.Contact?.Trim(),
                    imageUrl = request.ImageUrl?.Trim(),
                    status = NormalizeStatus(request.Status),
                    password = string.IsNullOrWhiteSpace(request.Password) ? null : BCrypt.Net.BCrypt.HashPassword(request.Password.Trim()),
                    plainPassword = string.IsNullOrWhiteSpace(request.Password) ? null : request.Password.Trim()
                },
                cancellationToken: cancellationToken));

            if (rows == 0)
            {
                return NotFound(Failure("Canteen admin not found."));
            }

            return Ok(Success("Canteen admin updated successfully."));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to update canteen admin {AdminId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while updating canteen admin."));
        }
    }

    [HttpDelete("canteen-admins/{id:int}")]
    public async Task<IActionResult> DeleteCanteenAdmin(int id, CancellationToken cancellationToken)
    {
        if (id <= 0)
        {
            return BadRequest(Failure("Valid canteen admin id is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var rows = await connection.ExecuteAsync(new CommandDefinition(
                "DELETE FROM canteen_admins WHERE id = @id;",
                new { id },
                cancellationToken: cancellationToken));

            if (rows == 0)
            {
                return NotFound(Failure("Canteen admin not found."));
            }

            return Ok(Success("Canteen admin deleted successfully."));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to delete canteen admin {AdminId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while deleting canteen admin."));
        }
    }

    [HttpGet("contact-messages")]
    public async Task<IActionResult> GetContactMessages([FromQuery] string? status, [FromQuery] string? search, CancellationToken cancellationToken)
    {
        var normalizedStatus = (status ?? string.Empty).Trim().ToLowerInvariant();
        var normalizedSearch = (search ?? string.Empty).Trim();

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var rows = await connection.QueryAsync<ContactMessageRow>(new CommandDefinition(
                """
                SELECT
                    id AS Id,
                    COALESCE(name, '') AS Name,
                    COALESCE(email, '') AS Email,
                    COALESCE(subject, '') AS Subject,
                    COALESCE(message, '') AS Message,
                    COALESCE(status, 'unread') AS Status,
                    created_at AS CreatedAt,
                    replied_at AS RepliedAt,
                    COALESCE(reply_message, '') AS ReplyMessage
                FROM contact_messages
                WHERE (@status = '' OR LOWER(COALESCE(status,'unread')) = @status)
                  AND (
                      @search = ''
                      OR COALESCE(name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(email, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(subject, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(message, '') LIKE CONCAT('%', @search, '%')
                  )
                ORDER BY created_at DESC;
                """,
                new { status = normalizedStatus, search = normalizedSearch },
                cancellationToken: cancellationToken));

            var list = rows.ToList();
            return Ok(Success("Contact messages fetched.", new
            {
                messages = list,
                total = list.Count,
                unread = list.Count(m => string.Equals(m.Status, "unread", StringComparison.OrdinalIgnoreCase))
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch contact messages.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching contact messages."));
        }
    }

    [HttpPatch("contact-messages/{id:int}/status")]
    public async Task<IActionResult> UpdateContactMessageStatus(int id, [FromBody] MessageStatusRequest request, CancellationToken cancellationToken)
    {
        if (id <= 0)
        {
            return BadRequest(Failure("Valid message id is required."));
        }

        var status = (request.Status ?? string.Empty).Trim().ToLowerInvariant();
        if (status is not ("unread" or "read" or "replied"))
        {
            return BadRequest(Failure("Status must be unread, read, or replied."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var rows = await connection.ExecuteAsync(new CommandDefinition(
                "UPDATE contact_messages SET status = @status WHERE id = @id;",
                new { id, status },
                cancellationToken: cancellationToken));

            if (rows == 0)
            {
                return NotFound(Failure("Message not found."));
            }

            return Ok(Success("Message status updated successfully."));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to update contact message status {MessageId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while updating message status."));
        }
    }

    [HttpDelete("contact-messages/{id:int}")]
    public async Task<IActionResult> DeleteContactMessage(int id, CancellationToken cancellationToken)
    {
        if (id <= 0)
        {
            return BadRequest(Failure("Valid message id is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var rows = await connection.ExecuteAsync(new CommandDefinition(
                "DELETE FROM contact_messages WHERE id = @id;",
                new { id },
                cancellationToken: cancellationToken));

            if (rows == 0)
            {
                return NotFound(Failure("Message not found."));
            }

            return Ok(Success("Message deleted successfully."));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to delete contact message {MessageId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while deleting message."));
        }
    }

    [HttpGet("reviews")]
    [ResponseCache(Duration = 20, Location = ResponseCacheLocation.Any)]
    public async Task<IActionResult> GetReviews([FromQuery] int? rating, [FromQuery] string? status, [FromQuery] string? search, [FromQuery] int limit = 50, [FromQuery] int offset = 0, CancellationToken cancellationToken = default)
    {
        var normalizedStatus = (status ?? string.Empty).Trim().ToLowerInvariant();
        var normalizedSearch = (search ?? string.Empty).Trim();
        var normalizedLimit = Math.Clamp(limit, 1, 200);
        var normalizedOffset = Math.Max(offset, 0);

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var rows = await connection.QueryAsync<ReviewRow>(new CommandDefinition(
                """
                SELECT
                    r.id AS Id,
                    r.user_id AS UserId,
                    COALESCE(u.first_name, '') AS UserFirstName,
                    COALESCE(u.last_name, '') AS UserLastName,
                    COALESCE(u.email, '') AS UserEmail,
                    r.canteen_id AS CanteenId,
                    COALESCE(c.name, 'Unknown') AS CanteenName,
                    COALESCE(r.rating, 0) AS Rating,
                    COALESCE(r.review_text, '') AS ReviewText,
                    COALESCE(r.admin_response, '') AS AdminResponse,
                    COALESCE(r.status, 'active') AS Status,
                    COALESCE(r.created_at, UTC_TIMESTAMP()) AS CreatedAt
                FROM reviews r
                LEFT JOIN users u ON u.id = r.user_id
                LEFT JOIN canteens c ON c.id = r.canteen_id
                WHERE (@status = '' OR LOWER(COALESCE(r.status, 'active')) = @status)
                  AND (@rating IS NULL OR r.rating = @rating)
                  AND (
                      @search = ''
                      OR COALESCE(r.review_text, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.first_name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(u.last_name, '') LIKE CONCAT('%', @search, '%')
                      OR COALESCE(c.name, '') LIKE CONCAT('%', @search, '%')
                  )
                ORDER BY r.created_at DESC
                LIMIT @limit OFFSET @offset;
                """,
                new
                {
                    status = normalizedStatus,
                    rating,
                    search = normalizedSearch,
                    limit = normalizedLimit,
                    offset = normalizedOffset
                },
                cancellationToken: cancellationToken));

            var list = rows.ToList();
            var average = list.Count == 0 ? 0d : list.Average(r => r.Rating);

            return Ok(Success("Reviews fetched.", new
            {
                reviews = list.Select(r => new
                {
                    id = r.Id,
                    userId = r.UserId,
                    userName = BuildName(r.UserFirstName, r.UserLastName),
                    userEmail = r.UserEmail,
                    canteenId = r.CanteenId,
                    canteenName = r.CanteenName,
                    rating = r.Rating,
                    reviewText = r.ReviewText,
                    adminResponse = r.AdminResponse,
                    status = r.Status,
                    createdAt = r.CreatedAt
                }),
                count = list.Count,
                limit = normalizedLimit,
                offset = normalizedOffset,
                averageRating = Math.Round(average, 1),
                positive = list.Count(r => r.Rating >= 4),
                responded = list.Count(r => !string.IsNullOrWhiteSpace(r.AdminResponse))
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch reviews.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching reviews."));
        }
    }

    [HttpPatch("reviews/{id:int}/status")]
    public async Task<IActionResult> UpdateReviewStatus(int id, [FromBody] ReviewStatusRequest request, CancellationToken cancellationToken)
    {
        if (id <= 0)
        {
            return BadRequest(Failure("Valid review id is required."));
        }

        var status = (request.Status ?? string.Empty).Trim().ToLowerInvariant();
        if (status is not ("active" or "hidden"))
        {
            return BadRequest(Failure("Status must be active or hidden."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var rows = await connection.ExecuteAsync(new CommandDefinition(
                "UPDATE reviews SET status = @status WHERE id = @id;",
                new { id, status },
                cancellationToken: cancellationToken));

            if (rows == 0)
            {
                return NotFound(Failure("Review not found."));
            }

            return Ok(Success("Review status updated successfully."));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to update review status {ReviewId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while updating review status."));
        }
    }

    [HttpGet("settings")]
    public async Task<IActionResult> GetSettings(CancellationToken cancellationToken)
    {
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            await EnsureRequiredSettingsAsync(connection, cancellationToken);

            var settings = await connection.QueryAsync<SystemSettingRow>(new CommandDefinition(
                """
                SELECT
                    id AS Id,
                    setting_key AS SettingKey,
                    COALESCE(setting_value, '') AS SettingValue,
                    COALESCE(description, '') AS Description,
                    updated_at AS UpdatedAt
                FROM system_settings
                WHERE LOWER(setting_key) IN @keys
                ORDER BY setting_key ASC;
                """,
                new
                {
                    keys = EditableSettingKeys.Select(x => x.ToLowerInvariant()).ToArray()
                },
                cancellationToken: cancellationToken));

            var settingsList = settings.ToList();
            var values = settingsList.ToDictionary(
                item => item.SettingKey,
                item => string.Equals(item.SettingKey, "logo_url", StringComparison.OrdinalIgnoreCase)
                    ? ToClientImageUrl(item.SettingValue)
                    : item.SettingValue,
                StringComparer.OrdinalIgnoreCase);

            return Ok(Success("Settings fetched.", new
            {
                settings = settingsList.Select(item => new
                {
                    id = item.Id,
                    settingKey = item.SettingKey,
                    settingValue = string.Equals(item.SettingKey, "logo_url", StringComparison.OrdinalIgnoreCase)
                        ? ToClientImageUrl(item.SettingValue)
                        : item.SettingValue,
                    description = item.Description,
                    updatedAt = item.UpdatedAt
                }),
                values
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch settings.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching settings."));
        }
    }

    [HttpPut("settings")]
    public async Task<IActionResult> UpsertSetting([FromBody] SystemSettingRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.SettingKey))
        {
            return BadRequest(Failure("Setting key is required."));
        }

        var normalizedKey = request.SettingKey.Trim().ToLowerInvariant();
        if (!EditableSettingKeys.Contains(normalizedKey))
        {
            return BadRequest(Failure("Unsupported setting key."));
        }

        var normalizedValue = (request.SettingValue ?? string.Empty).Trim();
        var validationError = ValidateSettingValue(normalizedKey, normalizedValue);
        if (!string.IsNullOrWhiteSpace(validationError))
        {
            return BadRequest(Failure(validationError));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            await EnsureRequiredSettingsAsync(connection, cancellationToken);

            await connection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO system_settings (setting_key, setting_value, description, updated_at)
                VALUES (@settingKey, @settingValue, @description, UTC_TIMESTAMP())
                ON DUPLICATE KEY UPDATE
                    setting_value = VALUES(setting_value),
                    description = COALESCE(VALUES(description), description),
                    updated_at = UTC_TIMESTAMP();
                """,
                new
                {
                    settingKey = normalizedKey,
                    settingValue = normalizedValue,
                    description = string.IsNullOrWhiteSpace(request.Description)
                        ? RequiredSettings.FirstOrDefault(item => item.Key.Equals(normalizedKey, StringComparison.OrdinalIgnoreCase)).Description
                        : request.Description.Trim()
                },
                cancellationToken: cancellationToken));

            await SyncSettingToLegacyTableAsync(
                connection,
                normalizedKey,
                normalizedValue,
                string.IsNullOrWhiteSpace(request.Description)
                    ? RequiredSettings.FirstOrDefault(item => item.Key.Equals(normalizedKey, StringComparison.OrdinalIgnoreCase)).Description
                    : request.Description.Trim(),
                cancellationToken);

            var outboundValue = string.Equals(normalizedKey, "logo_url", StringComparison.OrdinalIgnoreCase)
                ? ToClientImageUrl(normalizedValue)
                : normalizedValue;

            return Ok(Success("Setting saved successfully.", new
            {
                settingKey = normalizedKey,
                settingValue = outboundValue
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to update setting {SettingKey}", request.SettingKey);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while saving setting."));
        }
    }

    [HttpPost("settings/logo-upload")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> UploadLogo(IFormFile? logo, CancellationToken cancellationToken)
    {
        if (logo == null || logo.Length == 0)
        {
            return BadRequest(Failure("Logo file is required."));
        }

        const long maxBytes = 5 * 1024 * 1024;
        if (logo.Length > maxBytes)
        {
            return BadRequest(Failure("Logo must be smaller than 5 MB."));
        }

        var ext = Path.GetExtension(logo.FileName).ToLowerInvariant();
        if (ext is not (".jpg" or ".jpeg" or ".png" or ".webp" or ".svg"))
        {
            return BadRequest(Failure("Only JPG, PNG, WebP, or SVG images are allowed."));
        }

        var contentType = (logo.ContentType ?? string.Empty).Trim().ToLowerInvariant();
        if (!contentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase)
            && ext is not ".svg")
        {
            return BadRequest(Failure("Invalid file type. Please upload an image file."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            await EnsureRequiredSettingsAsync(connection, cancellationToken);

            var uploadDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "settings");
            Directory.CreateDirectory(uploadDir);

            var fileName = $"logo_{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}_{Guid.NewGuid():N}{ext}";
            var absolutePath = Path.Combine(uploadDir, fileName);

            await using (var stream = System.IO.File.Create(absolutePath))
            {
                await logo.CopyToAsync(stream, cancellationToken);
            }

            var relativePath = $"uploads/settings/{fileName}";

            await connection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO system_settings (setting_key, setting_value, description, updated_at)
                VALUES ('logo_url', @value, 'Application logo URL', UTC_TIMESTAMP())
                ON DUPLICATE KEY UPDATE
                    setting_value = VALUES(setting_value),
                    updated_at = UTC_TIMESTAMP();
                """,
                new { value = relativePath },
                cancellationToken: cancellationToken));

            await SyncSettingToLegacyTableAsync(
                connection,
                "logo_url",
                relativePath,
                "Application logo URL",
                cancellationToken);

            return Ok(Success("Logo uploaded successfully.", new
            {
                logoUrl = ToClientImageUrl(relativePath),
                relativePath
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to upload app logo.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while uploading logo."));
        }
    }

    [HttpGet("profile")]
    public async Task<IActionResult> GetAdminProfile(CancellationToken cancellationToken)
    {
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var admin = await GetAuthenticatedAdminAsync(connection, cancellationToken);
            if (admin is null)
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            return Ok(Success("Admin profile fetched.", new
            {
                id = admin.Id,
                name = admin.Name,
                email = admin.Email,
                createdAt = admin.CreatedAt
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch admin profile.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while fetching admin profile."));
        }
    }

    [HttpPut("profile")]
    public async Task<IActionResult> UpdateAdminProfile([FromBody] AdminProfileUpdateRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return BadRequest(Failure("Name is required."));
        }

        if (string.IsNullOrWhiteSpace(request.Email))
        {
            return BadRequest(Failure("Email is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var admin = await GetAuthenticatedAdminAsync(connection, cancellationToken);
            if (admin is null)
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var normalizedEmail = request.Email.Trim();
            var emailInUse = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
                "SELECT COUNT(1) FROM admin_users WHERE LOWER(email) = LOWER(@email) AND id <> @id;",
                new { email = normalizedEmail, id = admin.Id },
                cancellationToken: cancellationToken));

            if (emailInUse > 0)
            {
                return Conflict(Failure("Another admin already uses this email address."));
            }

            await connection.ExecuteAsync(new CommandDefinition(
                "UPDATE admin_users SET name = @name, email = @email WHERE id = @id;",
                new
                {
                    id = admin.Id,
                    name = request.Name.Trim(),
                    email = normalizedEmail
                },
                cancellationToken: cancellationToken));

            var requiresRelogin = !string.Equals(admin.Email, normalizedEmail, StringComparison.OrdinalIgnoreCase);
            return Ok(Success("Profile updated successfully.", new
            {
                id = admin.Id,
                name = request.Name.Trim(),
                email = normalizedEmail,
                requiresRelogin
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to update admin profile.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while updating admin profile."));
        }
    }

    [HttpPut("profile/password")]
    public async Task<IActionResult> ChangeAdminPassword([FromBody] AdminPasswordChangeRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.CurrentPassword)
            || string.IsNullOrWhiteSpace(request.NewPassword)
            || string.IsNullOrWhiteSpace(request.ConfirmPassword))
        {
            return BadRequest(Failure("Current password, new password, and confirmation are required."));
        }

        if (request.NewPassword.Trim().Length < 6)
        {
            return BadRequest(Failure("New password must be at least 6 characters."));
        }

        if (!string.Equals(request.NewPassword.Trim(), request.ConfirmPassword.Trim(), StringComparison.Ordinal))
        {
            return BadRequest(Failure("New password and confirm password must match."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var admin = await GetAuthenticatedAdminAsync(connection, cancellationToken);
            if (admin is null)
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var isCurrentPasswordValid = false;
            try
            {
                isCurrentPasswordValid = BCrypt.Net.BCrypt.Verify(request.CurrentPassword, admin.PasswordHash);
            }
            catch
            {
                isCurrentPasswordValid = false;
            }

            if (!isCurrentPasswordValid)
            {
                return BadRequest(Failure("Current password is incorrect."));
            }

            var newHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword.Trim());
            await connection.ExecuteAsync(new CommandDefinition(
                "UPDATE admin_users SET password = @password WHERE id = @id;",
                new { password = newHash, id = admin.Id },
                cancellationToken: cancellationToken));

            return Ok(Success("Password changed successfully."));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to change admin password.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while changing password."));
        }
    }

    // ── Maintenance ───────────────────────────────────────────────────────────

    [HttpGet("maintenance")]
    public async Task<IActionResult> GetMaintenanceStatus(CancellationToken cancellationToken)
    {
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var systemRow = await connection.QuerySingleOrDefaultAsync<AdminSystemMaintenanceRow>(new CommandDefinition(
                "SELECT is_active AS IsActive, COALESCE(maintenance_message,'') AS Message FROM website_maintenance WHERE id = 1 LIMIT 1;",
                cancellationToken: cancellationToken));

            var canteenRows = await connection.QueryAsync<AdminCanteenMaintenanceRow>(new CommandDefinition(
                """
                SELECT
                    c.id AS CanteenId,
                    c.name AS CanteenName,
                    COALESCE(m.is_active, 0) AS IsActive,
                    COALESCE(m.reason, '') AS Reason
                FROM canteens c
                LEFT JOIN maintenance_mode m ON m.canteen_id = c.id
                WHERE COALESCE(c.status,'active') <> 'deleted'
                ORDER BY c.display_order, c.name;
                """,
                cancellationToken: cancellationToken));

            return Ok(Success("Maintenance status loaded.", new
            {
                isSystemMaintenanceActive = systemRow?.IsActive ?? false,
                systemMaintenanceReason   = systemRow?.Message ?? "",
                canteens = canteenRows.Select(r => new
                {
                    canteenId     = r.CanteenId,
                    canteenName   = r.CanteenName,
                    isActive      = r.IsActive,
                    reason        = r.Reason
                })
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "GetAdminMaintenanceStatus failed");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while loading maintenance status."));
        }
    }

    [HttpPut("maintenance/system")]
    public async Task<IActionResult> UpdateSystemMaintenance([FromBody] AdminSystemMaintenanceRequest request, CancellationToken cancellationToken)
    {
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var admin = await GetAuthenticatedAdminAsync(connection, cancellationToken);
            if (admin is null)
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var message = string.IsNullOrWhiteSpace(request.Reason)
                ? "We are currently performing maintenance. Please check back soon."
                : request.Reason.Trim();

            await connection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO website_maintenance (id, is_active, maintenance_message)
                VALUES (1, @isActive, @message)
                ON DUPLICATE KEY UPDATE is_active = @isActive, maintenance_message = @message;
                """,
                new { isActive = request.IsActive, message },
                cancellationToken: cancellationToken));

            try
            {
                await notificationService.NotifySystemMaintenanceAsync(
                    request.IsActive,
                    message,
                    admin.Id,
                    "admin",
                    cancellationToken);
            }
            catch (Exception notificationEx)
            {
                logger.LogWarning(notificationEx, "Failed to publish system maintenance notification.");
            }

            return Ok(Success($"System maintenance {(request.IsActive ? "enabled" : "disabled")}.", null!));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "UpdateAdminSystemMaintenance failed");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while updating system maintenance."));
        }
    }

    [HttpPut("maintenance/canteen")]
    public async Task<IActionResult> UpdateCanteenMaintenance([FromBody] AdminCanteenMaintenanceRequest request, CancellationToken cancellationToken)
    {
        if (request.CanteenId <= 0)
        {
            return BadRequest(Failure("Canteen ID is required."));
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var admin = await GetAuthenticatedAdminAsync(connection, cancellationToken);
            if (admin is null)
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var reason = request.Reason?.Trim() ?? "";

            var updated = await connection.ExecuteAsync(new CommandDefinition(
                "UPDATE maintenance_mode SET is_active = @isActive, reason = @reason, updated_at = UTC_TIMESTAMP() WHERE canteen_id = @canteenId;",
                new { isActive = request.IsActive, reason, canteenId = request.CanteenId },
                cancellationToken: cancellationToken));

            if (updated == 0)
            {
                await connection.ExecuteAsync(new CommandDefinition(
                    "INSERT IGNORE INTO maintenance_mode (canteen_id, is_active, reason, started_at) VALUES (@canteenId, @isActive, @reason, UTC_TIMESTAMP());",
                    new { canteenId = request.CanteenId, isActive = request.IsActive, reason },
                    cancellationToken: cancellationToken));
            }

            try
            {
                await notificationService.NotifyCanteenMaintenanceAsync(
                    request.CanteenId,
                    request.IsActive,
                    reason,
                    admin.Id,
                    "admin",
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
            logger.LogError(ex, "UpdateAdminCanteenMaintenance failed for canteen {Id}", request.CanteenId);
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error while updating canteen maintenance."));
        }
    }

    private async Task<bool> EnsureAdminAccessAsync(System.Data.IDbConnection connection, CancellationToken cancellationToken)
    {
        var admin = await GetAuthenticatedAdminAsync(connection, cancellationToken);
        return admin is not null;
    }

    private async Task<AdminUserRow?> GetAuthenticatedAdminAsync(System.Data.IDbConnection connection, CancellationToken cancellationToken)
    {
        if (User?.Identity?.IsAuthenticated != true)
        {
            return null;
        }

        var role = User.FindFirst(ClaimTypes.Role)?.Value
            ?? User.FindFirst("role")?.Value
            ?? string.Empty;

        if (!string.Equals(role, "admin", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var email = User.FindFirst(JwtRegisteredClaimNames.Email)?.Value
            ?? User.FindFirst(ClaimTypes.Email)?.Value
            ?? User.FindFirst("email")?.Value
            ?? string.Empty;

        if (string.IsNullOrWhiteSpace(email))
        {
            return null;
        }

        var admin = await connection.QuerySingleOrDefaultAsync<AdminUserRow>(new CommandDefinition(
            """
            SELECT
                id AS Id,
                COALESCE(name, '') AS Name,
                COALESCE(email, '') AS Email,
                COALESCE(password, '') AS PasswordHash,
                COALESCE(created_at, UTC_TIMESTAMP()) AS CreatedAt
            FROM admin_users
            WHERE LOWER(email) = LOWER(@email)
            LIMIT 1;
            """,
            new { email = email.Trim() },
            cancellationToken: cancellationToken));

        return admin;
    }

    private static async Task EnsureRequiredSettingsAsync(System.Data.IDbConnection connection, CancellationToken cancellationToken)
    {
        foreach (var setting in RequiredSettings)
        {
            await connection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO system_settings (setting_key, setting_value, description, updated_at)
                VALUES (@key, @value, @description, UTC_TIMESTAMP())
                ON DUPLICATE KEY UPDATE
                    description = COALESCE(NULLIF(description, ''), VALUES(description));
                """,
                new
                {
                    key = setting.Key,
                    value = setting.DefaultValue,
                    description = setting.Description
                },
                cancellationToken: cancellationToken));

            await SyncSettingToLegacyTableAsync(
                connection,
                setting.Key,
                setting.DefaultValue,
                setting.Description,
                cancellationToken);
        }
    }

    private static async Task<bool> HasLegacySystemSettingsTableAsync(System.Data.IDbConnection connection, CancellationToken cancellationToken)
    {
        var count = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            "SELECT COUNT(1) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'system_settings';",
            cancellationToken: cancellationToken));

        return count > 0;
    }

    private static async Task SyncSettingToLegacyTableAsync(
        System.Data.IDbConnection connection,
        string settingKey,
        string settingValue,
        string description,
        CancellationToken cancellationToken)
    {
        if (!await HasLegacySystemSettingsTableAsync(connection, cancellationToken))
        {
            return;
        }

        async Task UpsertOneAsync(string key, string value, string desc)
        {
            await connection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO system_settings (setting_key, setting_value, description, updated_at)
                VALUES (@settingKey, @settingValue, @description, UTC_TIMESTAMP())
                ON DUPLICATE KEY UPDATE
                    setting_value = VALUES(setting_value),
                    description = COALESCE(NULLIF(VALUES(description), ''), description),
                    updated_at = UTC_TIMESTAMP();
                """,
                new
                {
                    settingKey = key,
                    settingValue = value,
                    description = desc
                },
                cancellationToken: cancellationToken));
        }

        await UpsertOneAsync(settingKey, settingValue, description);

        if (string.Equals(settingKey, "app_name", StringComparison.OrdinalIgnoreCase))
        {
            await UpsertOneAsync("cafe_name", settingValue, "Legacy cafe name");
        }
    }

    private static string? ValidateSettingValue(string key, string value)
    {
        if (key is "app_name")
        {
            return string.IsNullOrWhiteSpace(value)
                ? "Application name cannot be empty."
                : null;
        }

        if (key is "tax_percentage" or "delivery_charge" or "min_order_delivery")
        {
            if (!decimal.TryParse(value, out var numericValue) || numericValue < 0)
            {
                return "Numeric setting values must be valid positive numbers.";
            }
        }

        if (key is "operating_hours_open" or "operating_hours_close")
        {
            if (!TimeSpan.TryParse(value, out _))
            {
                return "Operating hours must use HH:mm format.";
            }
        }

        return null;
    }

    private static object MapUser(UserRow user) => new
    {
        id = user.Id,
        firstName = user.FirstName,
        lastName = user.LastName,
        fullName = BuildName(user.FirstName, user.LastName),
        email = user.Email,
        contact = user.Contact,
        department = user.Department,
        role = user.Role,
        canteenId = user.CanteenId,
        status = user.Status,
        totalOrders = user.TotalOrders,
        totalSpent = Math.Round(user.TotalSpent, 2),
        joinedAt = user.CreatedAt
    };

    private static string? ValidateUserRequest(UserUpsertRequest request, bool requirePassword)
    {
        if (string.IsNullOrWhiteSpace(request.FirstName)) return "First name is required.";
        if (string.IsNullOrWhiteSpace(request.LastName)) return "Last name is required.";
        if (string.IsNullOrWhiteSpace(request.Email)) return "Email is required.";
        if (requirePassword && string.IsNullOrWhiteSpace(request.Password)) return "Password is required.";
        if (!string.IsNullOrWhiteSpace(request.Password) && request.Password.Trim().Length < 6) return "Password must be at least 6 characters.";
        return null;
    }

    private static string? ValidateCanteenAdminRequest(CanteenAdminUpsertRequest request, bool requirePassword)
    {
        if (request.CanteenId <= 0) return "Valid canteen is required.";
        if (string.IsNullOrWhiteSpace(request.Name)) return "Name is required.";
        if (string.IsNullOrWhiteSpace(request.Username)) return "Username is required.";
        if (requirePassword && string.IsNullOrWhiteSpace(request.Password)) return "Password is required.";
        if (!string.IsNullOrWhiteSpace(request.Password) && request.Password.Trim().Length < 6) return "Password must be at least 6 characters.";
        return null;
    }

    private static string NormalizeRole(string? role)
    {
        var normalized = (role ?? string.Empty).Trim().ToLowerInvariant();
        return normalized switch
        {
            "admin" => "admin",
            "staff" => "staff",
            "canteen_admin" => "canteen_admin",
            _ => "student"
        };
    }

    private static string NormalizeStatus(string? status)
    {
        var normalized = (status ?? string.Empty).Trim().ToLowerInvariant();
        return normalized switch
        {
            "inactive" => "inactive",
            "banned" => "banned",
            _ => "active"
        };
    }

    private static string BuildName(string? firstName, string? lastName)
    {
        var value = $"{firstName} {lastName}".Trim();
        return string.IsNullOrWhiteSpace(value) ? "Unknown" : value;
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

        if (Uri.TryCreate(raw, UriKind.Absolute, out var absoluteUri)
            && (absoluteUri.Scheme.Equals("http", StringComparison.OrdinalIgnoreCase)
                || absoluteUri.Scheme.Equals("https", StringComparison.OrdinalIgnoreCase)))
        {
            if (absoluteUri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase)
                || absoluteUri.Host.Equals("127.0.0.1", StringComparison.OrdinalIgnoreCase)
                || absoluteUri.Host.Equals("::1", StringComparison.OrdinalIgnoreCase))
            {
                var remappedPath = absoluteUri.AbsolutePath.TrimStart('/');
                if (!string.IsNullOrWhiteSpace(remappedPath))
                {
                    return $"{Request.Scheme}://{Request.Host}/{remappedPath}";
                }
            }

            return raw;
        }

        var normalized = raw.TrimStart('/');
        return $"{Request.Scheme}://{Request.Host}/{normalized}";
    }

    private static object Success(string message, object? data = null) => new
    {
        success = true,
        message,
        data
    };

    private static object Failure(string message) => new
    {
        success = false,
        message
    };

    private sealed class DashboardStats
    {
        public int TotalOrders { get; init; }
        public int PendingOrders { get; init; }
        public int TodayOrders { get; init; }
        public decimal TotalRevenue { get; init; }
        public int TotalUsers { get; init; }
        public int ActiveCanteens { get; init; }
        public int UnreadMessages { get; init; }
        public int TotalReviews { get; init; }
        public int CompletedOrders { get; init; }
        public int CancelledOrders { get; init; }
    }

    private sealed class UserRow
    {
        public int Id { get; init; }
        public string FirstName { get; init; } = string.Empty;
        public string LastName { get; init; } = string.Empty;
        public string Email { get; init; } = string.Empty;
        public string Contact { get; init; } = string.Empty;
        public string Department { get; init; } = string.Empty;
        public string Role { get; init; } = string.Empty;
        public int? CanteenId { get; init; }
        public string Status { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
        public int TotalOrders { get; init; }
        public decimal TotalSpent { get; init; }
    }

    private sealed class CanteenRow
    {
        public int Id { get; init; }
        public string Name { get; init; } = string.Empty;
        public string Description { get; init; } = string.Empty;
        public string ImageUrl { get; init; } = string.Empty;
        public string Status { get; init; } = string.Empty;
        public int DisplayOrder { get; init; }
        public DateTime CreatedAt { get; init; }
        public int AdminCount { get; init; }
    }

    private sealed class CanteenAdminRow
    {
        public int Id { get; init; }
        public int CanteenId { get; init; }
        public string CanteenName { get; init; } = string.Empty;
        public string Username { get; init; } = string.Empty;
        public string Name { get; init; } = string.Empty;
        public string Email { get; init; } = string.Empty;
        public string Contact { get; init; } = string.Empty;
        public string ImageUrl { get; init; } = string.Empty;
        public string Status { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
    }

    private sealed class ContactMessageRow
    {
        public int Id { get; init; }
        public string Name { get; init; } = string.Empty;
        public string Email { get; init; } = string.Empty;
        public string Subject { get; init; } = string.Empty;
        public string Message { get; init; } = string.Empty;
        public string Status { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
        public DateTime? RepliedAt { get; init; }
        public string ReplyMessage { get; init; } = string.Empty;
    }

    private sealed class ReviewRow
    {
        public int Id { get; init; }
        public int UserId { get; init; }
        public string UserFirstName { get; init; } = string.Empty;
        public string UserLastName { get; init; } = string.Empty;
        public string UserEmail { get; init; } = string.Empty;
        public int CanteenId { get; init; }
        public string CanteenName { get; init; } = string.Empty;
        public int Rating { get; init; }
        public string ReviewText { get; init; } = string.Empty;
        public string AdminResponse { get; init; } = string.Empty;
        public string Status { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
    }

    private sealed class SystemSettingRow
    {
        public int Id { get; init; }
        public string SettingKey { get; init; } = string.Empty;
        public string SettingValue { get; init; } = string.Empty;
        public string Description { get; init; } = string.Empty;
        public DateTime UpdatedAt { get; init; }
    }

    private sealed class AdminUserRow
    {
        public int Id { get; init; }
        public string Name { get; init; } = string.Empty;
        public string Email { get; init; } = string.Empty;
        public string PasswordHash { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
    }

    private sealed class AdminSystemMaintenanceRow
    {
        public bool IsActive { get; init; }
        public string Message { get; init; } = string.Empty;
    }

    private sealed class AdminCanteenMaintenanceRow
    {
        public int CanteenId { get; init; }
        public string CanteenName { get; init; } = string.Empty;
        public bool IsActive { get; init; }
        public string Reason { get; init; } = string.Empty;
    }

    public sealed class UserUpsertRequest
    {
        public string? UniversityId { get; init; }
        public string? FirstName { get; init; }
        public string? LastName { get; init; }
        public string? Email { get; init; }
        public string? Contact { get; init; }
        public string? Department { get; init; }
        public string? Password { get; init; }
        public string? Role { get; init; }
        public int? CanteenId { get; init; }
        public string? Status { get; init; }
    }

    public sealed class CanteenUpsertRequest
    {
        public string? Name { get; init; }
        public string? Description { get; init; }
        public string? ImageUrl { get; init; }
        public bool IsActive { get; init; } = true;
        public int DisplayOrder { get; init; }
    }

    public sealed class CanteenAdminUpsertRequest
    {
        public int CanteenId { get; init; }
        public string? Username { get; init; }
        public string? Password { get; init; }
        public string? Name { get; init; }
        public string? Email { get; init; }
        public string? Contact { get; init; }
        public string? ImageUrl { get; init; }
        public string? Status { get; init; }
    }

    public sealed class MessageStatusRequest
    {
        public string? Status { get; init; }
    }

    public sealed class ReviewStatusRequest
    {
        public string? Status { get; init; }
    }

    public sealed class AdminSystemMaintenanceRequest
    {
        public bool IsActive { get; init; }
        public string? Reason { get; init; }
    }

    public sealed class AdminCanteenMaintenanceRequest
    {
        public int CanteenId { get; init; }
        public bool IsActive { get; init; }
        public string? Reason { get; init; }
    }

    public sealed class SystemSettingRequest
    {
        public string? SettingKey { get; init; }
        public string? SettingValue { get; init; }
        public string? Description { get; init; }
    }

    public sealed class AdminProfileUpdateRequest
    {
        public string? Name { get; init; }
        public string? Email { get; init; }
    }

    public sealed class AdminPasswordChangeRequest
    {
        public string? CurrentPassword { get; init; }
        public string? NewPassword { get; init; }
        public string? ConfirmPassword { get; init; }
    }

    [HttpGet("check-canteens")]
    public async Task<IActionResult> CheckCanteens(CancellationToken cancellationToken = default)
    {
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            if (!await EnsureAdminAccessAsync(connection, cancellationToken))
            {
                return StatusCode(StatusCodes.Status403Forbidden, Failure("Admin access required."));
            }

            var canteens = await connection.QueryAsync<dynamic>(
                "SELECT id, name, status FROM canteens WHERE status = 'active' ORDER BY id;");

            var menuStats = await connection.QueryAsync<dynamic>(
                "SELECT COUNT(*) as total, SUM(CASE WHEN is_deleted = 0 THEN 1 ELSE 0 END) as active, SUM(CASE WHEN is_deleted = 1 THEN 1 ELSE 0 END) as deleted FROM menu_items;");

            var itemsByCanteen = await connection.QueryAsync<dynamic>(
                """
                SELECT
                  c.id,
                  c.name,
                  SUM(CASE WHEN COALESCE(m.is_deleted,0)=0 THEN 1 ELSE 0 END) as active_items,
                  SUM(CASE WHEN COALESCE(m.is_deleted,0)=1 THEN 1 ELSE 0 END) as deleted_items
                FROM canteens c
                LEFT JOIN menu_items m ON m.canteen_id = c.id
                WHERE c.status = 'active'
                GROUP BY c.id, c.name
                ORDER BY c.id;
                """);

            return Ok(Success("Canteen and menu information.", new
            {
                canteens = canteens.ToList(),
                menuItemStats = menuStats.FirstOrDefault(),
                itemsByCanteen = itemsByCanteen.ToList()
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Check canteens failed.");
            return StatusCode(StatusCodes.Status500InternalServerError, Failure("Internal server error."));
        }
    }

    [HttpPost("reorganize-food-items")]
    public async Task<IActionResult> ReorganizeFoodItems()
    {
        using var connection = dbConnectionFactory.CreateConnection();
        await connection.ExecuteAsync("DELETE FROM menu_items;");
        var n = 0;
        var errors = new List<string>();
        var items = new[]{("Caesar Salad","Fresh crisp romaine lettuce with parmesan and Caesar dressing",150m, 3, 1),("Continental Breakfast","Eggs, toast, bacon, and fresh juice",200m, 3, 1),("Fish & Chips","Crispy battered fish with golden fries",220m, 3, 1),("Gulab Jamun","Sweet milk solids soaked in sugar syrup",80m, 5, 1),("Iced Latte","Cold espresso with steamed milk and ice",120m, 4, 1),("Margherita Pizza","Classic pizza with mozzarella, tomato, and basil",250m, 2, 1),("Mushroom Stroganoff","Creamy mushroom sauce with tender pasta",280m, 3, 3),("Nachos Supreme","Crispy nachos with cheese, jalapeños, and sour cream",200m, 3, 3),("New York Cheesecake","Classic creamy cheesecake with graham cracker crust",150m, 5, 3),("Pancakes Stack","Fluffy pancakes with butter and maple syrup",180m, 3, 3),("Paneer Tikka Masala","Soft paneer in creamy tomato sauce",240m, 3, 3),("Pasta Alfredo","Creamy Alfredo sauce with fresh parmesan",220m, 3, 3),("Penne Arrabiata","Spicy tomato and garlic pasta",210m, 3, 3),("Pepperoni Pizza","Pizza with pepperoni and mozzarella cheese",260m, 2, 2),("Restaurants","Our partner restaurants menu",0m, 3, 2),("Scrambled Eggs","Fluffy scrambled eggs with toast",120m, 3, 2),("Spring Rolls","Crispy vegetable spring rolls with dipping sauce",100m, 3, 2),("Tropical Smoothie","Fresh mango and pineapple smoothie",110m, 4, 2),("Vegetable Biryani","Aromatic basmati rice with mixed vegetables",180m, 3, 2),("Virgin Mojito","Refreshing mint and lime mocktail",100m, 4, 2)};
        foreach(var item in items) {
            try {
                var result = await connection.ExecuteAsync("INSERT INTO menu_items (category_id, canteen_id, name, description, price, is_available, is_vegetarian, created_at, updated_at) VALUES (@c, @cn, @n, @d, @p, 1, 1, NOW(), NOW());", new{c = item.Item4, cn = item.Item5, n = item.Item1, d = item.Item2, p = item.Item3});
                if (result > 0) n++;
            } catch (Exception ex) {
                errors.Add($"{item.Item1}: {ex.Message}");
            }
        }
        var total = await connection.QuerySingleAsync<int>("SELECT COUNT(*) FROM menu_items;");
        return Ok(Success("Food reorganized", new{inserted = n, total = total, errors = errors}));
    }

    [HttpGet("deploy-test")]
    public IActionResult DeployTest() => Ok(new { status = "deployed_v2" });

    [HttpPost("update-food-images")]
    public async Task<IActionResult> UpdateFoodImages()
    {
        using var connection = dbConnectionFactory.CreateConnection();
        var updates = new(int id, string img)[]
        {
            (1, "/uploads/menu_items/Caesar_Salad.jpg"),
            (2, "/uploads/menu_items/Continental _Breakfast.jpg"),
            (3, "/uploads/menu_items/Fish_&_Chips.jpg"),
            (4, "/uploads/menu_items/Gulab_Jamun.jpg"),
            (5, "/uploads/menu_items/Iced_Latte.jpg"),
            (6, "/uploads/menu_items/Margherita_Pizza.jpg"),
            (7, "/uploads/menu_items/Mushroom_Stroganoff.jpg"),
            (8, "/uploads/menu_items/Nachos_Supreme.jpg"),
            (9, "/uploads/menu_items/New_York_Cheesecake.jpg"),
            (10, "/uploads/menu_items/Pancakes_Stack.jpg"),
            (11, "/uploads/menu_items/Paneer_Tikka_Masala.jpg"),
            (12, "/uploads/menu_items/Pasta_Alfredo.jpg"),
            (13, "/uploads/menu_items/Penne_Arrabiata.jpg"),
            (14, "/uploads/menu_items/Pepperoni_Pizza.jpg"),
            (15, "/uploads/menu_items/Restaurants.jpg"),
            (16, "/uploads/menu_items/Scrambled_Eggs.jpg"),
            (17, "/uploads/menu_items/Spring_Rolls.jpg"),
            (18, "/uploads/menu_items/Tropical_Smoothie.jpg"),
            (19, "/uploads/menu_items/Vegetable_Biryani.jpg"),
            (20, "/uploads/menu_items/Virgin_Mojito.jpg")
        };
        int n = 0;
        foreach(var u in updates) {
            await connection.ExecuteAsync("UPDATE menu_items SET image_url = @img WHERE id = @id", new { id = u.id, img = u.img });
            n++;
        }
        return Ok(new { success = true, updated = n });
    }

    [HttpPost("insert-food-v3")]
    public async Task<IActionResult> InsertFoodV3()
    {
        using var connection = dbConnectionFactory.CreateConnection();
        try {
            await connection.ExecuteAsync("DELETE FROM menu_items");
            var sql = "INSERT INTO menu_items (id, category_id, canteen_id, name, description, price, is_available, is_vegetarian, created_at, updated_at) VALUES (@id, @c, @ca, @n, @d, @p, 1, 1, NOW(), NOW())";
            var items = new(int id, string name, string desc, int cat, int canteen)[]
            {
                (1, "Caesar Salad", "Fresh crisp romaine", 3, 1), (2, "Continental Breakfast", "Eggs, toast, bacon", 3, 1), (3, "Fish & Chips", "Crispy fish", 3, 1),
                (4, "Gulab Jamun", "Sweet milk solids", 5, 1), (5, "Iced Latte", "Cold espresso", 4, 1), (6, "Margherita Pizza", "Classic pizza", 2, 1),
                (7, "Mushroom Stroganoff", "Creamy sauce", 3, 3), (8, "Nachos Supreme", "Crispy nachos", 3, 3), (9, "New York Cheesecake", "Creamy cheesecake", 5, 3),
                (10, "Pancakes Stack", "Fluffy pancakes", 3, 3), (11, "Paneer Tikka Masala", "Soft paneer", 3, 3), (12, "Pasta Alfredo", "Creamy Alfredo", 3, 3),
                (13, "Penne Arrabiata", "Spicy pasta", 3, 3), (14, "Pepperoni Pizza", "Pizza with pepperoni", 2, 2), (15, "Restaurants", "Partner menus", 3, 2),
                (16, "Scrambled Eggs", "Fluffy eggs", 3, 2), (17, "Spring Rolls", "Crispy rolls", 3, 2), (18, "Tropical Smoothie", "Mango pineapple", 4, 2),
                (19, "Vegetable Biryani", "Aromatic rice", 3, 2), (20, "Virgin Mojito", "Mint mocktail", 4, 2)
            };
            int n = 0;
            foreach(var i in items) {
                await connection.ExecuteAsync(sql, new { id = i.id, c = i.cat, ca = i.canteen, n = i.name, d = i.desc, p = 100m });
                n++;
            }
            var total = await connection.QuerySingleAsync<int>("SELECT COUNT(*) FROM menu_items");
            return Ok(new { success = true, inserted = n, total = total });
        } catch (Exception ex) {
            return BadRequest(ex.Message);
        }
    }

    [HttpPost("reset-menu")]
    public async Task<IActionResult> ResetMenu()
    {
        using var connection = dbConnectionFactory.CreateConnection();
        await connection.ExecuteAsync("TRUNCATE TABLE menu_items;");
        var sql = "INSERT INTO menu_items (category_id, canteen_id, name, description, price, is_available, is_vegetarian, created_at, updated_at) VALUES (@c, @cn, @n, @d, @p, 1, 1, NOW(), NOW());";
        int cnt = 0;
        foreach(var item in new[]{("Caesar Salad","Fresh crisp romaine lettuce with parmesan and Caesar dressing",150m, 3, 1),("Continental Breakfast","Eggs, toast, bacon, and fresh juice",200m, 3, 1),("Fish & Chips","Crispy battered fish with golden fries",220m, 3, 1),("Gulab Jamun","Sweet milk solids soaked in sugar syrup",80m, 5, 1),("Iced Latte","Cold espresso with steamed milk and ice",120m, 4, 1),("Margherita Pizza","Classic pizza with mozzarella, tomato, and basil",250m, 2, 1),("Mushroom Stroganoff","Creamy mushroom sauce with tender pasta",280m, 3, 3),("Nachos Supreme","Crispy nachos with cheese, jalapeños, and sour cream",200m, 3, 3),("New York Cheesecake","Classic creamy cheesecake with graham cracker crust",150m, 5, 3),("Pancakes Stack","Fluffy pancakes with butter and maple syrup",180m, 3, 3),("Paneer Tikka Masala","Soft paneer in creamy tomato sauce",240m, 3, 3),("Pasta Alfredo","Creamy Alfredo sauce with fresh parmesan",220m, 3, 3),("Penne Arrabiata","Spicy tomato and garlic pasta",210m, 3, 3),("Pepperoni Pizza","Pizza with pepperoni and mozzarella cheese",260m, 2, 2),("Restaurants","Our partner restaurants menu",0m, 3, 2),("Scrambled Eggs","Fluffy scrambled eggs with toast",120m, 3, 2),("Spring Rolls","Crispy vegetable spring rolls with dipping sauce",100m, 3, 2),("Tropical Smoothie","Fresh mango and pineapple smoothie",110m, 4, 2),("Vegetable Biryani","Aromatic basmati rice with mixed vegetables",180m, 3, 2),("Virgin Mojito","Refreshing mint and lime mocktail",100m, 4, 2)}) {
            try { await connection.ExecuteAsync(sql, new{c = item.Item4, cn = item.Item5, n = item.Item1, d = item.Item2, p = item.Item3}); cnt++; } catch { }
        }
        var total = await connection.QuerySingleAsync<int>("SELECT COUNT(*) FROM menu_items;");
        return Ok(new { success = true, count = cnt, total = total });
    }

    [HttpPost("clear-all-images")]
    public async Task<IActionResult> ClearAllImages()
    {
        using var connection = dbConnectionFactory.CreateConnection();
        await connection.ExecuteAsync("UPDATE menu_items SET image_url = ''");
        return Ok(new { success = true });
    }

}
