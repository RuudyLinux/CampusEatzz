using Microsoft.AspNetCore.Mvc;
using Dapper;
using UniversityCanteen.Api.Data;

namespace UniversityCanteen.Api.Controllers;

[ApiController]
[Route("api/health")]
public sealed class HealthController(IDbConnectionFactory dbConnectionFactory) : ControllerBase
{
    [HttpGet]
    public IActionResult Get() => Ok(new { success = true, message = "API is running" });

    [HttpGet("db")]
    public async Task<IActionResult> GetDb(CancellationToken cancellationToken)
    {
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            var value = await connection.ExecuteScalarAsync<int>(
                new CommandDefinition("SELECT 1", cancellationToken: cancellationToken));
            return Ok(new { success = value == 1, message = "Database connection successful" });
        }
        catch (Exception ex)
        {
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                success = false,
                message = "Database connection failed",
                detail = ex.Message
            });
        }
    }
}
