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
set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL_EXE%" set "POWERSHELL_EXE=powershell.exe"
rem Default install location: sibling of the extraction directory named GreenFrog
rem e.g. bootstrap.bat is in D:\greenfrog-v1.4.0-windows\  ->  DATA_DIR = D:\GreenFrog
set SCRIPT_DIR=%~dp0
if "%SCRIPT_DIR:~-1%"=="\" set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%
for %%I in ("%SCRIPT_DIR%\..") do set PARENT_DIR=%%~fI
set DATA_DIR=%PARENT_DIR%\GreenFrog

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

rem Check if already installed
if exist "%DATA_DIR%\runtime\index.js" (
    echo   GreenFrog runtime detected at: %DATA_DIR%
    echo.
    goto :maybe_set_url
)

rem Run installer - pass DataDir and EnrollmentUrl so they are honoured
echo   Installing GreenFrog...
echo.
"%POWERSHELL_EXE%" -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\install.ps1" -DataDir "%DATA_DIR%" -EnrollmentUrl "%ENROLLMENT_URL%"
if %errorlevel% neq 0 (
    echo.
    echo   Installation failed. See errors above.
    pause
    exit /b 1
)
rem Installer already wrote the URL to config; skip to launch
goto :launch

:maybe_set_url
rem Write enrollment URL to config only if explicitly provided (already-installed path only)
if not "%ENROLLMENT_URL%"=="" (
    "%POWERSHELL_EXE%" -NonInteractive -ExecutionPolicy Bypass -Command "Add-Content -Encoding UTF8 '%DATA_DIR%\config.ps1' \"`n`$env:GF_ENROLLMENT_URL = '%ENROLLMENT_URL%'\""
    echo   Enrollment URL configured: %ENROLLMENT_URL%
    echo.
)

:launch
if exist "%DATA_DIR%\bin\bootstrap.bat" (
    call "%DATA_DIR%\bin\bootstrap.bat"
    exit /b %ERRORLEVEL%
)

echo.
echo   ERROR: Installed bootstrap not found at:
echo     %DATA_DIR%\bin\bootstrap.bat
echo.
pause
exit /b 1
