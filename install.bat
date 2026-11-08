@echo off
title Offline Emergency Library - Installer
cd /d "%~dp0"
echo ================================================================
echo   OFFLINE EMERGENCY LIBRARY - INSTALLER
echo.
echo   This downloads a complete offline survival library + AI:
echo   local AI chat, document Q^&A, Wikipedia, US maps, and
echo   survival/repair/medical manuals.
echo ================================================================
echo.

rem Locate the PowerShell installer (local copy, else download it once).
set "PS1=%~dp0Get-OfflineLibrary.ps1"
if not exist "%PS1%" (
  echo Downloading the installer script...
  curl.exe -fLsS -o "%TEMP%\Get-OfflineLibrary.ps1" "https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main/Get-OfflineLibrary.ps1"
  if errorlevel 1 goto :failed
  set "PS1=%TEMP%\Get-OfflineLibrary.ps1"
)

echo How would you like to install?
echo   [P] Pick what to install (opens a page in your browser)
echo   [A] Install with a few questions (where to save, how much, which maps) - default
echo.
set "choice="
set /p "choice=Choose P or A [A]: "
if /i "%choice%"=="P" goto :picker
goto :full

:full
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
rem errorlevel 9009 = PowerShell could not be started (blocked / not found), not an install error.
if errorlevel 9009 goto :notstarted
if errorlevel 1 goto :failed
goto :done

:picker
if exist "%~dp0web\index.html" goto :haspage
echo The picker page ^(web\index.html^) is not in this folder.
goto :askfull
:haspage
echo Opening the picker page in your browser...
start "" "%~dp0web\index.html"
echo.
echo In the page: tick what you want, then click "Download selection.json"
echo (it saves to your Downloads folder). When you have done that, come back here.
echo.
pause
rem Newest selection*.json in Downloads (dir /o-d sorts newest first).
set "SEL="
for /f "delims=" %%F in ('dir /b /a-d /o-d "%USERPROFILE%\Downloads\selection*.json" 2^>nul') do (
  if not defined SEL set "SEL=%USERPROFILE%\Downloads\%%F"
)
if defined SEL goto :hassel
rem Kept out of a parenthesised block on purpose: a profile path containing ')'
rem (e.g. C:\Users\Jo (work)) would otherwise break the block.
echo No selection*.json found in %USERPROFILE%\Downloads.
goto :askfull
:hassel
echo.
echo Using: %SEL%
echo ----------------------------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Selection "%SEL%" -CheckSelection
if errorlevel 9009 goto :notstarted
if errorlevel 1 (
  echo That selection file is not valid. Fix it in the page and try again.
  goto :failed
)
echo ----------------------------------------------------------------
set "ans="
set /p "ans=Install this selection? [y/N]: "
if /i "%ans%"=="y" goto :doinstall
if /i "%ans%"=="yes" goto :doinstall
echo Cancelled. Nothing was downloaded.
goto :cancelled

:doinstall
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Selection "%SEL%"
if errorlevel 9009 goto :notstarted
if errorlevel 1 goto :failed
goto :done

:done
echo.
echo Done. Open START-HERE.html in the OfflineLibrary folder inside the folder you chose.
pause
exit /b 0

:askfull
rem A pick could not proceed (no page, or no selection file). The user chose Pick,
rem so confirm before starting a full (large) install instead of doing it silently.
echo.
set "ans="
set /p "ans=Install everything instead? [y/N]: "
if /i "%ans%"=="y" goto :full
if /i "%ans%"=="yes" goto :full
echo Cancelled. Nothing was downloaded.
goto :cancelled

:cancelled
echo.
pause
exit /b 0

:notstarted
echo.
echo PowerShell did not start. Windows may have blocked it (Smart App Control / SmartScreen).
echo Right-click Get-OfflineLibrary.ps1 ^> Properties ^> Unblock, or run it from an elevated
echo PowerShell window, then try again.
pause
exit /b 1

:failed
echo.
echo Installation failed or was stopped. Review the error above and _download.log, then re-run to resume.
pause
exit /b 1
