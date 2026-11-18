@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0stop-dev.ps1"
set "EXIT_CODE=%ERRORLEVEL%"
echo.
if not "%EXIT_CODE%"=="0" (
  echo Stop failed. Review the error above.
) else (
  echo Stop completed.
)
echo.
pause
exit /b %EXIT_CODE%
