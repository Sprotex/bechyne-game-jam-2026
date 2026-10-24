@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0push_to_itch.ps1" %*
exit /b %ERRORLEVEL%
