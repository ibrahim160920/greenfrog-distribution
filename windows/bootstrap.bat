@echo off
rem GreenFrog Windows Bootstrap
rem ============================================================
rem Double-click this file to install and start GreenFrog.
rem No server configuration required for personal use.
rem
rem For managed/organization deployments, pass an enrollment URL:
rem   bootstrap.bat --enrollment-url https://your-server/api/distribution/enroll
rem ============================================================
title GreenFrog

setlocal enabledelayedexpansion

set ENROLLMENT_URL=
set DATA_DIR=%APPDATA%\GreenFrog

rem Parse arguments
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
echo   GreenFrog
echo ============================================================
echo.

rem Check Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo   ERROR: Node.js is not installed.
    echo.
    echo   Install Node.js 22 or later:
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
    goto :maybe_set_url
)

rem Run installer
echo   Installing GreenFrog...
echo.
set SCRIPT_DIR=%~dp0
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install.ps1"
if %errorlevel% neq 0 (
    echo.
    echo   Installation failed. See errors above.
    pause
    exit /b 1
)

:maybe_set_url
rem Write enrollment URL to config only if explicitly provided
if not "%ENROLLMENT_URL%"=="" (
    powershell -NonInteractive -ExecutionPolicy Bypass -Command "Add-Content -Encoding UTF8 '%DATA_DIR%\config.ps1' \"`n`$env:GF_ENROLLMENT_URL = '%ENROLLMENT_URL%'\""
    echo   Enrollment URL configured: %ENROLLMENT_URL%
    echo.
)

:launch
echo ============================================================
echo   Starting GreenFrog...
echo   On first launch, local identity is initialized automatically.
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
