@echo off
title Offline Library - close this window to stop
cd /d "%~dp0"
set "KS="
set "KM="
for /r "Kiwix-Reader\tools\win-x86_64" %%f in (kiwix-serve.exe) do if exist "%%f" set "KS=%%f"
for /r "Kiwix-Reader\tools\win-x86_64" %%f in (kiwix-manage.exe) do if exist "%%f" set "KM=%%f"
if not defined KS goto noreader
if not defined KM goto noreader
set "LIB=%TEMP%\offline-library.xml"
if exist "%LIB%" del "%LIB%"
echo Finding archives on the drive...
for /r %%f in (*.zim) do "%KM%" "%LIB%" add "%%f" >nul 2>&1
echo Opening the library at http://localhost:8095  (close this window to stop)
start "" cmd /c "timeout /t 3 >nul & start http://localhost:8095"
"%KS%" --address=127.0.0.1 --port=8095 --library "%LIB%"
pause
exit /b 0
:noreader
echo The Windows library reader is missing from Kiwix-Reader\tools\win-x86_64.
pause
exit /b 1
