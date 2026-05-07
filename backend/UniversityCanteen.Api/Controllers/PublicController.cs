using Dapper;
using Microsoft.AspNetCore.Mvc;
using UniversityCanteen.Api.Data;

namespace UniversityCanteen.Api.Controllers;

[ApiController]
[Route("api/public")]
public sealed class PublicController(
    IDbConnectionFactory dbConnectionFactory,
    ILogger<PublicController> logger) : ControllerBase
{
    private static readonly Dictionary<string, string> PublicSettingDefaults = new(StringComparer.OrdinalIgnoreCase)
    {
        ["app_name"] = "CampusEatzz",
        ["logo_url"] = string.Empty,
        ["tax_percentage"] = "5",
        ["delivery_charge"] = "50",
        ["min_order_delivery"] = "200",
        ["operating_hours_open"] = "09:00",
        ["operating_hours_close"] = "22:00"
    };

    [HttpGet("settings")]
    public async Task<IActionResult> GetPublicSettings(CancellationToken cancellationToken = default)
    {
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            var rows = new List<PublicSettingRow>();
            if (await HasTableAsync(connection, "system_settings", cancellationToken))
            {
                rows = (await connection.QueryAsync<PublicSettingRow>(new CommandDefinition(
                    """
                    SELECT
                        CASE
                            WHEN LOWER(COALESCE(setting_key, '')) = 'cafe_name' THEN 'app_name'
                            ELSE LOWER(COALESCE(setting_key, ''))
                        END AS SettingKey,
                        COALESCE(setting_value, '') AS SettingValue
                    FROM system_settings
                    WHERE LOWER(COALESCE(setting_key, '')) IN @keys;
                    """,
                    new
                    {
                        keys = new[]
                        {
                            "cafe_name",
                            "app_name",
                            "logo_url",
                            "tax_percentage",
                            "delivery_charge",
                            "min_order_delivery",
                            "operating_hours_open",
                            "operating_hours_close"
                        }
                    },
                    cancellationToken: cancellationToken))).ToList();
            }
            else
            {
                logger.LogWarning(
                    "Table 'system_settings' was not found in database '{DatabaseName}'. Falling back to defaults.",
                    connection.Database);
            }

            var values = new Dictionary<string, string>(PublicSettingDefaults, StringComparer.OrdinalIgnoreCase);
            foreach (var row in rows)
            {
                values[row.SettingKey] = string.Equals(row.SettingKey, "logo_url", StringComparison.OrdinalIgnoreCase)
                    ? ToAbsoluteImageUrl(row.SettingValue)
                    : row.SettingValue;
            }

            return Ok(new
            {
                success = true,
                message = "Public settings fetched successfully.",
                data = values
            });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch public settings.");
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                success = false,
                message = "Internal server error while fetching app settings."
            });
        }
    }

    [HttpGet("canteens")]
    public async Task<IActionResult> GetCanteens(CancellationToken cancellationToken = default)
    {
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var rows = (await connection.QueryAsync<PublicCanteenRow>(new CommandDefinition(
                """
                SELECT
                    c.id AS Id,
                    COALESCE(c.name, '') AS Name,
                    COALESCE(c.description, '') AS Description,
                    COALESCE(c.image_url, '') AS ImageUrl,
                    COALESCE(c.status, 'active') AS Status,
                    COALESCE(c.display_order, 0) AS DisplayOrder,
                    COALESCE(mm.is_active, 0) AS IsUnderMaintenance
                FROM canteens c
                LEFT JOIN maintenance mm ON mm.maintenance_type = 'canteen' AND mm.canteen_id = c.id
                WHERE COALESCE(c.status, 'active') = 'active'
                ORDER BY c.display_order ASC, c.id ASC;
                """,
                cancellationToken: cancellationToken))).ToList();

            return Ok(new
            {
                success = true,
                message = "Canteens fetched successfully.",
                data = new
                {
                    canteens = rows.Select(r => new
                    {
                        id = r.Id,
                        name = r.Name,
                        description = r.Description,
                        imageUrl = ToAbsoluteImageUrl(r.ImageUrl),
                        status = r.Status,
                        displayOrder = r.DisplayOrder,
                        isUnderMaintenance = r.IsUnderMaintenance
                    }),
                    total = rows.Count
                }
            });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to fetch public canteens.");
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                success = false,
                message = "Internal server error while fetching canteens."
            });
        }
    }

    private string ToAbsoluteImageUrl(string? value)
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
            // If an image was saved from localhost, remap it to the current API host
            // so phones/LAN clients can still load the same uploaded file.
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

    private static async Task<bool> HasTableAsync(System.Data.IDbConnection connection, string tableName, CancellationToken cancellationToken)
    {
        var count = await connection.ExecuteScalarAsync<int>(new CommandDefinition(
            "SELECT COUNT(1) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = @tableName;",
            new { tableName },
            cancellationToken: cancellationToken));

        return count > 0;
    }

    private sealed class PublicCanteenRow
    {
        public int Id { get; init; }
        public string Name { get; init; } = string.Empty;
        public string Description { get; init; } = string.Empty;
        public string ImageUrl { get; init; } = string.Empty;
        public string Status { get; init; } = "active";
        public int DisplayOrder { get; init; }
        public bool IsUnderMaintenance { get; init; }
    }

    private sealed class PublicSettingRow
    {
        public string SettingKey { get; init; } = string.Empty;
        public string SettingValue { get; init; } = string.Empty;
    }
}
