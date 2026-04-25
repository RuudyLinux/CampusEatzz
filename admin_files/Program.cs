var builder = WebApplication.CreateBuilder(args);

var configuredPort = Environment.GetEnvironmentVariable("PORT");
var listenerPort = string.IsNullOrWhiteSpace(configuredPort) ? "5001" : configuredPort;
var adminAppUrls = $"http://0.0.0.0:{listenerPort}";
builder.WebHost.UseUrls(adminAppUrls);
var hasHttpsEndpoint = adminAppUrls.Contains("https://", StringComparison.OrdinalIgnoreCase);

// Add services to the container.
builder.Services.AddControllersWithViews();

var app = builder.Build();
var staticRootCandidates = new[]
{
    app.Environment.ContentRootPath,
    Path.GetFullPath(Path.Combine(app.Environment.ContentRootPath, ".."))
};

void MapWorkspaceStaticFolder(string folderName)
{
    var absolutePath = staticRootCandidates
        .Select(root => Path.Combine(root, folderName))
        .FirstOrDefault(Directory.Exists);

    if (string.IsNullOrWhiteSpace(absolutePath))
    {
        app.Logger.LogWarning("Shared static folder '{FolderName}' was not found.", folderName);
        return;
    }

    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(absolutePath),
        RequestPath = $"/{folderName}"
    });
}

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

if (hasHttpsEndpoint)
{
    app.UseHttpsRedirection();
}
app.UseStaticFiles();

// Only expose required shared asset folders from the workspace root.
MapWorkspaceStaticFolder("JS");
MapWorkspaceStaticFolder("CSS");
MapWorkspaceStaticFolder("assets");

app.UseRouting();

app.UseAuthorization();

app.MapStaticAssets();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=AdminDashboard}/{id?}")
    .WithStaticAssets();

app.Lifetime.ApplicationStarted.Register(() =>
{
    var addresses = app.Urls.Count > 0 ? string.Join(", ", app.Urls) : "http://0.0.0.0:5001";
    app.Logger.LogInformation("Admin app started successfully. Listening on: {Addresses}", addresses);
    app.Logger.LogInformation("Open admin panel in browser: http://localhost:{Port}/Home/AdminLogin", listenerPort);
});

app.Lifetime.ApplicationStopping.Register(() =>
{
    app.Logger.LogInformation("Admin app is stopping.");
});

try
{
    app.Run();
}
catch (IOException ex) when (ex.Message.Contains("address already in use", StringComparison.OrdinalIgnoreCase))
{
    app.Logger.LogCritical(ex,
        "Address already in use on admin port {Port}. Check with 'netstat -ano | findstr :{Port}' and stop the conflicting process using 'taskkill /PID <PID> /F'.",
        listenerPort,
        listenerPort);
    throw;
}
catch (Exception ex)
{
    app.Logger.LogCritical(ex, "Admin app startup failure. Check network binding and firewall rules for dotnet.");
    throw;
}
