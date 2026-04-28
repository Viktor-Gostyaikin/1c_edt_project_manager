@echo off
chcp 65001 > nul

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { try { & '%~dp0..\technical\install-archiver.ps1' @args; exit $LASTEXITCODE } catch { Write-Host ''; Write-Host ('[ERROR] ' + $_.Exception.Message) -ForegroundColor Red; exit 1 } }" %*
set INSTALL_RESULT=%ERRORLEVEL%

if "%NO_PAUSE%"=="1" exit /b %INSTALL_RESULT%

echo.
pause
exit /b %INSTALL_RESULT%
