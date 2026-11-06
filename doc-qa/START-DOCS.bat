@echo off
setlocal
echo Ask the manuals - local CPU AI
echo Open http://127.0.0.1:8081/AI-Offline/Manual-QA/ when the server is ready.
echo Keep this window open while using the reader. Press Ctrl+C to stop.
set "ENGINE=x64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ENGINE=arm64"
"%~dp0..\engine\%ENGINE%\llama-server.exe" -m "%~dp0..\models\Llama-3.2-3B-Instruct-Q4_K_M.gguf" -c 4096 -ngl 0 -t 4 --offline --host 127.0.0.1 --port 8081 --path "%~dp0..\.."
pause
