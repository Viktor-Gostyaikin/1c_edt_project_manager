@echo off
chcp 65001 > nul

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-quickstart-deps.ps1"
set CHECK_RESULT=%ERRORLEVEL%

if "%NO_PAUSE%"=="1" exit /b %CHECK_RESULT%

echo.
pause
exit /b %CHECK_RESULT%
