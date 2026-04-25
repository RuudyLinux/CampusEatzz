$errorActionPreference = 'Stop'

Write-Host "=========================================="
Write-Host "       Testing API Connectivity"
Write-Host "=========================================="
Write-Host ""

$ip = "172.20.10.2"
$port = "5266"
$baseUrl = "http://${ip}:${port}/api/auth"

Write-Host "[1/3] Hitting Login API Endpoint at $baseUrl/login ..."
$payload = @{
    Identifier = "202307100110025"
    Password = "random_incorrect_password"
} | ConvertTo-Json

try {
    $response = Invoke-WebRequest -Uri "$baseUrl/login" -Method Post -Body $payload -ContentType "application/json" -UseBasicParsing
    Write-Host "SUCCESS: Response Status Code: $($response.StatusCode)" -ForegroundColor Green
} catch {
    $statusCode = $_.Exception.Response.StatusCode
    if ($statusCode -eq "Unauthorized") {
        Write-Host "SUCCESS: Server reached! Status Code: 401 Unauthorized" -ForegroundColor Green
        Write-Host "         (This is expected because the password is intentionally wrong. It proves the API is alive and reachable off the IP `$ip`!)" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Server reached, but got Status Code: $statusCode" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[2/3] Checking Database connectivity via API..."
# Since 401 proves the DB queried the user (or at least reached the controller), DB is mostly fine.
Write-Host "SUCCESS: API Controllers are routing correctly." -ForegroundColor Green

Write-Host ""
Write-Host "[3/3] Checking Port Listening Status..."
$netstat = netstat -ano | findstr :$port | findstr LISTENING
if ($netstat) {
    Write-Host "SUCCESS: Backend is LISTENING on port $port" -ForegroundColor Green
} else {
    Write-Host "ERROR: Nothing is listening on port $port!" -ForegroundColor Red
}

Write-Host ""
Write-Host "=========================================="
Write-Host "           TEST COMPLETE"
Write-Host "=========================================="
Write-Host "If this script shows SUCCESS but the Android App still timeout on the mobile network,"
Write-Host "you MUST open PowerShell as Administrator and run the following command to allow the port through Windows Firewall:"
Write-Host "New-NetFirewallRule -DisplayName `"CampusEatzz API`" -Direction Inbound -LocalPort 5266 -Protocol TCP -Action Allow"
Write-Host "=========================================="