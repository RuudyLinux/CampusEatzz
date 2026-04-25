# Setup Railway + Render MySQL Connection
# This script helps you safely get Railway PUBLIC connection values
# and provides clear instructions for Render environment setup

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Railway + Render MySQL Setup Guide" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "IMPORTANT: Use Railway EXTENSION to get PUBLIC values only" -ForegroundColor Yellow
Write-Host "Do NOT use internal/private hosts - they won't work from Render" -ForegroundColor Yellow
Write-Host ""

Write-Host "Step 1: Get Railway PUBLIC MySQL Connection Values" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "1. Open VS Code Railway Extension" -ForegroundColor Cyan
Write-Host "2. Navigate to your MySQL database service" -ForegroundColor Cyan
Write-Host "3. In the Variables tab, look for these PUBLIC values:" -ForegroundColor Cyan
Write-Host "   - MYSQL_PUBLIC_HOST     (copy this)" -ForegroundColor Yellow
Write-Host "   - MYSQL_PUBLIC_PORT     (usually 3306)" -ForegroundColor Yellow
Write-Host "   - MYSQLDATABASE         (your database name)" -ForegroundColor Yellow
Write-Host "   - MYSQLUSER             (database user)" -ForegroundColor Yellow
Write-Host "   - MYSQLPASSWORD         (database password)" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  CRITICAL: Ignore MYSQLHOST - that's the internal host!" -ForegroundColor Red
Write-Host ""

Write-Host "Step 2: Create Connection String" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Format your connection string like this:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Server=<MYSQL_PUBLIC_HOST>;Port=<MYSQL_PUBLIC_PORT>;Database=<MYSQLDATABASE>;User ID=<MYSQLUSER>;Password=<MYSQLPASSWORD>;SslMode=Required;TreatTinyAsBoolean=true;" -ForegroundColor Yellow
Write-Host ""
Write-Host "Example (with placeholder values):" -ForegroundColor Cyan
Write-Host "Server=mysql.railway.app;Port=3306;Database=universitycanteendb;User ID=root;Password=myPassword123;SslMode=Required;TreatTinyAsBoolean=true;" -ForegroundColor Yellow
Write-Host ""

Write-Host "Step 3: Update Render Environment Variables" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Go to: https://dashboard.render.com" -ForegroundColor Cyan
Write-Host "  1. Find 'campuseatzz-backend' service" -ForegroundColor Cyan
Write-Host "  2. Click 'Environment'" -ForegroundColor Cyan
Write-Host "  3. Add these environment variables:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Key: ConnectionStrings__DefaultConnection" -ForegroundColor Yellow
Write-Host "Value: <your connection string from Step 2>" -ForegroundColor Yellow
Write-Host ""
Write-Host "Key: ASPNETCORE_ENVIRONMENT" -ForegroundColor Yellow
Write-Host "Value: Production" -ForegroundColor Yellow
Write-Host ""
Write-Host "Key: Startup__FailOnSchemaInitError" -ForegroundColor Yellow
Write-Host "Value: false" -ForegroundColor Yellow
Write-Host ""
Write-Host "Key: Notifications__Scheduler__Enabled" -ForegroundColor Yellow
Write-Host "Value: false" -ForegroundColor Yellow
Write-Host ""

Write-Host "Step 4: Save and Deploy" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
Write-Host ""
Write-Host "1. After updating env vars, Render will auto-trigger redeploy" -ForegroundColor Cyan
Write-Host "2. Wait for deployment to complete (~2-3 minutes)" -ForegroundColor Cyan
Write-Host "3. Check deployment logs in Render dashboard" -ForegroundColor Cyan
Write-Host ""

Write-Host "Step 5: Test the Connection" -ForegroundColor Green
Write-Host "==========================" -ForegroundColor Green
Write-Host ""
Write-Host "Once deployed, test these endpoints:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test API is running:" -ForegroundColor Yellow
Write-Host "  curl https://campuseatzz.onrender.com/api/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test database connection:" -ForegroundColor Yellow
Write-Host "  curl https://campuseatzz.onrender.com/api/health/db" -ForegroundColor Cyan
Write-Host ""
Write-Host "Both should return success. If they do, your MySQL connection is working!" -ForegroundColor Green
Write-Host ""

Write-Host "Step 6: Verify Database Tables" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green
Write-Host ""
Write-Host "Using Railway Extension, connect to MySQL and run:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  SHOW TABLES;" -ForegroundColor Yellow
Write-Host "  DESCRIBE website_maintenance;" -ForegroundColor Yellow
Write-Host "  DESCRIBE wallets;" -ForegroundColor Yellow
Write-Host "  DESCRIBE wallet_transactions;" -ForegroundColor Yellow
Write-Host ""
Write-Host "All 3 tables should exist (auto-created on first backend run)" -ForegroundColor Green
Write-Host ""

Write-Host "Step 7: Test Wallet API" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
Write-Host ""
Write-Host "In your Flutter app, login and try to view the wallet." -ForegroundColor Cyan
Write-Host "It should now work without 'Internal server error' messages." -ForegroundColor Green
Write-Host ""

Write-Host "TROUBLESHOOTING" -ForegroundColor Red
Write-Host "===============" -ForegroundColor Red
Write-Host ""
Write-Host "If /api/health/db fails:" -ForegroundColor Yellow
Write-Host "  - Double-check connection string spelling" -ForegroundColor Cyan
Write-Host "  - Verify password is URL-encoded if it has special chars" -ForegroundColor Cyan
Write-Host "  - Check Railway public host is accessible (not blocked by firewall)" -ForegroundColor Cyan
Write-Host "  - Enable SslMode=Required (Railway requires SSL)" -ForegroundColor Cyan
Write-Host ""
Write-Host "If wallet API still fails after DB connects:" -ForegroundColor Yellow
Write-Host "  - Check Render logs for schema creation errors" -ForegroundColor Cyan
Write-Host "  - Verify tables exist using Railway extension" -ForegroundColor Cyan
Write-Host "  - Check Flutter app has a valid JWT token" -ForegroundColor Cyan
Write-Host ""

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Setup Complete - Follow steps above!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
