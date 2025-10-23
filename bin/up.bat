@echo off
REM ERPNext Docker Compose Startup Script for Windows
REM Usage:
REM bin\up.bat local       - Start in local development mode
REM bin\up.bat localbuild  - Start local with rebuild
REM bin\up.bat prod        - Start in production mode

setlocal enabledelayedexpansion

set env=%1

if "%env%"=="local" (
    echo ?? Starting ERPNext in local development mode...
    echo    Starting database first ^(from database/ folder^)...
    REM Create database directories and start database services
    call make win-dbup
    echo    Starting ERPNext app...
    docker compose -f docker-compose.local.yml up
    goto :eof
)

if "%env%"=="localbuild" (
    echo ?? Starting ERPNext in local development mode with rebuild...
    echo    Starting database first ^(from database/ folder^)...
    REM Create database directories and start database services
    call make win-dbup
    echo    Building and starting ERPNext app...
    docker compose -f docker-compose.local.yml up --build
    goto :eof
)

if "%env%"=="prod" (
    echo ?? Starting ERPNext in production mode...
    echo    Starting with database...
    docker compose -f docker-compose.yml up --build -d
    goto :eof
)

echo ? Environment not found! Please choose one of: [local, localbuild, prod]
exit /b 1