@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%admin_files"
set "ADMIN_BIND_URL=http://0.0.0.0:5001"
set "ADMIN_BROWSER_URL=http://localhost:5001/Home/AdminLogin"

echo [INFO] Admin API bind URL: %ADMIN_BIND_URL%
echo [INFO] Open admin panel in browser: %ADMIN_BROWSER_URL%
echo [WARN] Do not use http://0.0.0.0:5001 in browser.
echo [INFO] If port is busy, run: netstat -ano ^| findstr :5001
echo [INFO] To stop blocking process, run: taskkill /PID ^<PID^> /F
echo [INFO] Mobile should use LAN IP like: http://192.168.x.x:5001
echo.

pushd "%PROJECT_DIR%"
dotnet run --urls "%ADMIN_BIND_URL%"
set "EXIT_CODE=%ERRORLEVEL%"
popd

if %EXIT_CODE% GEQ 1 (
    echo [ERROR] Admin API failed to start. Check logs for "Address already in use" or startup errors.
)

pause
exit /b %EXIT_CODE%
