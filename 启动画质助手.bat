@echo off
setlocal
chcp 936 >nul
cd /d "%~dp0"
title Douyin Quality Helper
echo.
echo   Starting the Douyin quality helper...
echo.
set "PS=powershell"
where powershell >nul 2>nul || set "PS=pwsh"
where %PS% >nul 2>nul || goto :nops
%PS% -NoProfile -ExecutionPolicy Bypass -File "douyin-quality-gui.ps1"
if errorlevel 1 goto :failed
exit /b 0
:nops
echo   [ERROR] PowerShell not found on this system.
echo.
pause
exit /b 1
:failed
echo.
echo   [ERROR] Startup failed. Please screenshot the messages above.
echo.
pause
exit /b 1
