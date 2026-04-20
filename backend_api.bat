@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%backend\UniversityCanteen.Api"
set "MYSQL_PORT=3306"
set "MYSQL_START_SCRIPT=C:\xampp\mysql_start.bat"

echo [INFO] Checking MySQL on 127.0.0.1:%MYSQL_PORT% ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "if ((Test-NetConnection -ComputerName 127.0.0.1 -Port %MYSQL_PORT% -WarningAction SilentlyContinue).TcpTestSucceeded) { exit 0 } else { exit 1 }"
if %ERRORLEVEL% GEQ 1 (
    if exist "%MYSQL_START_SCRIPT%" (
        echo [WARN] MySQL is not reachable on port %MYSQL_PORT%.
        echo [INFO] Starting XAMPP MySQL...
        start "mysqld" /min cmd /c "\"%MYSQL_START_SCRIPT%\""

        echo [INFO] Waiting for MySQL to become ready...
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$deadline=(Get-Date).AddSeconds(35); do { $ok=$false; try { $ok=(Test-NetConnection -ComputerName 127.0.0.1 -Port %MYSQL_PORT% -WarningAction SilentlyContinue).TcpTestSucceeded } catch { $ok=$false }; if ($ok) { exit 0 }; Start-Sleep -Milliseconds 700 } while((Get-Date) -lt $deadline); exit 1"

        if %ERRORLEVEL% GEQ 1 (
            echo [ERROR] MySQL did not become ready on port %MYSQL_PORT%.
            echo [HINT] Start MySQL manually from XAMPP Control Panel, then re-run this script.
            pause
            exit /b 1
        )
    ) else (
        echo [ERROR] MySQL is not reachable and start script was not found: %MYSQL_START_SCRIPT%
        echo [HINT] Start your MySQL server manually, then run this script again.
        pause
        exit /b 1
    )
)

if "%MYSQL_LOCAL_PASSWORD%"=="" (
    echo [INFO] MYSQL_LOCAL_PASSWORD is not set.
    echo [INFO] If your local MySQL user has a password, set it before running:
    echo [INFO]   setx MYSQL_LOCAL_PASSWORD "your_mysql_password"
    echo [INFO] Then open a new terminal and run this script again.
)

echo [INFO] Backend API target URL: http://0.0.0.0:5266
echo [INFO] If port is busy, run: netstat -ano ^| findstr :5266
echo [INFO] To stop blocking process, run: taskkill /PID ^<PID^> /F
echo [INFO] Mobile should use LAN IP like: http://192.168.x.x:5266
echo.

pushd "%PROJECT_DIR%"
dotnet run --urls "http://0.0.0.0:5266"
set "EXIT_CODE=%ERRORLEVEL%"
popd

if %EXIT_CODE% GEQ 1 (
    echo [ERROR] Backend API failed to start. Check logs for "Address already in use" or startup errors.
)

pause
exit /b %EXIT_CODE%
