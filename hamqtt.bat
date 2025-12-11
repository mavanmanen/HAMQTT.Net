@ECHO OFF
REM Wraps the PowerShell script so you can just type 'hamqtt'
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0hamqtt.ps1" %*
IF %ERRORLEVEL% NEQ 0 (
    REM Fallback to standard powershell if pwsh (PowerShell Core) is missing
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0hamqtt.ps1" %*
)