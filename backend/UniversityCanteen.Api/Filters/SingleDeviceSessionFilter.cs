using Dapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using System.IdentityModel.Tokens.Jwt;
using UniversityCanteen.Api.Data;

namespace UniversityCanteen.Api.Filters;

/// <summary>
/// Rejects any authenticated request whose JWT jti does not match the
/// active_session_jti stored in the database for that user.
/// Returns HTTP 403 with error_code SESSION_SUPERSEDED when the session
/// has been replaced by a login on another device.
/// </summary>
public sealed class SingleDeviceSessionFilter(IDbConnectionFactory dbConnectionFactory, ILogger<SingleDeviceSessionFilter> logger) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var httpContext = context.HttpContext;

        // Skip unauthenticated endpoints (no Bearer token present).
        var authHeader = httpContext.Request.Headers.Authorization.FirstOrDefault();
        if (string.IsNullOrWhiteSpace(authHeader) || !authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            await next();
            return;
        }

        var rawToken = authHeader["Bearer ".Length..].Trim();
        if (string.IsNullOrWhiteSpace(rawToken))
        {
            await next();
            return;
        }

        // Read claims without re-validating signature — the JWT middleware already did that.
        var handler = new JwtSecurityTokenHandler();
        if (!handler.CanReadToken(rawToken))
        {
            await next();
            return;
        }

        JwtSecurityToken jwt;
        try
        {
            jwt = handler.ReadJwtToken(rawToken);
        }
        catch
        {
            await next();
            return;
        }

        var jti = jwt.Id;
        var subClaim = jwt.Subject;
        var roleClaim = jwt.Claims.FirstOrDefault(c => c.Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/role")?.Value
                     ?? jwt.Claims.FirstOrDefault(c => c.Type == "role")?.Value
                     ?? string.Empty;

        if (string.IsNullOrWhiteSpace(jti) || string.IsNullOrWhiteSpace(subClaim))
        {
            await next();
            return;
        }

        // Determine which table to check based on role.
        string? storedJti;
        try
        {
            using var connection = dbConnectionFactory.CreateConnection();
            storedJti = roleClaim.Equals("canteen_admin", StringComparison.OrdinalIgnoreCase)
                ? await GetCanteenAdminJtiAsync(connection, subClaim)
                : roleClaim.Equals("admin", StringComparison.OrdinalIgnoreCase)
                    ? await GetPlatformAdminJtiAsync(connection, subClaim)
                    : await GetUserJtiAsync(connection, subClaim);
        }
        catch (Exception ex)
        {
            // DB failure — fail open to avoid locking out all users on transient errors.
            logger.LogWarning(ex, "SingleDeviceSessionFilter: DB lookup failed for sub={Sub}. Allowing request.", subClaim);
            await next();
            return;
        }

        // storedJti == null means the column exists but no session has been written yet
        // (e.g. user logged in before the single-device feature was deployed).
        // Treat as pass-through so existing sessions are not broken.
        if (storedJti is not null && !string.Equals(storedJti, jti, StringComparison.Ordinal))
        {
            logger.LogInformation(
                "Session superseded for sub={Sub}. Token jti={Jti}, stored jti={StoredJti}.",
                subClaim, jti, storedJti);

            context.Result = new ObjectResult(new
            {
                success = false,
                message = "Your session has been terminated because you logged in on another device.",
                error_code = "SESSION_SUPERSEDED"
            })
            {
                StatusCode = StatusCodes.Status403Forbidden
            };
            return;
        }

        await next();
    }

    private static async Task<string?> GetUserJtiAsync(System.Data.IDbConnection connection, string sub)
    {
        return await connection.QuerySingleOrDefaultAsync<string?>(
            "SELECT active_session_jti FROM users WHERE id = @id LIMIT 1;",
            new { id = sub });
    }

    private static async Task<string?> GetCanteenAdminJtiAsync(System.Data.IDbConnection connection, string sub)
    {
        return await connection.QuerySingleOrDefaultAsync<string?>(
            "SELECT active_session_jti FROM canteen_admins WHERE id = @id LIMIT 1;",
            new { id = sub });
    }

    private static async Task<string?> GetPlatformAdminJtiAsync(System.Data.IDbConnection connection, string sub)
    {
        return await connection.QuerySingleOrDefaultAsync<string?>(
            "SELECT active_session_jti FROM admin_users WHERE id = @id LIMIT 1;",
            new { id = sub });
    }
}
