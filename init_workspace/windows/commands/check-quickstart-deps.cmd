@echo off
chcp 65001 > nul

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { try { $global:LASTEXITCODE = 0; & '%~dp0..\technical\check-quickstart-deps.ps1'; exit $global:LASTEXITCODE } catch { Write-Host ''; Write-Host ('[ERROR] ' + $_.Exception.Message) -ForegroundColor Red; exit 1 } }"
set CHECK_RESULT=%ERRORLEVEL%

if "%NO_PAUSE%"=="1" exit /b %CHECK_RESULT%

echo.
pause
exit /b %CHECK_RESULT%
