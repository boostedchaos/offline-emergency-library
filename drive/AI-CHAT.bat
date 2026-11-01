@echo off
title Offline AI chat - close this window to stop
cd /d "%~dp0"
rem Offline AI chat in your web browser. You can attach PDFs and text files in the chat.
set "PORT=8098"
set "SMALL=AI-Offline\models\Qwen3.5-4B-Q4_K_M.gguf"
set "MEDIUM=AI-Offline\models\gemma-4-12b-it-qat-q4_0.gguf"
set "P=win-cpu-x64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "P=win-cpu-arm64"
set "GPU="
echo Offline AI chat
echo   1 = Small  (Qwen 3.5 4B)  - fast, needs about 8 GB of memory
echo   2 = Medium (Gemma 4 12B)  - better answers, needs about 16 GB of memory
echo   3 = Small on the graphics card (GPU)
echo   4 = Medium on the graphics card (GPU)
choice /c 1234 /n /m "Type 1, 2, 3 or 4: "
set "C=%errorlevel%"
set "MODEL=%SMALL%"
if "%C%"=="2" set "MODEL=%MEDIUM%"
if "%C%"=="4" set "MODEL=%MEDIUM%"
if "%C%"=="3" set "P=win-vulkan-x64"
if "%C%"=="4" set "P=win-vulkan-x64"
if "%P%"=="win-vulkan-x64" set "GPU=-ngl 99"
if not exist "%MODEL%" goto nomodel
set "SRV="
for /r "AI-Offline\engine\%P%" %%f in (llama-server.exe) do if exist "%%f" set "SRV=%%f"
if not defined SRV goto noengine
echo Loading the model (can take up to a minute from the drive)...
echo Your browser opens at http://localhost:%PORT% when it is ready. Close this window to stop.
start "" /b powershell -NoProfile -WindowStyle Hidden -Command "for($i=0;$i -lt 180;$i++){try{Invoke-WebRequest -UseBasicParsing http://127.0.0.1:%PORT%/health -TimeoutSec 2 | Out-Null; Start-Process 'http://localhost:%PORT%'; break}catch{Start-Sleep 1}}"
"%SRV%" -m "%MODEL%" -c 8192 %GPU% --host 127.0.0.1 --port %PORT%
pause
exit /b 0
:nomodel
echo That model is not on this drive: %MODEL%
pause
exit /b 1
:noengine
echo The AI program for this computer (%P%) is missing from AI-Offline\engine\.
pause
exit /b 1
