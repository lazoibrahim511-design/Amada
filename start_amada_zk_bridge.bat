@echo off
title Amada ZKTeco Cloud Bridge
color 0B
echo ===================================================================
echo               Amada ZKTeco Cloud Bridge (24/7 Desktop App)
echo ===================================================================
echo  This standalone desktop application connects to your local ZKTeco
echo  attendance machines via LAN (Port 4370) and automatically syncs
echo  all employee biometric punches directly to Firebase Cloud.
echo.
echo  - Mobile users everywhere will see punches in real time.
echo  - Runs in the background without needing mobile phones.
echo ===================================================================
echo.

flutter run -d windows -t lib/bridge_main.dart

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Bridge exited with error code %ERRORLEVEL%.
    pause
)
