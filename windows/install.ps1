# GreenFrog Windows Installer
# ============================================================
# Installs the GreenFrog child runtime from the extraction directory.
# Default install location: sibling of the extraction directory named GreenFrog.
#   e.g. extracted to D:\greenfrog-v1.4.0-windows\  ->  installs to D:\GreenFrog
#
# Usage:
#   powershell -File install.ps1 [-EnrollmentUrl <url>] [-DataDir <path>]
#
# Parameters:
#   -EnrollmentUrl <url>   Mother-body enrollment endpoint (optional).
#                          Writes to config.ps1 automatically.
#   -DataDir <path>        Override install directory.
#                          Default: <parent of extraction dir>\GreenFrog
# ============================================================
param(
    [string]$EnrollmentUrl = "",
    [string]$DataDir = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PowerShellExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path $PowerShellExe)) {
    $PowerShellExe = "powershell.exe"
}
$RequiredNodeMajorFile = Join-Path $ScriptDir "runtime-node-major.txt"
$RequiredNodeMajor = if (Test-Path $RequiredNodeMajorFile) {
    [int](Get-Content $RequiredNodeMajorFile -Raw).Trim()
} else {
    24
}

# ---- Default paths -----------------------------------------------------------
# Install alongside the extraction directory -- visible, non-system, predictable.
# Explicit -DataDir or GF_BASE_DIR environment variable takes priority.
if (-not $DataDir) {
    $ParentDir = Split-Path -Parent $ScriptDir
    $DataDir = if ($env:GF_BASE_DIR) { $env:GF_BASE_DIR } else { Join-Path $ParentDir "GreenFrog" }
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

# ---- Step 1: Check required Node.js major -----------------------------------
Write-Host "  Checking Node.js..."
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Write-Host
    Write-Host "  ERROR: Node.js is not installed."
    Write-Host
    Write-Host "  Install Node.js $RequiredNodeMajor.x from:"
    Write-Host
    Write-Host "    https://nodejs.org/en/download/releases/"
    Write-Host
    exit 1
}

$nodeVersion = (node --version).TrimStart('v')
$nodeMajor   = [int]($nodeVersion.Split('.')[0])
if ($nodeMajor -ne $RequiredNodeMajor) {
    Write-Host
    Write-Host "  ERROR: Node.js $nodeVersion detected. This distribution currently requires Node.js $RequiredNodeMajor.x."
    Write-Host "  Reason: bundled native modules are built for the Node $RequiredNodeMajor ABI."
    Write-Host "  Install Node.js $RequiredNodeMajor.x from: https://nodejs.org/en/download/releases/"
    Write-Host
    exit 1
}
Write-Host "  Node.js v$nodeVersion -- OK"
Write-Host

# ---- Step 2: Create directory structure -------------------------------------
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

# ---- Step 3: Copy runtime files ---------------------------------------------
# Source is always the extraction directory (where install.ps1 lives).
# NEVER use ".\*" -- that depends on the current working directory and copies
# system files when launched from System32 or any non-extraction directory.
Write-Host "  Copying runtime files..."
$runtimeSubdir = Join-Path $ScriptDir "runtime"
if (Test-Path (Join-Path $ScriptDir "index.js")) {
    # Standard bundle layout: runtime files live alongside install.ps1.
    # Do not treat a module directory named "runtime/" as the package root.
    $excludeNames = [System.Collections.Generic.HashSet[string]]@(
        "install.ps1", "bootstrap.bat", "public-key.pem"
    )
    Get-ChildItem -Path $ScriptDir |
        Where-Object { -not $excludeNames.Contains($_.Name) } |
        ForEach-Object { Copy-Item -Recurse -Force $_.FullName $RuntimeDir }
} elseif (Test-Path (Join-Path $runtimeSubdir "index.js")) {
    # Explicit runtime/ subdirectory bundle layout
    Copy-Item -Recurse -Force (Join-Path $runtimeSubdir "*") $RuntimeDir
} else {
    Write-Host
    Write-Host "  ERROR: index.js not found in the extracted package."
    Write-Host "  The Windows ZIP may be incomplete or corrupted."
    Write-Host
    exit 1
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

# ---- Step 4: Copy public key ------------------------------------------------
# Key lives in the extraction directory alongside install.ps1
$keySource = Join-Path $ScriptDir "public-key.pem"
if (-not (Test-Path $keySource)) {
    $keySource = Join-Path (Split-Path $ScriptDir -Parent) "public-key.pem"
}
$keyDest   = Join-Path $DataDir "public-key.pem"
if (Test-Path $keySource) {
    Copy-Item -Force $keySource $keyDest
    Write-Host "  Public key installed."
} else {
    Write-Warning "  public-key.pem not found -- manifest signature verification will be unavailable."
}
Write-Host

# ---- Step 5: Write config (preserving existing) -----------------------------
$configFile = Join-Path $DataDir "config.ps1"
if (-not (Test-Path $configFile)) {
    $templatePath = Join-Path $ScriptDir "config.ps1.template"
    if (-not (Test-Path $templatePath)) {
        $templatePath = Join-Path $RuntimeDir "config.ps1.template"
    }
    if (Test-Path $templatePath) {
        Copy-Item -Force $templatePath $configFile
    } else {
        @'
# GreenFrog Configuration
# Personal mode is the default -- no server configuration required.
# GreenFrog runs locally and initializes its own identity on first launch.
#
# To connect to a managed distribution server (organizations / advanced use):
# $env:GF_ENROLLMENT_URL = "https://your-server.example.com/api/distribution/enroll"
# $env:GF_DISTRIBUTION_URL = "https://your-server.example.com"
#
# $env:GF_LOCALE = ""  # Leave unset to auto-detect system locale
'@ | Set-Content -Encoding UTF8 $configFile
    }
    Write-Host "  Config created at: $configFile"
}

# Write enrollment URL if provided via -EnrollmentUrl
if ($EnrollmentUrl) {
    $lines = Get-Content $configFile -Raw
    if ($lines -match 'GF_ENROLLMENT_URL') {
        $lines = $lines -replace '(?m).*GF_ENROLLMENT_URL.*', "`$env:GF_ENROLLMENT_URL = `"$EnrollmentUrl`""
        Set-Content -Encoding UTF8 $configFile $lines
    } else {
        Add-Content -Encoding UTF8 $configFile "`n`$env:GF_ENROLLMENT_URL = `"$EnrollmentUrl`""
    }
    Write-Host "  Enrollment URL written to config: $EnrollmentUrl"
}
Write-Host

# ---- Step 6: Create launch wrappers (greenfrog.ps1 + greenfrog.bat) ---------
$launcherPs1Path = Join-Path $BinDir "greenfrog.ps1"
@'
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ForwardArgs
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$dataDir = Split-Path -Parent $scriptDir
$configPath = Join-Path $dataDir "config.ps1"
$runtimeEntry = Join-Path $dataDir "runtime\index.js"
$requiredNodeMajorFile = Join-Path $dataDir "runtime\runtime-node-major.txt"
$requiredNodeMajor = if (Test-Path $requiredNodeMajorFile) {
    [int](Get-Content $requiredNodeMajorFile -Raw).Trim()
} else {
    24
}

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Write-Host
    Write-Host "ERROR: Node.js $requiredNodeMajor.x is required but was not found."
    Write-Host "Install from: https://nodejs.org/en/download/releases/"
    Write-Host
    exit 1
}

$nodeVersion = (& node --version).Trim().TrimStart('v')
$nodeMajor = [int]($nodeVersion.Split('.')[0])
if ($nodeMajor -ne $requiredNodeMajor) {
    Write-Host
    Write-Host "ERROR: Node.js $nodeVersion detected. This distribution currently requires Node.js $requiredNodeMajor.x."
    Write-Host "Reason: bundled native modules are built for the Node $requiredNodeMajor ABI."
    Write-Host "Install Node.js $requiredNodeMajor.x from: https://nodejs.org/en/download/releases/"
    Write-Host
    exit 1
}

if (Test-Path $configPath) {
    . $configPath
}

$env:GF_IS_CHILD_INSTANCE = "true"
if (-not $env:GF_BASE_DIR) {
    $env:GF_BASE_DIR = $dataDir
}

& node $runtimeEntry @ForwardArgs
exit $LASTEXITCODE
'@ | Set-Content -Encoding UTF8 $launcherPs1Path
Write-Host "  Launcher created: $launcherPs1Path"

$launcherPath = Join-Path $BinDir "greenfrog.bat"
($(
@'
@echo off
rem GreenFrog Child Runtime Launcher
rem Auto-generated by installer -- do not edit manually
set SCRIPT_DIR=%~dp0
set "POWERSHELL_EXE=__POWERSHELL_EXE__"
"%POWERSHELL_EXE%" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%SCRIPT_DIR%greenfrog.ps1" %*
exit /b %ERRORLEVEL%
'@
).Replace('__POWERSHELL_EXE__', $PowerShellExe)) | Set-Content -Encoding ASCII $launcherPath
Write-Host "  Launcher created: $launcherPath"
Write-Host

# ---- Step 7: Create bootstrap.bat (guided first-run entry) ------------------
$bootstrapPath = Join-Path $BinDir "bootstrap.bat"
@"
@echo off
rem GreenFrog Bootstrap -- First-Run Launcher
rem Double-click this file to start GreenFrog.
title GreenFrog

echo ============================================================
echo   GreenFrog
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

echo   Starting GreenFrog...
echo   On first launch, local identity is initialized automatically.
echo   No server configuration required for personal use.
echo.

:launch
call "%DATA_DIR%\bin\greenfrog.bat"
"@ | Set-Content -Encoding ASCII $bootstrapPath
Write-Host "  Bootstrap created: $bootstrapPath"
Write-Host

# ---- Step 8: Add to PATH ----------------------------------------------------
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

# ---- Summary ----------------------------------------------------------------
Write-Host $SEP
Write-Host "  Installation complete!"
Write-Host $SEP
Write-Host
Write-Host "  Install location : $DataDir"
Write-Host
Write-Host "  Next steps:"

if ($EnrollmentUrl) {
    Write-Host "    Enrollment URL configured. GreenFrog will connect to your server on first launch."
    Write-Host "    Open a new terminal and run: greenfrog"
} else {
    Write-Host "    GreenFrog is ready. Start it now:"
    Write-Host
    Write-Host "      Double-click: $bootstrapPath"
    Write-Host "      Or open a new terminal and run: greenfrog"
    Write-Host
    Write-Host "    On first launch, GreenFrog initializes its local identity automatically."
    Write-Host "    No server configuration is required for personal use."
    Write-Host
    Write-Host "    For managed/organization deployments, run:"
    Write-Host "      greenfrog --enrollment-url https://your-server/api/distribution/enroll"
}
Write-Host
Write-Host $SEP
