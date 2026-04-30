using Dapper;
using Scalar.AspNetCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.ResponseCompression;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.IdentityModel.Tokens;
using MySqlConnector;
using System.IO.Compression;
using System.Net;
using System.Text;
using UniversityCanteen.Api.Configuration;
using UniversityCanteen.Api.Data;
using UniversityCanteen.Api.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddOpenApi();
builder.Services.Configure<AuthOptions>(builder.Configuration.GetSection(AuthOptions.SectionName));
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection(JwtOptions.SectionName));
builder.Services.Configure<OtpOptions>(builder.Configuration.GetSection(OtpOptions.SectionName));
builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection(SmtpOptions.SectionName));
builder.Services.Configure<FcmOptions>(builder.Configuration.GetSection(FcmOptions.SectionName));
builder.Services.Configure<AiOptions>(builder.Configuration.GetSection(AiOptions.SectionName));

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

var resolvedDatabaseConnectionString = ResolveDatabaseConnectionString(
    builder.Configuration,
    builder.Environment.IsDevelopment());

builder.Services.AddScoped<IDbConnectionFactory>(_ =>
{
    return new MySqlConnectionFactory(resolvedDatabaseConnectionString);
});

builder.Services.AddScoped<IOtpEmailSender, SmtpOtpEmailSender>();
builder.Services.AddScoped<UniversityCanteenDbContext>();
builder.Services.AddSingleton<IJwtTokenService, JwtTokenService>();
builder.Services.AddSingleton<IFcmPushSender, FirebaseFcmPushSender>();
builder.Services.AddScoped<INotificationService, NotificationService>();
var notificationSchedulerEnabled = builder.Configuration
    .GetValue<bool?>("Notifications:Scheduler:Enabled") ?? true;
if (notificationSchedulerEnabled)
{
    builder.Services.AddHostedService<NotificationSchedulerHostedService>();
}

// AI + Recommendation services
var aiOptions = builder.Configuration.GetSection(AiOptions.SectionName).Get<AiOptions>() ?? new AiOptions();
builder.Services.AddMemoryCache();
// Resolve the API key — supports both Ai:ApiKey config and standalone ApiKey env var
var resolvedAiApiKey = !string.IsNullOrWhiteSpace(aiOptions.ApiKey)
    ? aiOptions.ApiKey
    : (Environment.GetEnvironmentVariable("ApiKey") ?? string.Empty);
builder.Services.AddHttpClient("OpenRouter", client =>
{
    var baseUrl = string.IsNullOrWhiteSpace(aiOptions.BaseUrl)
        ? "https://openrouter.ai/api/v1/"
        : aiOptions.BaseUrl;
    client.BaseAddress = new Uri(baseUrl);
    if (!string.IsNullOrWhiteSpace(resolvedAiApiKey))
    {
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {resolvedAiApiKey}");
        client.DefaultRequestHeaders.Add("HTTP-Referer", "https://campuseatzz.onrender.com");
        client.DefaultRequestHeaders.Add("X-Title", "CampusEatzz");
    }
    client.Timeout = TimeSpan.FromSeconds(30);
});
builder.Services.AddScoped<IAiChatService, AiChatService>();
builder.Services.AddScoped<IRecommendationService, RecommendationService>();

var failOnSchemaInitError = builder.Configuration
    .GetValue<bool?>("Startup:FailOnSchemaInitError") ?? false;

builder.Services.AddCors();
builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;
    options.Providers.Add<GzipCompressionProvider>();
});
builder.Services.Configure<GzipCompressionProviderOptions>(options =>
{
    options.Level = System.IO.Compression.CompressionLevel.Fastest;
});
builder.Services.AddOutputCache(options =>
{
    options.AddBasePolicy(builder =>
        builder.Expire(TimeSpan.FromSeconds(30)));
    options.AddPolicy("StaticContent", builder =>
        builder.Expire(TimeSpan.FromMinutes(10)));
});
builder.Services.AddSingleton<IMaintenanceStateCache>(new MaintenanceStateCache());

var app = builder.Build();

WarnIfLikelyInvalidProductionDatabaseHost(resolvedDatabaseConnectionString, app.Logger, app.Environment.IsDevelopment());
WarnIfLocalDatabasePasswordLooksMissing(resolvedDatabaseConnectionString, app.Logger, app.Environment.IsDevelopment());
await EnsureCoreSchemaAsync(app.Services, app.Logger, app.Configuration, failOnSchemaInitError);

app.MapOpenApi();
app.MapScalarApiReference();

app.UseResponseCompression();
app.UseCors(policy =>
    policy.AllowAnyOrigin()
          .AllowAnyMethod()
          .AllowAnyHeader());
app.UseStaticFiles(new StaticFileOptions
{
    OnPrepareResponse = ctx =>
    {
        ctx.Context.Response.Headers["Cache-Control"] = "public, max-age=604800";
    }
});
app.UseOutputCache();
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

    var cache = context.RequestServices.GetRequiredService<IMaintenanceStateCache>();
    var state = await cache.GetMaintenanceStateAsync(
        () => GetMaintenanceStateFromDatabaseAsync(context.RequestServices));

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

    await next();
});

app.MapControllers();

app.Lifetime.ApplicationStarted.Register(() =>
{
    var addresses = app.Urls.Count > 0 ? string.Join(", ", app.Urls) : "Kestrel default URLs";
    app.Logger.LogInformation("Backend API started successfully. Listening on: {Addresses}", addresses);
});

app.Lifetime.ApplicationStopping.Register(() =>
{
    app.Logger.LogInformation("Backend API is stopping.");
});

app.MapGet("/", () => "CampusEatzz API is running 🚀");

try
{
    app.Run();
}
catch (IOException ex) when (ex.Message.Contains("address already in use", StringComparison.OrdinalIgnoreCase))
{
    app.Logger.LogCritical(ex,
        "Address already in use on the configured backend listener. Check port usage and ensure only one API instance is running.");
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

    // Drop system_settings if it exists without AUTO_INCREMENT on id (broken legacy schema).
    // All rows are re-seeded below, so dropping is safe.
    var settingsHasAutoInc = await connection.ExecuteScalarAsync<int>(
        """
        SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME   = 'system_settings'
          AND COLUMN_NAME  = 'id'
          AND EXTRA LIKE '%auto_increment%'
        """) > 0;
    if (!settingsHasAutoInc)
    {
        var settingsExists = await connection.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='system_settings'") > 0;
        if (settingsExists)
            await connection.ExecuteAsync("DROP TABLE system_settings;");
    }

    var schemaSql = new[]
    {
        "ALTER TABLE users ADD COLUMN OtpCode VARCHAR(255) NULL;",
        "ALTER TABLE users ADD COLUMN OtpExpiry DATETIME NULL;",
        "ALTER TABLE users ADD COLUMN IsLoggedIn TINYINT(1) NOT NULL DEFAULT 0;",
        "ALTER TABLE users MODIFY COLUMN OtpCode VARCHAR(255) NULL;",
        "ALTER TABLE canteen_admins ADD COLUMN image_url VARCHAR(500) NULL;",
        "ALTER TABLE menu_items ADD COLUMN is_vegetarian TINYINT(1) NOT NULL DEFAULT 0;",
        "ALTER TABLE menu_items ADD COLUMN spice_level VARCHAR(20) NULL;",
        "ALTER TABLE menu_items ADD COLUMN preparation_time INT NOT NULL DEFAULT 0;",
        "ALTER TABLE menu_items ADD COLUMN display_order INT NOT NULL DEFAULT 0;",
        "ALTER TABLE menu_items ADD COLUMN description TEXT NULL;",
        // Ensure id has AUTO_INCREMENT (may be missing if DB was not seeded from full SQL file)
        "ALTER TABLE menu_items ADD PRIMARY KEY (id);",
        "ALTER TABLE menu_items MODIFY id INT NOT NULL AUTO_INCREMENT;",
        // Ensure all core tables have PRIMARY KEY + AUTO_INCREMENT on id
        "ALTER TABLE orders ADD PRIMARY KEY (id);",
        "ALTER TABLE orders MODIFY id INT NOT NULL AUTO_INCREMENT;",
        "ALTER TABLE order_items ADD PRIMARY KEY (id);",
        "ALTER TABLE order_items MODIFY id INT NOT NULL AUTO_INCREMENT;",
        "ALTER TABLE users ADD PRIMARY KEY (id);",
        "ALTER TABLE users MODIFY id INT NOT NULL AUTO_INCREMENT;",
        "ALTER TABLE canteens ADD PRIMARY KEY (id);",
        "ALTER TABLE canteens MODIFY id INT NOT NULL AUTO_INCREMENT;",
        "ALTER TABLE canteen_admins ADD PRIMARY KEY (id);",
        "ALTER TABLE canteen_admins MODIFY id INT NOT NULL AUTO_INCREMENT;",
        "ALTER TABLE admin_users ADD PRIMARY KEY (id);",
        "ALTER TABLE admin_users MODIFY id INT NOT NULL AUTO_INCREMENT;",
        "ALTER TABLE reviews ADD PRIMARY KEY (id);",
        "ALTER TABLE reviews MODIFY id INT NOT NULL AUTO_INCREMENT;",
        "ALTER TABLE contact_messages ADD PRIMARY KEY (id);",
        "ALTER TABLE contact_messages MODIFY id INT NOT NULL AUTO_INCREMENT;",
        "ALTER TABLE menu_categories ADD PRIMARY KEY (id);",
        "ALTER TABLE menu_categories MODIFY id INT NOT NULL AUTO_INCREMENT;",
        "ALTER TABLE order_status_history ADD PRIMARY KEY (id);",
        "ALTER TABLE order_status_history MODIFY id INT NOT NULL AUTO_INCREMENT;",
        "ALTER TABLE user_device_tokens ADD PRIMARY KEY (id);",
        "ALTER TABLE user_device_tokens MODIFY id INT NOT NULL AUTO_INCREMENT;",
        "ALTER TABLE app_notifications ADD PRIMARY KEY (id);",
        "ALTER TABLE app_notifications MODIFY id INT NOT NULL AUTO_INCREMENT;",
        "ALTER TABLE app_notification_recipients ADD PRIMARY KEY (id);",
        "ALTER TABLE app_notification_recipients MODIFY id INT NOT NULL AUTO_INCREMENT;",
        "ALTER TABLE auth_refresh_tokens ADD PRIMARY KEY (id);",
        "ALTER TABLE auth_refresh_tokens MODIFY id BIGINT NOT NULL AUTO_INCREMENT;",
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
        """,
        """
        CREATE TABLE IF NOT EXISTS wallets (
            id INT NOT NULL AUTO_INCREMENT,
            user_id INT NOT NULL,
            balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_wallets_user_id (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """,
        """
        CREATE TABLE IF NOT EXISTS wallet_transactions (
            id BIGINT NOT NULL AUTO_INCREMENT,
            user_id INT NOT NULL,
            transaction_id VARCHAR(100) NOT NULL,
            amount DECIMAL(10,2) NOT NULL,
            type ENUM('credit','debit') NOT NULL,
            status ENUM('pending','completed','failed','refunded') NOT NULL DEFAULT 'pending',
            payment_gateway VARCHAR(50) NULL,
            gateway_order_id VARCHAR(100) NULL,
            gateway_payment_id VARCHAR(100) NULL,
            gateway_signature VARCHAR(255) NULL,
            description TEXT NULL,
            order_id INT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_wallet_transactions_txn_id (transaction_id),
            KEY ix_wallet_transactions_user (user_id),
            KEY ix_wallet_transactions_created (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """,
        """
        CREATE TABLE IF NOT EXISTS website_maintenance (
            id INT NOT NULL AUTO_INCREMENT,
            is_active TINYINT(1) NOT NULL DEFAULT 0,
            maintenance_message TEXT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """,
        """
        CREATE TABLE IF NOT EXISTS chatbot_conversations (
            id VARCHAR(100) NOT NULL,
            user_id INT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY ix_chatbot_conversations_user (user_id),
            KEY ix_chatbot_conversations_updated (updated_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        """,
        """
        CREATE TABLE IF NOT EXISTS refund_requests (
            id INT NOT NULL AUTO_INCREMENT,
            order_id INT NOT NULL,
            user_id INT NOT NULL,
            amount DECIMAL(10,2) NOT NULL,
            reason VARCHAR(500) NOT NULL,
            status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
            admin_notes TEXT NULL,
            processed_at TIMESTAMP NULL DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_refund_requests_order (order_id),
            KEY ix_refund_requests_user (user_id),
            KEY ix_refund_requests_status (status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """,
        """
        CREATE TABLE IF NOT EXISTS chatbot_messages (
            id BIGINT NOT NULL AUTO_INCREMENT,
            conversation_id VARCHAR(100) NOT NULL,
            role ENUM('user', 'assistant') NOT NULL,
            content TEXT NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY ix_chatbot_messages_conversation (conversation_id),
            CONSTRAINT fk_chatbot_messages_conversation
                FOREIGN KEY (conversation_id) REFERENCES chatbot_conversations(id)
                ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
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
                try { await connection.ExecuteAsync(sql); }
                catch (MySqlException ex) when (
                    ex.Number == 1060   // Duplicate column name
                    || ex.Number == 1061 // Duplicate key name
                    || ex.Number == 1062 // Duplicate entry for PRIMARY KEY
                    || ex.Number == 1068 // Multiple primary key defined
                    || ex.Number == 1091 // Can't DROP, check that column/key exists
                ) { } // already applied — skip
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

            var adminPasswordHash = BCrypt.Net.BCrypt.HashPassword(seedAdminPassword);

            // Create configured admin user
            var adminHash = BCrypt.Net.BCrypt.HashPassword(seedAdminPassword);
            try
            {
                // Check if admin exists, insert if not
                var count = await connection.ExecuteScalarAsync<int>(
                    "SELECT COUNT(*) FROM admin_users WHERE email = @email;",
                    new { email = seedAdminEmail });

                if (count == 0)
                {
                    await connection.ExecuteAsync(
                        "INSERT INTO admin_users (name, email, password, created_at) VALUES (@name, @email, @password, NOW());",
                        new { name = seedAdminName, email = seedAdminEmail, password = adminHash });
                    logger.LogInformation("Admin created: {Email}", seedAdminEmail);
                }
                else
                {
                    await connection.ExecuteAsync(
                        "UPDATE admin_users SET password = @password, name = @name WHERE email = @email;",
                        new { name = seedAdminName, email = seedAdminEmail, password = adminHash });
                    logger.LogInformation("Admin updated: {Email}", seedAdminEmail);
                }
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Admin sync failed: {Message}", ex.Message);
            }

            var maintenanceCount = await connection.ExecuteScalarAsync<int>("SELECT COUNT(1) FROM website_maintenance;");
            if (maintenanceCount == 0)
            {
                await connection.ExecuteAsync(
                    """
                    INSERT INTO website_maintenance (id, is_active, maintenance_message, created_at, updated_at)
                    VALUES (1, 0, NULL, UTC_TIMESTAMP(), UTC_TIMESTAMP());
                    """);
            }

            logger.LogInformation("Startup schema verification complete. Admin user auto-seeded if first deployment.");
            return;
        }
        catch (MySqlException ex) when (attempt < maxAttempts && ex.Number != 1045)
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

            if (ex.Number == 1045)
            {
                logger.LogWarning(
                    ex,
                    "Startup schema verification failed due to invalid MySQL credentials. Update ConnectionStrings:DefaultConnection or cloud DB environment variables, then restart.");
                return;
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

static string ResolveDatabaseConnectionString(IConfiguration configuration, bool isDevelopment)
{
    var environmentConnectionString = ResolveConnectionStringFromEnvironment(isDevelopment);
    if (!string.IsNullOrWhiteSpace(environmentConnectionString))
    {
        return environmentConnectionString;
    }

    var configuredConnectionString = configuration.GetConnectionString("DefaultConnection");
    var hasConfiguredConnection = !string.IsNullOrWhiteSpace(configuredConnectionString);

    if (hasConfiguredConnection)
    {
        return ApplyMissingConnectionStringPartsFromEnvironment(configuredConnectionString!, isDevelopment);
    }

    throw new InvalidOperationException(
        "ConnectionStrings:DefaultConnection is not configured and no supported MySQL environment variables were found.");
}

static string ApplyMissingConnectionStringPartsFromEnvironment(string connectionString, bool isDevelopment)
{
    try
    {
        var builder = new MySqlConnectionStringBuilder(connectionString);
        var hasChanges = false;

        var host = GetFirstEnvironmentValue(
            "MYSQL_PUBLIC_HOST",
            "MYSQLHOST",
            "DB_HOST",
            "DATABASE_HOST");
        var database = GetFirstEnvironmentValue("MYSQLDATABASE", "DB_NAME", "DATABASE_NAME");
        var user = GetFirstEnvironmentValue("MYSQLUSER", "DB_USER", "DATABASE_USER");
        var password = GetFirstEnvironmentValue(
            "MYSQL_LOCAL_PASSWORD",
            "MYSQL_ROOT_PASSWORD",
            "MYSQLPASSWORD",
            "DB_PASSWORD",
            "DATABASE_PASSWORD");
        var portText = GetFirstEnvironmentValue(
            "MYSQL_PUBLIC_PORT",
            "MYSQLPORT",
            "DB_PORT",
            "DATABASE_PORT");
        var sslModeText = GetFirstEnvironmentValue("MYSQL_SSLMODE", "MYSQL_SSL_MODE", "DB_SSLMODE", "SSLMODE");

        if (string.IsNullOrWhiteSpace(builder.Server) && !string.IsNullOrWhiteSpace(host))
        {
            builder.Server = host.Trim();
            hasChanges = true;
        }

        if (string.IsNullOrWhiteSpace(builder.Database) && !string.IsNullOrWhiteSpace(database))
        {
            builder.Database = database.Trim();
            hasChanges = true;
        }

        if (string.IsNullOrWhiteSpace(builder.UserID) && !string.IsNullOrWhiteSpace(user))
        {
            builder.UserID = user.Trim();
            hasChanges = true;
        }

        if (string.IsNullOrWhiteSpace(builder.Password) && !string.IsNullOrWhiteSpace(password))
        {
            builder.Password = password;
            hasChanges = true;
        }

        if ((builder.Port == 0 || builder.Port == 3306)
            && uint.TryParse(portText, out var parsedPort)
            && parsedPort > 0)
        {
            builder.Port = parsedPort;
            hasChanges = true;
        }

        if (!string.IsNullOrWhiteSpace(sslModeText))
        {
            builder.SslMode = ResolveSslMode(sslModeText, builder.Server, isDevelopment);
            hasChanges = true;
        }

        return hasChanges ? builder.ConnectionString : connectionString;
    }
    catch
    {
        return connectionString;
    }
}

static string? ResolveConnectionStringFromEnvironment(bool isDevelopment)
{
    var directConnection = GetFirstEnvironmentValue(
        "DB_CONNECTION",
        "ConnectionStrings__DefaultConnection",
        "DEFAULT_CONNECTION_STRING");

    if (!string.IsNullOrWhiteSpace(directConnection))
    {
        var parsedFromDirect = TryBuildConnectionStringFromMySqlUrl(directConnection, isDevelopment);
        return !string.IsNullOrWhiteSpace(parsedFromDirect) ? parsedFromDirect : directConnection.Trim();
    }

    var urlVariables = new[]
    {
        "DATABASE_URL",
        "MYSQL_URL",
        "MYSQL_PUBLIC_URL",
        "MYSQL_INTERNAL_URL",
        "DATABASE_PUBLIC_URL",
        "RAILWAY_DATABASE_URL",
        "MYSQLDATABASE_URL"
    };

    foreach (var variableName in urlVariables)
    {
        var value = Environment.GetEnvironmentVariable(variableName);
        if (string.IsNullOrWhiteSpace(value))
        {
            continue;
        }

        var parsed = TryBuildConnectionStringFromMySqlUrl(value, isDevelopment);
        if (!string.IsNullOrWhiteSpace(parsed))
        {
            return parsed;
        }
    }

    var host = GetFirstEnvironmentValue(
        "MYSQL_PUBLIC_HOST",
        "MYSQLHOST",
        "DB_HOST",
        "DATABASE_HOST");
    var database = GetFirstEnvironmentValue("MYSQLDATABASE", "DB_NAME", "DATABASE_NAME");
    var user = GetFirstEnvironmentValue("MYSQLUSER", "DB_USER", "DATABASE_USER");
    var password = GetFirstEnvironmentValue(
        "MYSQL_LOCAL_PASSWORD",
        "MYSQL_ROOT_PASSWORD",
        "MYSQLPASSWORD",
        "DB_PASSWORD",
        "DATABASE_PASSWORD");
    var portText = GetFirstEnvironmentValue(
        "MYSQL_PUBLIC_PORT",
        "MYSQLPORT",
        "DB_PORT",
        "DATABASE_PORT") ?? "3306";

    if (string.IsNullOrWhiteSpace(host)
        || string.IsNullOrWhiteSpace(database)
        || string.IsNullOrWhiteSpace(user))
    {
        return null;
    }

    var builder = new MySqlConnectionStringBuilder
    {
        Server = host.Trim(),
        Database = database.Trim(),
        UserID = user.Trim(),
        Password = password ?? string.Empty,
        Port = uint.TryParse(portText, out var parsedPort) ? parsedPort : 3306,
        TreatTinyAsBoolean = true
    };

    var sslModeText = GetFirstEnvironmentValue("MYSQL_SSLMODE", "MYSQL_SSL_MODE", "DB_SSLMODE", "SSLMODE");
    builder.SslMode = ResolveSslMode(sslModeText, builder.Server, isDevelopment);

    return builder.ConnectionString;
}

static string? TryBuildConnectionStringFromMySqlUrl(string url, bool isDevelopment)
{
    if (!Uri.TryCreate(url.Trim(), UriKind.Absolute, out var uri)
        || !string.Equals(uri.Scheme, "mysql", StringComparison.OrdinalIgnoreCase))
    {
        return null;
    }

    var userInfo = (uri.UserInfo ?? string.Empty).Split(':', 2);
    var user = userInfo.Length > 0 ? WebUtility.UrlDecode(userInfo[0]) : string.Empty;
    var password = userInfo.Length > 1 ? WebUtility.UrlDecode(userInfo[1]) : string.Empty;
    var database = uri.AbsolutePath.Trim('/');

    if (string.IsNullOrWhiteSpace(uri.Host)
        || string.IsNullOrWhiteSpace(user)
        || string.IsNullOrWhiteSpace(database))
    {
        return null;
    }

    var builder = new MySqlConnectionStringBuilder
    {
        Server = uri.Host,
        Port = uri.Port > 0 ? (uint)uri.Port : 3306,
        Database = WebUtility.UrlDecode(database),
        UserID = user,
        Password = password,
        TreatTinyAsBoolean = true
    };

    var sslModeFromQuery = GetQueryStringValue(uri.Query, "sslmode")
        ?? GetQueryStringValue(uri.Query, "ssl-mode");
    builder.SslMode = ResolveSslMode(sslModeFromQuery, builder.Server, isDevelopment);

    return builder.ConnectionString;
}

static string? GetFirstEnvironmentValue(params string[] keys)
{
    foreach (var key in keys)
    {
        var value = Environment.GetEnvironmentVariable(key);
        if (!string.IsNullOrWhiteSpace(value))
        {
            return value;
        }
    }

    return null;
}

static string? GetQueryStringValue(string query, string key)
{
    if (string.IsNullOrWhiteSpace(query) || string.IsNullOrWhiteSpace(key))
    {
        return null;
    }

    var trimmed = query.TrimStart('?');
    var pairs = trimmed.Split('&', StringSplitOptions.RemoveEmptyEntries);
    foreach (var pair in pairs)
    {
        var parts = pair.Split('=', 2);
        var currentKey = WebUtility.UrlDecode(parts[0] ?? string.Empty);
        if (!string.Equals(currentKey, key, StringComparison.OrdinalIgnoreCase))
        {
            continue;
        }

        var rawValue = parts.Length > 1 ? parts[1] : string.Empty;
        return WebUtility.UrlDecode(rawValue);
    }

    return null;
}

static MySqlSslMode ResolveSslMode(string? sslModeText, string host, bool isDevelopment)
{
    if (!string.IsNullOrWhiteSpace(sslModeText)
        && Enum.TryParse<MySqlSslMode>(sslModeText, ignoreCase: true, out var parsedMode))
    {
        return parsedMode;
    }

    return IsLocalDatabaseHost(host)
        ? MySqlSslMode.None
        : (isDevelopment ? MySqlSslMode.Preferred : MySqlSslMode.Required);
}

static void WarnIfLikelyInvalidProductionDatabaseHost(string connectionString, ILogger logger, bool isDevelopment)
{
    if (isDevelopment)
    {
        return;
    }

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
                "Detected local MySQL host '{Server}' in a non-development environment. On Render, set DB_CONNECTION (or ConnectionStrings__DefaultConnection) to your managed MySQL host.",
                server);
        }
    }
    catch (Exception ex)
    {
        logger.LogWarning(ex, "Unable to parse ConnectionStrings:DefaultConnection for deployment diagnostics.");
    }
}

static void WarnIfLocalDatabasePasswordLooksMissing(string connectionString, ILogger logger, bool isDevelopment)
{
    if (!isDevelopment || string.IsNullOrWhiteSpace(connectionString))
    {
        return;
    }

    try
    {
        var connectionStringBuilder = new MySqlConnectionStringBuilder(connectionString);
        if (IsLocalDatabaseHost(connectionStringBuilder.Server ?? string.Empty)
            && string.IsNullOrWhiteSpace(connectionStringBuilder.Password))
        {
            logger.LogWarning(
                "Local MySQL connection string has an empty password. If your MySQL user requires a password, set MYSQL_LOCAL_PASSWORD or ConnectionStrings__DefaultConnection before running the API.");
        }
    }
    catch
    {
        // Ignore diagnostics parsing errors to avoid startup interruption.
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

static async Task<SystemMaintenanceState?> GetMaintenanceStateFromDatabaseAsync(IServiceProvider services)
{
    try
    {
        using var scope = services.CreateScope();
        var dbConnectionFactory = scope.ServiceProvider.GetRequiredService<IDbConnectionFactory>();
        using var connection = dbConnectionFactory.CreateConnection();

        var state = await connection.QuerySingleOrDefaultAsync<SystemMaintenanceState>(new CommandDefinition(
            "SELECT COALESCE(is_active, 0) AS IsActive, COALESCE(maintenance_message, '') AS Message FROM website_maintenance WHERE id = 1 LIMIT 1;",
            cancellationToken: CancellationToken.None));

        return state ?? new SystemMaintenanceState { IsActive = false, Message = string.Empty };
    }
    catch (Exception)
    {
        return new SystemMaintenanceState { IsActive = false, Message = string.Empty };
    }
}

file interface IMaintenanceStateCache
{
    Task<SystemMaintenanceState?> GetMaintenanceStateAsync(Func<Task<SystemMaintenanceState?>> factory);
}

file sealed class MaintenanceStateCache : IMaintenanceStateCache
{
    private SystemMaintenanceState? _cachedState;
    private DateTime _cacheExpiry = DateTime.MinValue;
    private readonly TimeSpan _cacheDuration = TimeSpan.FromSeconds(30);
    private readonly object _lock = new();

    public async Task<SystemMaintenanceState?> GetMaintenanceStateAsync(Func<Task<SystemMaintenanceState?>> factory)
    {
        lock (_lock)
        {
            if (DateTime.UtcNow < _cacheExpiry && _cachedState != null)
            {
                return _cachedState;
            }
        }

        var state = await factory();

        lock (_lock)
        {
            _cachedState = state;
            _cacheExpiry = DateTime.UtcNow.Add(_cacheDuration);
        }

        return state;
    }
}

file sealed class SystemMaintenanceState
{
    public bool IsActive { get; init; }
    public string Message { get; init; } = string.Empty;
}
