# Test script to check database state for menu items

$BASE_URL = "https://campuseatzz.onrender.com"
$ADMIN_EMAIL = "admin@gmail.com"
$ADMIN_PASSWORD = "admin@123"

Write-Host "======== STEP 1: Get Auth Token ========" -ForegroundColor Cyan
try {
    $loginResponse = Invoke-RestMethod -Uri "$BASE_URL/api/auth/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body (@{
            email = $ADMIN_EMAIL
            password = $ADMIN_PASSWORD
        } | ConvertTo-Json) `
        -TimeoutSec 30

    $token = $loginResponse.data.token
    Write-Host "✓ Token obtained" -ForegroundColor Green
} catch {
    Write-Host "✗ Login failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n======== STEP 2: Check Canteen 1 Menu Items ========" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "$BASE_URL/api/canteen/menu-items?canteenId=1" `
        -Method GET `
        -Headers @{ Authorization = "Bearer $token" } `
        -TimeoutSec 30

    $items = $response.data.items
    Write-Host "Total items for canteen 1: $($items.Count)" -ForegroundColor Yellow
    Write-Host "First 3 items:" -ForegroundColor Yellow
    $items | Select-Object -First 3 | ConvertTo-Json | Write-Host
} catch {
    Write-Host "✗ Failed: $_" -ForegroundColor Red
}

Write-Host "`n======== STEP 3: Check Canteen 2 Menu Items ========" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "$BASE_URL/api/canteen/menu-items?canteenId=2" `
        -Method GET `
        -Headers @{ Authorization = "Bearer $token" } `
        -TimeoutSec 30

    $items = $response.data.items
    Write-Host "Total items for canteen 2: $($items.Count)" -ForegroundColor Yellow
    Write-Host "First 3 items:" -ForegroundColor Yellow
    $items | Select-Object -First 3 | ConvertTo-Json | Write-Host
} catch {
    Write-Host "✗ Failed: $_" -ForegroundColor Red
}

Write-Host "`n======== STEP 4: Check Canteen 3 Menu Items ========" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "$BASE_URL/api/canteen/menu-items?canteenId=3" `
        -Method GET `
        -Headers @{ Authorization = "Bearer $token" } `
        -TimeoutSec 30

    $items = $response.data.items
    Write-Host "Total items for canteen 3: $($items.Count)" -ForegroundColor Yellow
    Write-Host "First 3 items:" -ForegroundColor Yellow
    $items | Select-Object -First 3 | ConvertTo-Json | Write-Host
} catch {
    Write-Host "✗ Failed: $_" -ForegroundColor Red
}
