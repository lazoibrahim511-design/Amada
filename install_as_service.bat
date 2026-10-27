@echo off
setlocal
cd /d "%~dp0"
set "APP_PATH=%~dp0attendance_app.exe"

echo ========================================================
echo       Amada ZKTeco 24/7 Background Sync Installer
echo ========================================================
echo.
echo Registering Amada Attendance to run silently at Windows startup...

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "AmadaZkBackgroundSync" /t REG_SZ /d "\"%APP_PATH%\" --silent" /f >nul 2>&1

if %errorlevel% equ 0 (
    echo [OK] Successfully registered in Windows Startup.
) else (
    echo [WARNING] Could not write to registry, but you can still run manually.
)

echo.
echo Starting background attendance sync process now...
start "" wscript.exe "%~dp0run_background_service.vbs"

echo [OK] Background service is now running!
echo You can close this window. Your attendance punches will sync 24/7.
echo.
timeout /t 5
