# Test script to verify food item reorganization

$BASE_URL = "https://campuseatzz.onrender.com"
$ADMIN_EMAIL = "admin@gmail.com"
$ADMIN_PASSWORD = "admin@123"  # Update this with actual password

Write-Host "======== STEP 1: Get Auth Token ========" -ForegroundColor Cyan
$loginResponse = Invoke-RestMethod -Uri "$BASE_URL/api/auth/login" `
    -Method POST `
    -ContentType "application/json" `
    -Body @{
        email = $ADMIN_EMAIL
        password = $ADMIN_PASSWORD
    } | Select-Object -ExpandProperty data

$token = $loginResponse.token
Write-Host "✓ Token obtained: $($token.Substring(0, 20))..." -ForegroundColor Green

Write-Host "`n======== STEP 2: Check Current Menu Items ========" -ForegroundColor Cyan
$checkBefore = Invoke-RestMethod -Uri "$BASE_URL/api/admin/check-canteens" `
    -Method GET `
    -Headers @{ Authorization = "Bearer $token" }

Write-Host "Current Database State:" -ForegroundColor Yellow
$checkBefore.data | ConvertTo-Json | Write-Host

Write-Host "`n======== STEP 3: Trigger Reorganization ========" -ForegroundColor Cyan
$reorganizeResponse = Invoke-RestMethod -Uri "$BASE_URL/api/admin/reorganize-food-items" `
    -Method POST `
    -Headers @{ Authorization = "Bearer $token" }

Write-Host "Reorganization Result:" -ForegroundColor Yellow
$reorganizeResponse.data | ConvertTo-Json | Write-Host

Write-Host "`n======== STEP 4: Check Updated Menu Items ========" -ForegroundColor Cyan
Start-Sleep -Seconds 2
$checkAfter = Invoke-RestMethod -Uri "$BASE_URL/api/admin/check-canteens" `
    -Method GET `
    -Headers @{ Authorization = "Bearer $token" }

Write-Host "Updated Database State:" -ForegroundColor Yellow
$checkAfter.data | ConvertTo-Json | Write-Host

Write-Host "`n======== VERIFICATION SUMMARY ========" -ForegroundColor Green
Write-Host "Items before: $($checkBefore.data.menuItemStats.active)"
Write-Host "Items after: $($checkAfter.data.menuItemStats.active)"
Write-Host "Expected new items: 20"
