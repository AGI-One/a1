@echo off
REM ERPNext Windows Build Script
REM This script builds ERPNext for Windows deployment

setlocal enabledelayedexpansion

echo ??????????????????????????????????????????????????????????
echo ?            ERPNext Windows Build Script               ?
echo ??????????????????????????????????????????????????????????
echo.

set "BUILD_TYPE=%1"
if "%BUILD_TYPE%"=="" set "BUILD_TYPE=local"

echo [INFO] Starting ERPNext build process...
echo [INFO] Build type: %BUILD_TYPE%
echo.

REM Check prerequisites
echo [INFO] Checking prerequisites...

REM Check for Docker
where docker >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not installed or not in PATH
    echo Please install Docker Desktop from: https://www.docker.com/products/docker-desktop
    exit /b 1
)

REM Check for Docker Compose
docker compose version >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Docker Compose is not available
    echo Please ensure Docker Desktop is running
    exit /b 1
)

echo [INFO] Prerequisites check completed ?
echo.

REM Create necessary directories
echo [INFO] Creating necessary directories...
if not exist "database\mariadb\data" mkdir "database\mariadb\data"
if not exist "database\redis\data" mkdir "database\redis\data"
if not exist "frappe-bench" mkdir "frappe-bench"

REM Check and create .env files
echo [INFO] Checking environment configuration...
if not exist ".env" (
    if exist ".env.example" (
        copy ".env.example" ".env"
        echo [INFO] Created .env from .env.example
        echo [WARNING] Please review and update .env file with your configuration
    ) else (
        echo [ERROR] .env.example not found. Cannot create .env file
        exit /b 1
    )
)

if not exist "database\.env" (
    if exist "database\.env.example" (
        copy "database\.env.example" "database\.env"
        echo [INFO] Created database\.env from database\.env.example
    ) else (
        echo [ERROR] database\.env.example not found
        exit /b 1
    )
)

echo [INFO] Environment configuration completed ?
echo.

REM Build based on type
if "%BUILD_TYPE%"=="local" (
    echo [INFO] Building for local development...
    docker compose -f docker-compose.yml -f docker-compose.local.yml build
) else if "%BUILD_TYPE%"=="prod" (
    echo [INFO] Building for production...
    docker compose -f docker-compose.yml build
) else (
    echo [ERROR] Unknown build type: %BUILD_TYPE%
    echo [INFO] Supported types: local, prod
    exit /b 1
)

if %errorlevel% neq 0 (
    echo [ERROR] Build failed
    exit /b 1
)

echo.
echo [INFO] Build completed successfully! ?
echo.
echo Next steps:
if "%BUILD_TYPE%"=="local" (
    echo   1. Start the application: make win-up
    echo   2. Access ERPNext at: http://localhost:8080
) else (
    echo   1. Start the application: make win-up-prod  
    echo   2. Access ERPNext at the configured domain
)
echo   3. View logs: make win-logs
echo   4. Stop application: make win-down
echo.