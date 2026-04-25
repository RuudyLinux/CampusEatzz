@echo off
:: Run this file as Administrator to allow port 5266 through Windows Firewall.
:: Right-click -> "Run as administrator"

echo [INFO] Adding Windows Firewall rule for port 5266...
netsh advfirewall firewall delete rule name="dotnet port 5266" >nul 2>&1
netsh advfirewall firewall add rule name="dotnet port 5266" dir=in action=allow protocol=TCP localport=5266
if %ERRORLEVEL% EQU 0 (
    echo [OK]   Firewall rule added. Port 5266 is now open for inbound connections.
) else (
    echo [FAIL] Could not add rule. Make sure you ran this as Administrator.
)
echo.
echo [INFO] Verifying rule...
netsh advfirewall firewall show rule name="dotnet port 5266"
pause
