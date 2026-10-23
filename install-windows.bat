@echo off
rem Runs install-windows.ps1 (pass -Uninstall to uninstall)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-windows.ps1" %*
echo.
pause
