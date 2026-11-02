@echo off
title Offline Maps - close this window to stop
cd /d "%~dp0"
set "P=windows-amd64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "P=windows-arm64"
set "C=%~dp0server\%P%\caddy.exe"
if not exist "%C%" goto missing
if not exist "%~dp0regions.json" goto missing
echo Opening the maps at http://localhost:8097/viewer/  (close this window to stop)
start "" cmd /c "timeout /t 2 >nul & start http://localhost:8097/viewer/"
"%C%" file-server --root "%~dp0." --listen 127.0.0.1:8097
pause
exit /b 0
:missing
echo The maps or their web server for this computer (%P%) are missing from this folder.
pause
exit /b 1
