using Dapper;
using Microsoft.AspNetCore.Mvc;
using UniversityCanteen.Api.Data;

namespace UniversityCanteen.Api.Controllers;

[ApiController]
[Route("api/maintenance")]
public sealed class MaintenanceController(
    IDbConnectionFactory dbConnectionFactory,
    ILogger<MaintenanceController> logger) : ControllerBase
{
    [HttpGet("status")]
    public async Task<IActionResult> GetStatus(CancellationToken cancellationToken = default)
    {
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var row = await connection.QuerySingleOrDefaultAsync<MaintenanceStatusRow>(new CommandDefinition(
                "SELECT COALESCE(is_active, 0) AS IsActive, COALESCE(message, '') AS Message FROM maintenance WHERE maintenance_type = 'global' AND canteen_id = 0 LIMIT 1;",
                cancellationToken: cancellationToken));

            var isActive = row?.IsActive ?? false;
            var message = string.IsNullOrWhiteSpace(row?.Message)
                ? "System-wide maintenance is active. Please try again later."
                : row!.Message.Trim();

            return Ok(new
            {
                success = true,
                message = "Maintenance status loaded.",
                data = new
                {
                    maintenanceActive = isActive,
                    message
                }
            });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to load maintenance status.");
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                success = false,
                message = "Internal server error while loading maintenance status."
            });
        }
    }

    private sealed class MaintenanceStatusRow
    {
        public bool IsActive { get; init; }
        public string Message { get; init; } = string.Empty;
    }
}
