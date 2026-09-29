@echo off
setlocal
cd /d "%~dp0backend"
echo.
echo ================================================
echo        ADVISE DIGITAL BACKEND - PORT 3001
echo ================================================
echo.
echo Backend URL: http://0.0.0.0:3001
if not exist node_modules (
  echo Installing dependencies...
  call npm.cmd install
)
call npm.cmd start
pause
