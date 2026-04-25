@echo off
setlocal

set "PORT=5266"
if not "%~1"=="" set "PORT=%~1"

echo Stopping backend API on port %PORT%...

powershell -NoProfile -ExecutionPolicy Bypass -Command "$port = [int]('%PORT%'); $pids = @(); try { $pids = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction Stop | Select-Object -ExpandProperty OwningProcess -Unique } catch { $lines = netstat -ano -p tcp | Select-String (':' + $port + '\s+.*LISTENING\s+(\d+)$'); foreach ($line in $lines) { if ($line -match 'LISTENING\s+(\d+)$') { $pids += [int]$Matches[1] } } $pids = $pids | Select-Object -Unique }; if (-not $pids -or $pids.Count -eq 0) { Write-Output ('[INFO] No listening process found on port ' + $port + '.'); exit 0 }; foreach ($procId in $pids) { try { $proc = Get-Process -Id $procId -ErrorAction Stop; Stop-Process -Id $procId -Force -ErrorAction Stop; Write-Output ('[OK] Stopped PID ' + $procId + ' (' + $proc.ProcessName + ') on port ' + $port + '.'); } catch { Write-Output ('[WARN] Failed to stop PID ' + $procId + '. ' + $_.Exception.Message) } }"

set "EXIT_CODE=%ERRORLEVEL%"
if %EXIT_CODE% GEQ 1 (
    echo [ERROR] Failed to stop backend API on port %PORT%.
    exit /b %EXIT_CODE%
)

echo Done.
exit /b 0
