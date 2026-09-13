@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0scripts\launch.ps1" %*
set "result=%errorlevel%"
if not "%result%"=="0" pause
exit /b %result%
