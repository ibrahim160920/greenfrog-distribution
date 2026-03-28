@echo off
rem GreenFrog Windows Bootstrap
rem ============================================================
rem Double-click this file to install and set up GreenFrog.
rem Or run from a terminal with an enrollment URL:
rem   bootstrap.bat --enrollment-url https://your-server/api/distribution/enroll
rem ============================================================
title GreenFrog Setup

setlocal enabledelayedexpansion

set ENROLLMENT_URL=
set DATA_DIR=%APPDATA%\GreenFrog

rem Parse --enrollment-url argument
:parse_args
if "%~1"=="" goto :check_node
if /i "%~1"=="--enrollment-url" (
    set ENROLLMENT_URL=%~2
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--data-dir" (
    set DATA_DIR=%~2
    shift
    shift
    goto :parse_args
)
shift
goto :parse_args

:check_node
echo ============================================================
echo   GreenFrog -- Windows Setup
echo ============================================================
echo.

rem Check Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo   ERROR: Node.js is not installed.
    echo.
    echo   Install Node.js 18 or later:
    echo     winget install OpenJS.NodeJS.LTS
    echo.
    echo   Or download from: https://nodejs.org/en/download/
    echo.
    pause
    exit /b 1
)

rem Check if already installed
if exist "%DATA_DIR%\runtime\index.js" (
    echo   GreenFrog runtime detected at: %DATA_DIR%
    echo.
    goto :check_enrollment
)

rem Run installer
echo   Running installer...
echo.
set SCRIPT_DIR=%~dp0
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install.ps1"
if %errorlevel% neq 0 (
    echo.
    echo   Installation failed. See errors above.
    pause
    exit /b 1
)

:check_enrollment
rem Check/set enrollment URL
if not "%ENROLLMENT_URL%"=="" (
    rem Write enrollment URL to config
    powershell -NonInteractive -ExecutionPolicy Bypass -Command "Add-Content -Encoding UTF8 '%DATA_DIR%\config.ps1' \"`n`$env:GF_ENROLLMENT_URL = '%ENROLLMENT_URL%'\""
    echo   Enrollment URL: %ENROLLMENT_URL%
    goto :launch
)

rem Check if enrollment URL already configured
powershell -NonInteractive -ExecutionPolicy Bypass -Command "& { if (Test-Path '%DATA_DIR%\config.ps1') { . '%DATA_DIR%\config.ps1' } ; if ($env:GF_ENROLLMENT_URL) { exit 0 } else { exit 1 } }" >nul 2>&1
if %errorlevel% == 0 goto :launch

rem Prompt for enrollment URL
echo.
echo   Enter your GreenFrog server enrollment URL.
echo   This looks like: https://your-server.example.com/api/distribution/enroll
echo   Your administrator will provide this URL.
echo.
set /p ENROLLMENT_URL="  Enrollment URL: "

if "!ENROLLMENT_URL!"=="" (
    echo.
    echo   No URL entered. You can set it later in: %DATA_DIR%\config.ps1
    echo.
    goto :launch
)

powershell -NonInteractive -ExecutionPolicy Bypass -Command "Add-Content -Encoding UTF8 '%DATA_DIR%\config.ps1' \"`n`$env:GF_ENROLLMENT_URL = '!ENROLLMENT_URL!'\""
echo.
echo   Enrollment URL saved.

:launch
echo.
echo ============================================================
echo   Starting GreenFrog...
echo   Press Ctrl+C to stop.
echo ============================================================
echo.

if exist "%DATA_DIR%\bin\greenfrog.bat" (
    call "%DATA_DIR%\bin\greenfrog.bat"
) else (
    set GF_IS_CHILD_INSTANCE=true
    set GF_BASE_DIR=%DATA_DIR%
    node "%DATA_DIR%\runtime\index.js"
)

pause
