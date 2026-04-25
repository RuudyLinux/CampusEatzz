# Automated Render Environment Variable Update
# Updates campuseatzz-backend with Railway MySQL connection

param(
    [string]$ApiKey = "rnd_tNaIHwPUSnWsaoxH59MxJMSXsF7P",
    [string]$ServiceName = "campuseatzz-backend"
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Render Environment Variables Updater" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Railway connection values
$connectionString = "Server=roundhouse.proxy.rlwy.net;Port=47842;Database=universitycanteendb;User ID=root;Password=ZJUSaeMDXTrbQptDuNxAmiEBBKmiMsIf;SslMode=Required;TreatTinyAsBoolean=true;"

Write-Host "Step 1: Finding your Render service..." -ForegroundColor Green
Write-Host ""

# Get service ID
$headers = @{
    "Authorization" = "Bearer $ApiKey"
    "Content-Type"  = "application/json"
}

try {
    $servicesResponse = Invoke-RestMethod `
        -Uri "https://api.render.com/v1/services" `
        -Headers $headers `
        -Method Get

    $service = $servicesResponse.services | Where-Object { $_.name -eq $ServiceName }

    if (-not $service) {
        Write-Host "❌ Service '$ServiceName' not found!" -ForegroundColor Red
        Write-Host "Available services:" -ForegroundColor Yellow
        $servicesResponse.services | ForEach-Object { Write-Host "  - $($_.name)" }
        exit 1
    }

    $serviceId = $service.id
    Write-Host "✅ Found service: $ServiceName" -ForegroundColor Green
    Write-Host "   Service ID: $serviceId" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host "❌ Error finding service: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Step 2: Updating environment variables..." -ForegroundColor Green
Write-Host ""

# Environment variables to set
$envVars = @(
    @{
        key   = "ConnectionStrings__DefaultConnection"
        value = $connectionString
    },
    @{
        key   = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
    },
    @{
        key   = "Startup__FailOnSchemaInitError"
        value = "false"
    },
    @{
        key   = "Notifications__Scheduler__Enabled"
        value = "false"
    }
)

try {
    # Update each environment variable
    foreach ($envVar in $envVars) {
        Write-Host "  Setting: $($envVar.key)" -ForegroundColor Cyan

        $body = @{
            key   = $envVar.key
            value = $envVar.value
        } | ConvertTo-Json

        Invoke-RestMethod `
            -Uri "https://api.render.com/v1/services/$serviceId/env-vars" `
            -Headers $headers `
            -Method Post `
            -Body $body | Out-Null

        Write-Host "    ✅ Updated" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "✅ All environment variables set successfully!" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error updating environment variables: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Triggering redeploy..." -ForegroundColor Green
Write-Host ""

try {
    $redeployBody = @{
        clearCache = "clear"
    } | ConvertTo-Json

    $deployResponse = Invoke-RestMethod `
        -Uri "https://api.render.com/v1/services/$serviceId/deploys" `
        -Headers $headers `
        -Method Post `
        -Body $redeployBody

    $deployId = $deployResponse.id
    Write-Host "✅ Redeploy triggered!" -ForegroundColor Green
    Write-Host "   Deploy ID: $deployId" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host "❌ Error triggering redeploy: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Step 4: Waiting for deployment to complete..." -ForegroundColor Green
Write-Host ""

# Poll deployment status
$maxWaitTime = 180 # 3 minutes
$startTime = Get-Date
$statusCheckInterval = 5

while ($true) {
    $elapsed = (Get-Date) - $startTime

    if ($elapsed.TotalSeconds -gt $maxWaitTime) {
        Write-Host "⚠️  Deployment is taking longer than expected (3+ minutes)" -ForegroundColor Yellow
        Write-Host "   Check Render dashboard for detailed logs" -ForegroundColor Cyan
        Write-Host "   URL: https://dashboard.render.com" -ForegroundColor Cyan
        break
    }

    try {
        $deployStatus = Invoke-RestMethod `
            -Uri "https://api.render.com/v1/services/$serviceId/deploys/$deployId" `
            -Headers $headers `
            -Method Get

        $status = $deployStatus.status
        Write-Host "  Status: $status (elapsed: $([int]$elapsed.TotalSeconds)s)" -ForegroundColor Cyan

        if ($status -eq "live") {
            Write-Host ""
            Write-Host "✅ Deployment successful!" -ForegroundColor Green
            break
        }
        elseif ($status -eq "build_failed" -or $status -eq "deploy_failed") {
            Write-Host "❌ Deployment failed with status: $status" -ForegroundColor Red
            Write-Host "   Check Render logs for details" -ForegroundColor Cyan
            exit 1
        }
    }
    catch {
        Write-Host "  (checking status...)" -ForegroundColor Gray
    }

    Start-Sleep -Seconds $statusCheckInterval
}

Write-Host ""
Write-Host "Step 5: Testing database connection..." -ForegroundColor Green
Write-Host ""

# Test the health endpoint
$maxRetries = 6
$retryCount = 0
$testSuccess = $false

while ($retryCount -lt $maxRetries) {
    try {
        $healthResponse = Invoke-RestMethod `
            -Uri "https://campuseatzz.onrender.com/api/health/db" `
            -Method Get `
            -TimeoutSec 10

        Write-Host "✅ Database connection successful!" -ForegroundColor Green
        Write-Host "   Response: $healthResponse" -ForegroundColor Cyan
        $testSuccess = $true
        break
    }
    catch {
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "  Attempt $retryCount/$maxRetries - retrying in 5 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
    }
}

if (-not $testSuccess) {
    Write-Host "⚠️  Could not verify database connection yet" -ForegroundColor Yellow
    Write-Host "   The backend might still be initializing" -ForegroundColor Cyan
    Write-Host "   Try again in 30 seconds: curl https://campuseatzz.onrender.com/api/health/db" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "✅ SETUP COMPLETE!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your backend is now configured with:" -ForegroundColor Cyan
Write-Host "  • Railway MySQL (PUBLIC HOST: roundhouse.proxy.rlwy.net)" -ForegroundColor Cyan
Write-Host "  • Connection String: $connectionString" -ForegroundColor Cyan
Write-Host "  • Environment: Production" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  1. Wait 1-2 minutes for full deployment" -ForegroundColor Cyan
Write-Host "  2. Test in Flutter app: Login → Go to Wallet" -ForegroundColor Cyan
Write-Host "  3. Wallet should show balance (no error)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Troubleshooting:" -ForegroundColor Green
Write-Host "  Dashboard: https://dashboard.render.com" -ForegroundColor Cyan
Write-Host "  Health Check: curl https://campuseatzz.onrender.com/api/health/db" -ForegroundColor Cyan
Write-Host ""
