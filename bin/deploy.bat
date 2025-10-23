@echo off
REM ERPNext Windows Deployment Script
REM This script helps deploy ERPNext on Windows servers

setlocal enabledelayedexpansion

echo ??????????????????????????????????????????????????????????
echo ?           ERPNext Windows Deployment Script           ?
echo ??????????????????????????????????????????????????????????
echo.

set "DEPLOY_ENV=%1"
if "%DEPLOY_ENV%"=="" set "DEPLOY_ENV=production"

echo [INFO] Starting deployment process...
echo [INFO] Environment: %DEPLOY_ENV%
echo [INFO] Timestamp: %date% %time%
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Not running as administrator
    echo [INFO] Some operations may require elevated privileges
    echo.
)

REM Backup existing configuration
if exist "frappe-bench\sites" (
    echo [INFO] Creating backup of existing sites...
    set "BACKUP_DIR=backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
    set "BACKUP_DIR=!BACKUP_DIR: =0!"
    mkdir "!BACKUP_DIR!" 2>nul
    xcopy "frappe-bench\sites" "!BACKUP_DIR!\sites\" /E /I /Q
    echo [INFO] Backup created in: !BACKUP_DIR!
)

REM Pull latest images
echo [INFO] Pulling latest Docker images...
docker compose pull
if %errorlevel% neq 0 (
    echo [ERROR] Failed to pull Docker images
    exit /b 1
)

REM Stop existing containers
echo [INFO] Stopping existing containers...
docker compose down
if %errorlevel% neq 0 (
    echo [WARNING] Failed to stop some containers, continuing...
)

REM Clean up old containers and images
echo [INFO] Cleaning up old containers and images...
docker container prune -f
docker image prune -f

REM Start services based on environment
if "%DEPLOY_ENV%"=="production" (
    echo [INFO] Starting production deployment...
    docker compose -f docker-compose.yml up -d
) else if "%DEPLOY_ENV%"=="staging" (
    echo [INFO] Starting staging deployment...
    docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d
) else (
    echo [INFO] Starting local deployment...
    docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
)

if %errorlevel% neq 0 (
    echo [ERROR] Deployment failed
    exit /b 1
)

REM Wait for services to be ready
echo [INFO] Waiting for services to be ready...
timeout /t 30 /nobreak >nul

REM Health check
echo [INFO] Performing health check...
set "HEALTH_CHECK_PASSED=false"

for /l %%i in (1,1,10) do (
    docker ps --filter "name=erpnext" --filter "status=running" | find "erpnext" >nul
    if !errorlevel! equ 0 (
        echo [INFO] Health check passed ?
        set "HEALTH_CHECK_PASSED=true"
        goto :health_check_done
    )
    echo [INFO] Attempt %%i/10: Waiting for containers to be healthy...
    timeout /t 10 /nobreak >nul
)

:health_check_done
if "%HEALTH_CHECK_PASSED%"=="false" (
    echo [ERROR] Health check failed
    echo [INFO] Checking container logs...
    docker compose logs --tail=50
    exit /b 1
)

REM Show deployment status
echo.
echo [INFO] Deployment completed successfully! ?
echo.
echo ???????????????????????????????????????????????????????????
echo Deployment Summary:
echo ???????????????????????????????????????????????????????????
echo Environment: %DEPLOY_ENV%
echo Timestamp: %date% %time%
echo.

REM Show running containers
echo Running containers:
docker ps --filter "name=erpnext" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo.
echo Next steps:
echo   1. Access ERPNext web interface
echo   2. Check logs: make win-logs
echo   3. Monitor status: docker ps
echo   4. Stop services: make win-down
echo.
echo ???????????????????????????????????????????????????????????