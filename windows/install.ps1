# GreenFrog Windows Installer
# ============================================================
# Installs the GreenFrog child runtime to %APPDATA%\GreenFrog\runtime
# and creates a launch wrapper at %APPDATA%\GreenFrog\bin\greenfrog.bat
#
# Usage:
#   powershell -File install.ps1 [-EnrollmentUrl <url>] [-DataDir <path>]
#
# Parameters:
#   -EnrollmentUrl <url>   Mother-body enrollment endpoint.
#                          Writes to config.ps1 automatically.
#                          If omitted, you can use bootstrap.bat for guided setup.
#   -DataDir <path>        Override install directory (default: %APPDATA%\GreenFrog)
# ============================================================
param(
    [string]$EnrollmentUrl = "",
    [string]$DataDir = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── Default paths ─────────────────────────────────────────────────────────────
if (-not $DataDir) {
    $DataDir = if ($env:GF_BASE_DIR) { $env:GF_BASE_DIR } else { Join-Path $env:APPDATA "GreenFrog" }
}
$RuntimeDir  = Join-Path $DataDir "runtime"
$BinDir      = Join-Path $DataDir "bin"
$LogsDir     = Join-Path $DataDir "logs"
$CacheDir    = Join-Path $DataDir "update-cache"

$SEP = "=" * 60

Write-Host $SEP
Write-Host "  GreenFrog -- Child Runtime Installer (Windows)"
Write-Host $SEP
Write-Host

# ── Step 1: Check Node.js >= 18 ───────────────────────────────────────────────
Write-Host "  Checking Node.js..."
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Write-Host
    Write-Host "  ERROR: Node.js is not installed."
    Write-Host
    Write-Host "  Install Node.js 18 or later — choose one:"
    Write-Host
    Write-Host "    winget (recommended, open a terminal and run):"
    Write-Host "      winget install OpenJS.NodeJS.LTS"
    Write-Host
    Write-Host "    Official installer: https://nodejs.org/en/download/"
    Write-Host
    exit 1
}

$nodeVersion = (node --version).TrimStart('v')
$nodeMajor   = [int]($nodeVersion.Split('.')[0])
if ($nodeMajor -lt 18) {
    Write-Host
    Write-Host "  ERROR: Node.js $nodeVersion detected. Version 18 or later is required."
    Write-Host "  Upgrade: winget upgrade OpenJS.NodeJS  or  https://nodejs.org/en/download/"
    Write-Host
    exit 1
}
Write-Host "  Node.js v$nodeVersion -- OK"
Write-Host

# ── Step 2: Create directory structure ───────────────────────────────────────
Write-Host "  Creating directories..."
foreach ($d in @($RuntimeDir, $BinDir, $LogsDir, $CacheDir,
    (Join-Path $DataDir "identity"), (Join-Path $DataDir "backflow"),
    (Join-Path $DataDir "inheritance"), (Join-Path $DataDir "update-cache"))) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}
Write-Host "  Runtime  : $RuntimeDir"
Write-Host "  Data     : $DataDir"
Write-Host "  Logs     : $LogsDir"
Write-Host

# ── Step 3: Copy runtime files ────────────────────────────────────────────────
Write-Host "  Copying runtime files..."
$runtimeSource = Join-Path (Split-Path $ScriptDir -Parent) "runtime"
if (Test-Path $runtimeSource) {
    Copy-Item -Recurse -Force (Join-Path $runtimeSource "*") $RuntimeDir
} else {
    Copy-Item -Recurse -Force ".\*" $RuntimeDir -Exclude "install.ps1","bootstrap.bat"
}

if (-not (Test-Path (Join-Path $RuntimeDir "index.js"))) {
    Write-Host
    Write-Host "  ERROR: index.js not found in runtime bundle."
    Write-Host "  The installation package may be incomplete."
    Write-Host
    exit 1
}
Write-Host "  Runtime files installed."
Write-Host

# ── Step 4: Copy public key ───────────────────────────────────────────────────
$keySource = Join-Path (Split-Path $ScriptDir -Parent) "public-key.pem"
$keyDest   = Join-Path $DataDir "public-key.pem"
if (Test-Path $keySource) {
    Copy-Item -Force $keySource $keyDest
    Write-Host "  Public key installed."
} elseif (Test-Path ".\public-key.pem") {
    Copy-Item -Force ".\public-key.pem" $keyDest
    Write-Host "  Public key installed."
} else {
    Write-Warning "  public-key.pem not found -- manifest signature verification will be unavailable."
}
Write-Host

# ── Step 5: Write config (preserving existing) ────────────────────────────────
$configFile = Join-Path $DataDir "config.ps1"
if (-not (Test-Path $configFile)) {
    $templatePath = Join-Path $RuntimeDir "config.ps1.template"
    if (Test-Path $templatePath) {
        Copy-Item -Force $templatePath $configFile
    } else {
        @'
# GreenFrog Child Instance Configuration
# $env:GF_ENROLLMENT_URL = "https://your-server.example.com/api/distribution/enroll"
# $env:GF_DISTRIBUTION_URL = "https://your-server.example.com"
# $env:GF_LOCALE = ""  # Leave unset to auto-detect system locale
'@ | Set-Content -Encoding UTF8 $configFile
    }
    Write-Host "  Config created at: $configFile"
}

# Write enrollment URL if provided via -EnrollmentUrl
if ($EnrollmentUrl) {
    $lines = Get-Content $configFile -Raw
    if ($lines -match 'GF_ENROLLMENT_URL') {
        # Replace existing line (commented or not)
        $lines = $lines -replace '(?m).*GF_ENROLLMENT_URL.*', "`$env:GF_ENROLLMENT_URL = `"$EnrollmentUrl`""
        Set-Content -Encoding UTF8 $configFile $lines
    } else {
        Add-Content -Encoding UTF8 $configFile "`n`$env:GF_ENROLLMENT_URL = `"$EnrollmentUrl`""
    }
    Write-Host "  Enrollment URL written to config: $EnrollmentUrl"
}
Write-Host

# ── Step 6: Create launch wrapper (greenfrog.bat) ────────────────────────────
$launcherPath = Join-Path $BinDir "greenfrog.bat"
@"
@echo off
rem GreenFrog Child Runtime Launcher
rem Auto-generated by installer -- do not edit manually
set SCRIPT_DIR=%~dp0
for %%I in ("%SCRIPT_DIR%..") do set DATA_DIR=%%~fI
for /f "usebackq delims=" %%A in (`powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$cfg = Join-Path '$DataDir' 'config.ps1'; if (Test-Path \$cfg) { . \$cfg }; Get-ChildItem Env: | Where-Object { \$_.Name -like 'GF_*' } | ForEach-Object { Write-Output (\$_.Name + '=' + \$_.Value) }"`) do set "%%A"
set GF_IS_CHILD_INSTANCE=true
if not defined GF_BASE_DIR set GF_BASE_DIR=%DATA_DIR%
node "%DATA_DIR%\runtime\index.js" %*
"@ | Set-Content -Encoding ASCII $launcherPath
Write-Host "  Launcher created: $launcherPath"
Write-Host

# ── Step 7: Create bootstrap.bat (guided first-run entry) ────────────────────
$bootstrapPath = Join-Path $BinDir "bootstrap.bat"
@"
@echo off
rem GreenFrog Bootstrap -- Guided First-Run Setup
rem Double-click this file to configure and start GreenFrog.
title GreenFrog Setup

echo ============================================================
echo   GreenFrog -- First-Run Setup
echo ============================================================
echo.

set SCRIPT_DIR=%~dp0
for %%I in ("%SCRIPT_DIR%..") do set DATA_DIR=%%~fI
set CONFIG_FILE=%DATA_DIR%\config.ps1
if not exist "%CONFIG_FILE%" (
    echo   ERROR: GreenFrog is not installed yet.
    echo   Run install.ps1 first.
    pause
    exit /b 1
)

rem Check if enrollment URL is already configured
powershell -NonInteractive -ExecutionPolicy Bypass -Command "& { . '%CONFIG_FILE%'; if (\$env:GF_ENROLLMENT_URL) { exit 0 } else { exit 1 } }" >nul 2>&1
if %errorlevel% == 0 (
    echo   Enrollment URL is already configured.
    goto :launch
)

echo   Your enrollment URL is the address of your GreenFrog server.
echo   It looks like: https://your-server.example.com/api/distribution/enroll
echo   Your administrator will provide this URL.
echo.
set /p ENROLLMENT_URL="  Enter enrollment URL: "

if "%ENROLLMENT_URL%" == "" (
    echo.
    echo   No URL entered. You can set it later by editing:
    echo   %CONFIG_FILE%
    echo.
    pause
    exit /b 0
)

rem Write the URL to config
powershell -NonInteractive -ExecutionPolicy Bypass -Command "Add-Content -Encoding UTF8 '%CONFIG_FILE%' \"`n`$env:GF_ENROLLMENT_URL = '%ENROLLMENT_URL%'\""
echo.
echo   Enrollment URL saved.

:launch
echo.
echo ============================================================
echo   Starting GreenFrog...
echo ============================================================
echo.
call "%DATA_DIR%\bin\greenfrog.bat"
"@ | Set-Content -Encoding ASCII $bootstrapPath
Write-Host "  Bootstrap created: $bootstrapPath"
Write-Host

# ── Step 8: Add to PATH ───────────────────────────────────────────────────────
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$BinDir*") {
    try {
        [System.Environment]::SetEnvironmentVariable(
            "Path",
            "$userPath;$BinDir",
            "User"
        )
        Write-Host "  Added $BinDir to user PATH."
        Write-Host "  Restart your terminal for PATH changes to take effect."
    } catch {
        Write-Warning "  Could not update PATH automatically. Add manually: $BinDir"
    }
} else {
    Write-Host "  $BinDir is already in user PATH."
}
Write-Host

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host $SEP
Write-Host "  Installation complete!"
Write-Host $SEP
Write-Host
Write-Host "  Next steps:"

if ($EnrollmentUrl) {
    Write-Host "    Enrollment URL is set. Open a new terminal and run: greenfrog"
    Write-Host "    GreenFrog will complete enrollment automatically on first launch."
} else {
    Write-Host "    Option A (guided setup):"
    Write-Host "      Double-click: $bootstrapPath"
    Write-Host
    Write-Host "    Option B (command line):"
    Write-Host "      Open a new terminal and run:"
    Write-Host "      greenfrog.bat (or greenfrog after restarting terminal)"
    Write-Host
    Write-Host "    To set enrollment URL manually, edit:"
    Write-Host "      $configFile"
}
Write-Host
Write-Host $SEP
