@echo off
chcp 65001 > nul

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { try { & '%~dp0..\technical\open-edt-config.ps1' @args; exit $LASTEXITCODE } catch { Write-Host ''; Write-Host ('[ERROR] ' + $_.Exception.Message) -ForegroundColor Red; exit 1 } }" %*
set OPEN_EDT_CONFIG_RESULT=%ERRORLEVEL%

if "%NO_PAUSE%"=="1" exit /b %OPEN_EDT_CONFIG_RESULT%

echo.
pause
exit /b %OPEN_EDT_CONFIG_RESULT%
