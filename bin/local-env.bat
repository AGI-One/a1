@echo off
REM Load environment variables from .env file for Windows

setlocal enabledelayedexpansion

if not exist ".env" (
    echo ? File .env không t?n t?i.
    exit /b 1
)

echo ?? ?ang load bi?n t? .env vào môi tr??ng hi?n t?i...

REM Read .env file and set environment variables
for /f "usebackq tokens=1,2 delims==" %%a in (".env") do (
    if not "%%a"=="" (
        if not "%%a:~0,1%"=="#" (
            set "%%a=%%b"
            echo    Loaded: %%a
        )
    )
)

echo ? Bi?n môi tr??ng ?ã ???c load.

REM Export variables to calling environment
endlocal & (
    for /f "usebackq tokens=1,2 delims==" %%a in (".env") do (
        if not "%%a"=="" (
            if not "%%a:~0,1%"=="#" (
                set "%%a=%%b"
            )
        )
    )
)