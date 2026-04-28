@echo off
chcp 65001 > nul

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { try { & '%~dp0..\technical\start-edt-cli.ps1' @args; exit $LASTEXITCODE } catch { Write-Host ''; Write-Host ('[ERROR] ' + $_.Exception.Message) -ForegroundColor Red; exit 1 } }" %*
set EDT_CLI_RESULT=%ERRORLEVEL%

if "%NO_PAUSE%"=="1" exit /b %EDT_CLI_RESULT%

echo.
pause
exit /b %EDT_CLI_RESULT%
