@echo off
chcp 65001 > nul

wscript.exe "%~dp0technical\start-workspace-setup-hidden.vbs" %*
set SETUP_RESULT=%ERRORLEVEL%

exit /b %SETUP_RESULT%
