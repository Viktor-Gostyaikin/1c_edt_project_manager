@echo off
chcp 65001 > nul

net session > nul 2>&1
if not "%ERRORLEVEL%"=="0" (
    echo Для запуска мастера требуются права администратора.
    echo Сейчас появится запрос контроля учетных записей Windows.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    exit /b 0
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0technical\start-workspace-setup.ps1" %*
set SETUP_RESULT=%ERRORLEVEL%

exit /b %SETUP_RESULT%
