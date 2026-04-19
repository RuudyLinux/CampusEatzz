using Dapper;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using MySqlConnector;
using System.Text;
using UniversityCanteen.Api.Configuration;
using UniversityCanteen.Api.Data;
using UniversityCanteen.Api.Services;

var builder = WebApplication.CreateBuilder(args);

const string defaultLocalPort = "5266";
var requestedPort = Environment.GetEnvironmentVariable("PORT");
var resolvedPort = int.TryParse(requestedPort, out var parsedPort) && parsedPort > 0
    ? parsedPort.ToString()
    : defaultLocalPort;
var bindingUrl = $"http://0.0.0.0:{resolvedPort}";

builder.WebHost.UseUrls(bindingUrl);

builder.Services.AddControllers();
builder.Services.AddOpenApi();
builder.Services.Configure<AuthOptions>(builder.Configuration.GetSection(AuthOptions.SectionName));
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection(JwtOptions.SectionName));
builder.Services.Configure<OtpOptions>(builder.Configuration.GetSection(OtpOptions.SectionName));
builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection(SmtpOptions.SectionName));
builder.Services.Configure<FcmOptions>(builder.Configuration.GetSection(FcmOptions.SectionName));

var jwtOptions = builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>() ?? new JwtOptions();
var jwtSecret = JwtTokenService.ResolveSecret(jwtOptions.Secret);

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidAudience = jwtOptions.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
            ClockSkew = TimeSpan.Zero
        };
    });

builder.Services.AddAuthorization();

builder.Services.AddScoped<IDbConnectionFactory>(_ =>
{
    var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
        ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection is not configured.");
    return new MySqlConnectionFactory(connectionString);
});

builder.Services.AddScoped<IOtpEmailSender, SmtpOtpEmailSender>();
builder.Services.AddScoped<UniversityCanteenDbContext>();
builder.Services.AddSingleton<IJwtTokenService, JwtTokenService>();
builder.Services.AddSingleton<IFcmPushSender, FirebaseFcmPushSender>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddHostedService<NotificationSchedulerHostedService>();

var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? [];
var isDevelopment = builder.Environment.IsDevelopment();
var failOnSchemaInitError = builder.Configuration
    .GetValue<bool?>("Startup:FailOnSchemaInitError") ?? isDevelopment;

builder.Services.AddCors(options =>
{
    options.AddPolicy("HybridAppCors", policy =>
    {
        if (isDevelopment)
        {
            policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
            return;
        }

        var configuredOrigins = allowedOrigins.Length == 0
            ? new[] { "https://appassets.androidplatform.net" }
            : allowedOrigins;

        policy
            .SetIsOriginAllowed(origin => IsOriginAllowed(origin, configuredOrigins))
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

WarnIfLikelyInvalidProductionDatabaseHost(app.Configuration, app.Logger, app.Environment.IsDevelopment());
await EnsureCoreSchemaAsync(app.Services, app.Logger, app.Configuration, failOnSchemaInitError);

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors("HybridAppCors");
app.UseStaticFiles();
app.UseAuthentication();
app.UseAuthorization();

app.Use(async (context, next) =>
{
    var path = context.Request.Path;
    if (!path.StartsWithSegments("/api", StringComparison.OrdinalIgnoreCase)
        || HttpMethods.IsOptions(context.Request.Method)
        || IsMaintenanceBypassPath(path))
    {
        await next();
        return;
    }

    try
    {
        using var scope = context.RequestServices.CreateScope();
        var dbConnectionFactory = scope.ServiceProvider.GetRequiredService<IDbConnectionFactory>();
        using var connection = dbConnectionFactory.CreateConnection();

        var state = await connection.QuerySingleOrDefaultAsync<SystemMaintenanceState>(new CommandDefinition(
            "SELECT COALESCE(is_active, 0) AS IsActive, COALESCE(maintenance_message, '') AS Message FROM website_maintenance WHERE id = 1 LIMIT 1;",
            cancellationToken: context.RequestAborted));

        if (state?.IsActive == true)
        {
            var message = string.IsNullOrWhiteSpace(state.Message)
                ? "System-wide maintenance is active. Please try again later."
                : state.Message;

            context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new
            {
                success = false,
                message,
                maintenance = true
            }, context.RequestAborted);
            return;
        }
    }
    catch (Exception ex)
    {
        app.Logger.LogWarning(ex, "Failed to evaluate maintenance status. Allowing request to continue.");
    }

    await next();
});

app.MapControllers();

app.Lifetime.ApplicationStarted.Register(() =>
{
    var addresses = app.Urls.Count > 0 ? string.Join(", ", app.Urls) : bindingUrl;
    app.Logger.LogInformation("Backend API started successfully. Listening on: {Addresses}", addresses);
});

app.Lifetime.ApplicationStopping.Register(() =>
{
    app.Logger.LogInformation("Backend API is stopping.");
});

try
{
    app.Run();
}
catch (IOException ex) when (ex.Message.Contains("address already in use", StringComparison.OrdinalIgnoreCase))
{
    app.Logger.LogCritical(ex,
        "Address already in use on configured backend port {Port}. Check port usage and ensure only one API instance is running.",
        resolvedPort);
    throw;
}
catch (Exception ex)
{
    app.Logger.LogCritical(ex, "Backend API startup failure. Check network binding and firewall rules for dotnet.");
    throw;
}

static bool IsMaintenanceBypassPath(PathString path)
{
    return path.StartsWithSegments("/api/admin", StringComparison.OrdinalIgnoreCase)
        || path.StartsWithSegments("/api/maintenance/status", StringComparison.OrdinalIgnoreCase)
        || path.StartsWithSegments("/api/health", StringComparison.OrdinalIgnoreCase)
        || path.StartsWithSegments("/api/canteen-admin/login", StringComparison.OrdinalIgnoreCase)
        || path.StartsWithSegments("/api/auth", StringComparison.OrdinalIgnoreCase);
}

static bool IsOriginAllowed(string origin, string[] configuredOrigins)
{
    if (string.IsNullOrWhiteSpace(origin) || configuredOrigins.Length == 0)
    {
        return false;
    }

    if (!Uri.TryCreate(origin, UriKind.Absolute, out var requestOrigin))
    {
        return false;
    }

    foreach (var configured in configuredOrigins)
    {
        var candidate = (configured ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(candidate))
        {
            continue;
        }

        if (string.Equals(origin, candidate, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        if (!candidate.Contains("*", StringComparison.Ordinal))
        {
            continue;
        }

        if (!Uri.TryCreate(candidate.Replace("*.", "placeholder."), UriKind.Absolute, out var patternUri))
        {
            continue;
        }

        if (!string.Equals(requestOrigin.Scheme, patternUri.Scheme, StringComparison.OrdinalIgnoreCase))
        {
            continue;
        }

        var wildcardHost = patternUri.Host.Replace("placeholder.", string.Empty, StringComparison.OrdinalIgnoreCase);
        if (requestOrigin.Host.Equals(wildcardHost, StringComparison.OrdinalIgnoreCase)
            || requestOrigin.Host.EndsWith("." + wildcardHost, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }
    }

    return false;
}

static async Task EnsureCoreSchemaAsync(
    IServiceProvider services,
    ILogger logger,
    IConfiguration configuration,
    bool failOnSchemaInitError)
{
    using var scope = services.CreateScope();
    var dbConnectionFactory = scope.ServiceProvider.GetRequiredService<IDbConnectionFactory>();
    var authOptions = configuration.GetSection(AuthOptions.SectionName).Get<AuthOptions>() ?? new AuthOptions();
    var configuredAdmin = authOptions.Admin;

    var seedAdminName = string.IsNullOrWhiteSpace(configuredAdmin.Name)
        ? "Platform Admin"
        : configuredAdmin.Name.Trim();
    var seedAdminEmail = string.IsNullOrWhiteSpace(configuredAdmin.Email)
        ? "admin@utu.ac.in"
        : configuredAdmin.Email.Trim();
    var seedAdminPassword = string.IsNullOrWhiteSpace(configuredAdmin.Password)
        ? "admin123"
        : configuredAdmin.Password;

    using var connection = dbConnectionFactory.CreateConnection();
    var schemaSql = new[]
    {
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS OtpCode VARCHAR(255) NULL;",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS OtpExpiry DATETIME NULL;",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS IsLoggedIn TINYINT(1) NOT NULL DEFAULT 0;",
        "ALTER TABLE users MODIFY COLUMN OtpCode VARCHAR(255) NULL;",
        "ALTER TABLE canteen_admins ADD COLUMN IF NOT EXISTS image_url VARCHAR(500) NULL;",
        """
        CREATE TABLE IF NOT EXISTS system_settings (
            id INT NOT NULL AUTO_INCREMENT,
            setting_key VARCHAR(100) NOT NULL,
            setting_value TEXT NULL,
            description VARCHAR(255) NULL,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_system_settings_setting_key (setting_key)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """,
        """
        CREATE TABLE IF NOT EXISTS admin_users (
            id INT NOT NULL AUTO_INCREMENT,
            name VARCHAR(100) NOT NULL,
            email VARCHAR(150) NOT NULL,
            password VARCHAR(255) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_admin_users_email (email)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """,
        """
        CREATE TABLE IF NOT EXISTS auth_refresh_tokens (
            id BIGINT NOT NULL AUTO_INCREMENT,
            user_id INT NOT NULL,
            role VARCHAR(50) NOT NULL,
            token_hash VARCHAR(64) NOT NULL,
            expires_at_utc DATETIME NOT NULL,
            created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            revoked_at_utc DATETIME NULL,
            PRIMARY KEY (id),
            UNIQUE KEY uq_auth_refresh_tokens_hash (token_hash),
            KEY ix_auth_refresh_tokens_user_role (user_id, role),
            KEY ix_auth_refresh_tokens_expiry (expires_at_utc)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """,
        """
        CREATE TABLE IF NOT EXISTS user_device_tokens (
            id BIGINT NOT NULL AUTO_INCREMENT,
            user_id INT NOT NULL,
            role VARCHAR(50) NOT NULL,
            token VARCHAR(512) NOT NULL,
            platform VARCHAR(30) NOT NULL DEFAULT 'unknown',
            is_active TINYINT(1) NOT NULL DEFAULT 1,
            created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_seen_utc DATETIME NULL,
            PRIMARY KEY (id),
            UNIQUE KEY uq_user_device_tokens_token (token),
            KEY ix_user_device_tokens_user_role (user_id, role),
            KEY ix_user_device_tokens_active (is_active)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """,
        """
        CREATE TABLE IF NOT EXISTS app_notifications (
            id BIGINT NOT NULL AUTO_INCREMENT,
            notification_type VARCHAR(50) NOT NULL,
            title VARCHAR(255) NOT NULL,
            message TEXT NOT NULL,
            payload_json TEXT NULL,
            target_scope VARCHAR(20) NOT NULL DEFAULT 'all',
            target_user_id INT NULL,
            target_role VARCHAR(50) NULL,
            target_canteen_id INT NULL,
            scheduled_for_utc DATETIME NULL,
            status VARCHAR(20) NOT NULL DEFAULT 'pending',
            created_by_user_id INT NULL,
            created_by_role VARCHAR(50) NULL,
            created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            sent_at_utc DATETIME NULL,
            PRIMARY KEY (id),
            KEY ix_app_notifications_status_schedule (status, scheduled_for_utc),
            KEY ix_app_notifications_created_at (created_at_utc),
            KEY ix_app_notifications_target_user (target_user_id),
            KEY ix_app_notifications_target_canteen (target_canteen_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """,
        """
        CREATE TABLE IF NOT EXISTS app_notification_recipients (
            id BIGINT NOT NULL AUTO_INCREMENT,
            notification_id BIGINT NOT NULL,
            recipient_user_id INT NOT NULL,
            recipient_role VARCHAR(50) NOT NULL,
            delivery_status VARCHAR(20) NOT NULL DEFAULT 'pending',
            delivery_error TEXT NULL,
            delivered_at_utc DATETIME NULL,
            read_at_utc DATETIME NULL,
            created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_notification_recipient (notification_id, recipient_user_id, recipient_role),
            KEY ix_notification_recipient_user (recipient_user_id, recipient_role, read_at_utc),
            KEY ix_notification_recipient_created (created_at_utc),
            CONSTRAINT fk_notification_recipients_notification
                FOREIGN KEY (notification_id) REFERENCES app_notifications(id)
                ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """
    };

    var settingsSeed = new[]
    {
        new { Key = "app_name", Value = "CampusEatzz", Description = "Application display name" },
        new { Key = "logo_url", Value = string.Empty, Description = "Application logo URL" },
        new { Key = "tax_percentage", Value = "5", Description = "Tax percentage for orders" },
        new { Key = "delivery_charge", Value = "50", Description = "Delivery charge amount" },
        new { Key = "min_order_delivery", Value = "200", Description = "Minimum order amount for delivery" },
        new { Key = "operating_hours_open", Value = "09:00", Description = "Opening time" },
        new { Key = "operating_hours_close", Value = "22:00", Description = "Closing time" }
    };

    const int maxAttempts = 8;
    for (var attempt = 1; attempt <= maxAttempts; attempt++)
    {
        try
        {
            foreach (var sql in schemaSql)
            {
                await connection.ExecuteAsync(sql);
            }

            foreach (var setting in settingsSeed)
            {
                await connection.ExecuteAsync(
                    """
                    INSERT INTO system_settings (setting_key, setting_value, description, updated_at)
                    VALUES (@key, @value, @description, UTC_TIMESTAMP())
                    ON DUPLICATE KEY UPDATE
                        description = COALESCE(NULLIF(description, ''), VALUES(description));
                    """,
                    new
                    {
                        key = setting.Key,
                        value = setting.Value,
                        description = setting.Description
                    });
            }

            var adminCount = await connection.ExecuteScalarAsync<int>("SELECT COUNT(1) FROM admin_users;");
            if (adminCount == 0)
            {
                var adminPasswordHash = BCrypt.Net.BCrypt.HashPassword(seedAdminPassword);
                await connection.ExecuteAsync(
                    """
                    INSERT INTO admin_users (name, email, password, created_at)
                    VALUES (@name, @email, @password, UTC_TIMESTAMP());
                    """,
                    new
                    {
                        name = seedAdminName,
                        email = seedAdminEmail,
                        password = adminPasswordHash
                    });
            }

            logger.LogInformation("Verified startup schema for auth/login support tables and columns.");
            return;
        }
        catch (MySqlException ex) when (attempt < maxAttempts)
        {
            logger.LogWarning(
                ex,
                "MySQL unavailable during startup schema verification (attempt {Attempt}/{MaxAttempts}). Retrying in 2 seconds.",
                attempt,
                maxAttempts);
            await Task.Delay(TimeSpan.FromSeconds(2));
        }
        catch (MySqlException ex)
        {
            if (failOnSchemaInitError)
            {
                logger.LogError(
                    ex,
                    "Failed to verify startup schema requirements after retries. Ensure MySQL is running and reachable via ConnectionStrings:DefaultConnection.");
                throw;
            }

            logger.LogWarning(
                ex,
                "Startup schema verification failed after retries, but the API will continue because Startup:FailOnSchemaInitError is disabled.");
            return;
        }
        catch (Exception ex)
        {
            if (failOnSchemaInitError)
            {
                logger.LogError(ex, "Failed to verify startup schema requirements.");
                throw;
            }

            logger.LogWarning(
                ex,
                "Unexpected startup schema verification failure, but the API will continue because Startup:FailOnSchemaInitError is disabled.");
            return;
        }
    }
}

static void WarnIfLikelyInvalidProductionDatabaseHost(IConfiguration configuration, ILogger logger, bool isDevelopment)
{
    if (isDevelopment)
    {
        return;
    }

    var connectionString = configuration.GetConnectionString("DefaultConnection");
    if (string.IsNullOrWhiteSpace(connectionString))
    {
        logger.LogWarning(
            "ConnectionStrings:DefaultConnection is not configured. Configure a cloud MySQL connection in environment variables before using database-backed endpoints.");
        return;
    }

    try
    {
        var connectionStringBuilder = new MySqlConnectionStringBuilder(connectionString);
        var server = (connectionStringBuilder.Server ?? string.Empty).Trim();
        if (IsLocalDatabaseHost(server))
        {
            logger.LogWarning(
                "Detected local MySQL host '{Server}' in a non-development environment. On Render, set ConnectionStrings__DefaultConnection to your managed MySQL host.",
                server);
        }
    }
    catch (Exception ex)
    {
        logger.LogWarning(ex, "Unable to parse ConnectionStrings:DefaultConnection for deployment diagnostics.");
    }
}

static bool IsLocalDatabaseHost(string host)
{
    return string.Equals(host, "localhost", StringComparison.OrdinalIgnoreCase)
        || string.Equals(host, "127.0.0.1", StringComparison.OrdinalIgnoreCase)
        || string.Equals(host, "0.0.0.0", StringComparison.OrdinalIgnoreCase)
        || string.Equals(host, "::1", StringComparison.OrdinalIgnoreCase)
        || string.Equals(host, "host.docker.internal", StringComparison.OrdinalIgnoreCase);
}

file sealed class SystemMaintenanceState
{
    public bool IsActive { get; init; }
    public string Message { get; init; } = string.Empty;
}
