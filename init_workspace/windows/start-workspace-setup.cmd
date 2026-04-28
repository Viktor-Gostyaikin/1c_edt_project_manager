@echo off
chcp 65001 > nul

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\technical\start-workspace-setup.ps1" %*
set SETUP_RESULT=%ERRORLEVEL%

exit /b %SETUP_RESULT%
