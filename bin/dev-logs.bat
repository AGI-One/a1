@echo off
REM Helper script to show live logs from ERPNext development container
REM Usage: bin\dev-logs.bat

setlocal enabledelayedexpansion

echo ?? Showing live logs from ERPNext development container...
echo    Press Ctrl+C to stop watching logs
echo.

REM Find the ERPNext app container
set "CONTAINER_NAME=erpnext-app"

REM Check if container is running
docker ps -q -f "name=%CONTAINER_NAME%" >nul 2>&1
if %errorlevel% neq 0 (
    echo ? ERPNext container '%CONTAINER_NAME%' is not running
    echo    Start it with: make win-up or make win-up-build
    exit /b 1
)

REM Get container ID
for /f %%i in ('docker ps -q -f "name=%CONTAINER_NAME%"') do set "CONTAINER_ID=%%i"

if "%CONTAINER_ID%"=="" (
    echo ? ERPNext container '%CONTAINER_NAME%' is not running
    echo    Start it with: make win-up or make win-up-build
    exit /b 1
)

echo ? Found container: %CONTAINER_NAME% ^(ID: %CONTAINER_ID%^)
echo ?? Watching logs ^(with watchexec auto-reload info^)...
echo ????????????????????????????????????????????????????????

REM Follow logs with timestamps
docker logs -f --timestamps "%CONTAINER_ID%" 2>&1