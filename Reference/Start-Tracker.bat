@echo off
REM Start Inventor Activity Tracker - Headless Edition
echo Starting Inventor Activity Tracker...
echo Press Ctrl+C in the PowerShell window to stop the tracker
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0run-tracker.ps1"
pause
