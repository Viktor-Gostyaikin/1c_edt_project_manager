@echo off
chcp 65001 > nul

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-platform.ps1" %*
set INSTALL_RESULT=%ERRORLEVEL%

if "%NO_PAUSE%"=="1" exit /b %INSTALL_RESULT%

echo.
pause
exit /b %INSTALL_RESULT%
