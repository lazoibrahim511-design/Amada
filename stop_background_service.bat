@echo off
setlocal
cd /d "%~dp0"

echo ========================================================
echo       Stopping Amada Attendance Background Sync
echo ========================================================
echo.

taskkill /f /im attendance_app.exe >nul 2>&1

echo [OK] Background sync process has been stopped.
echo.
timeout /t 3
