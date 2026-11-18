@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-dev.ps1" -OpenBrowser
set "EXIT_CODE=%ERRORLEVEL%"
echo.
if not "%EXIT_CODE%"=="0" (
  echo Startup failed. Review the error above.
) else (
  echo Startup completed.
)
echo.
pause
exit /b %EXIT_CODE%
