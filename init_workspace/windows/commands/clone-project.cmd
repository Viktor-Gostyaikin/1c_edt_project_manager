@echo off
chcp 65001 > nul

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { try { $global:LASTEXITCODE = 0; & '%~dp0..\technical\clone-project.ps1' @args; exit $global:LASTEXITCODE } catch { Write-Host ''; Write-Host ('[ERROR] ' + $_.Exception.Message) -ForegroundColor Red; exit 1 } }" %*
set CLONE_RESULT=%ERRORLEVEL%

if "%NO_PAUSE%"=="1" exit /b %CLONE_RESULT%

echo.
pause
exit /b %CLONE_RESULT%
