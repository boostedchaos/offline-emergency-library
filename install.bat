@echo off
title Offline Emergency Library - Installer
cd /d "%~dp0"
echo ================================================================
echo   OFFLINE EMERGENCY LIBRARY - INSTALLER
echo.
echo   This downloads a complete offline survival library + AI:
echo   local AI chat, document Q^&A, Wikipedia, US maps, and
echo   survival/repair/medical manuals.
echo.
echo   You will be asked ONE question: where to save the files.
echo   (Tip: an external drive or USB with 128 GB+ free is ideal.)
echo ================================================================
echo.
if exist "%~dp0Get-OfflineLibrary.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Get-OfflineLibrary.ps1"
) else (
  echo Downloading the installer script...
  curl.exe -fLsS -o "%TEMP%\Get-OfflineLibrary.ps1" "https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main/Get-OfflineLibrary.ps1"
  if errorlevel 1 goto :failed
  powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\Get-OfflineLibrary.ps1"
)
if errorlevel 1 goto :failed
echo.
echo Done. Open START-HERE.html in the folder you chose.
pause
exit /b 0

:failed
echo.
echo Installation failed. Review the error above and _download.log, then re-run to resume.
pause
exit /b 1
