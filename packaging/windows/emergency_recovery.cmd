@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0emergency_recovery.ps1"
if errorlevel 1 pause
endlocal
