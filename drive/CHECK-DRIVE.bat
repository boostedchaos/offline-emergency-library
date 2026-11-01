@echo off
title Check Drive
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-drive.ps1"
pause
