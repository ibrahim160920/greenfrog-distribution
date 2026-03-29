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
$RequiredNodeVersionFile = Join-Path $ScriptDir "runtime-node-version.txt"
$RequiredNodeVersion = if (Test-Path $RequiredNodeVersionFile) {
    (Get-Content $RequiredNodeVersionFile -Raw).Trim().TrimStart('v')
} else {
    "24.14.0"
}
$NodeRuntimeZipOverride = $env:GF_NODE_RUNTIME_ZIP

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
$BundledNodeSource = Join-Path $ScriptDir "node-runtime\node.exe"
$BundledNodeDir = Join-Path $RuntimeDir "node-runtime"
$BundledNodeExe = Join-Path $BundledNodeDir "node.exe"
$NodeRuntimeZipUrl = "https://nodejs.org/dist/v$RequiredNodeVersion/node-v$RequiredNodeVersion-win-x64.zip"

$SEP = "=" * 60

Write-Host $SEP
Write-Host "  GreenFrog -- Child Runtime Installer (Windows)"
Write-Host $SEP
Write-Host

# ---- Step 1: Resolve local runtime source -----------------------------------
Write-Host "  Checking local runtime bootstrap..."
if (Test-Path $BundledNodeSource) {
    Write-Host "  Packaged node-runtime found in the extracted bundle."
} else {
    Write-Host "  Packaged node-runtime not embedded in this ZIP."
    Write-Host "  GreenFrog will provision Node.js v$RequiredNodeVersion locally during install."
}
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

# ---- Step 3.5: Provision local node runtime ---------------------------------
function Install-NodeRuntimeFromZip([string]$zipPath, [string]$destinationExe) {
    $extractRoot = Join-Path $env:TEMP ("gf-node-extract-" + [guid]::NewGuid().ToString('N'))
    try {
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
        $extractedNode = Get-ChildItem -Path $extractRoot -Recurse -Filter node.exe | Select-Object -First 1
        if (-not $extractedNode) {
            throw "node.exe not found inside runtime ZIP"
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $destinationExe -Parent) | Out-Null
        Copy-Item -Force $extractedNode.FullName $destinationExe
    } finally {
        Remove-Item -Recurse -Force $extractRoot -ErrorAction SilentlyContinue
    }
}

function Ensure-NodeRuntime([string]$destinationExe) {
    if (Test-Path $BundledNodeSource) {
        New-Item -ItemType Directory -Force -Path $BundledNodeDir | Out-Null
        Copy-Item -Force $BundledNodeSource $destinationExe
        return "packaged"
    }

    if (Test-Path $destinationExe) {
        $existingVersion = (& $destinationExe --version).Trim().TrimStart('v')
        if ($existingVersion -eq $RequiredNodeVersion) {
            return "existing"
        }
        Remove-Item -Force $destinationExe
    }

    $runtimeZip = Join-Path $env:TEMP ("gf-node-runtime-" + $RequiredNodeVersion + ".zip")
    $sourceLabel = ""
    if ($NodeRuntimeZipOverride -and (Test-Path $NodeRuntimeZipOverride)) {
        Copy-Item -Force $NodeRuntimeZipOverride $runtimeZip
        $sourceLabel = "override"
    } else {
        try {
            Invoke-WebRequest -Uri $NodeRuntimeZipUrl -OutFile $runtimeZip
        } catch {
            throw "failed to download $NodeRuntimeZipUrl"
        }
        $sourceLabel = "downloaded"
    }

    try {
        Install-NodeRuntimeFromZip $runtimeZip $destinationExe
    } finally {
        Remove-Item -Force $runtimeZip -ErrorAction SilentlyContinue
    }

    return $sourceLabel
}

$runtimeSource = Ensure-NodeRuntime $BundledNodeExe
if (-not (Test-Path $BundledNodeExe)) {
    Write-Host
    Write-Host "  ERROR: local node runtime could not be provisioned."
    Write-Host
    exit 1
}
$bundledNodeVersion = (& $BundledNodeExe --version).Trim().TrimStart('v')
Write-Host "  Local Node runtime ready ($runtimeSource): v$bundledNodeVersion"
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
$runtimeEntry = Join-Path $dataDir "runtime\entry.js"
$bundledNode = Join-Path $dataDir "runtime\node-runtime\node.exe"
if (-not (Test-Path $bundledNode)) {
    Write-Host
    Write-Host "ERROR: local node-runtime\\node.exe is missing from the GreenFrog install."
    Write-Host
    exit 1
}
if (-not (Test-Path $runtimeEntry)) {
    Write-Host
    Write-Host "ERROR: runtime\\entry.js is missing from the GreenFrog install."
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
if (-not $env:DATA_DIR) {
    $env:DATA_DIR = $dataDir
}

$resolvedArgs = @()
if ($ForwardArgs.Count -eq 0 -or $ForwardArgs[0].StartsWith('-')) {
    $resolvedArgs += 'start'
}
$resolvedArgs += $ForwardArgs

& $bundledNode $runtimeEntry @resolvedArgs
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
setlocal enabledelayedexpansion

echo ============================================================
echo   GreenFrog
echo ============================================================
echo.

set SCRIPT_DIR=%~dp0
for %%I in ("%SCRIPT_DIR%..") do set DATA_DIR=%%~fI
set CONFIG_FILE=%DATA_DIR%\config.ps1
set LOG_FILE=%DATA_DIR%\logs\startup.log
set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL_EXE%" set "POWERSHELL_EXE=powershell.exe"
set "APP_URL=http://127.0.0.1:18889/"
set "HEALTH_URL=http://127.0.0.1:18889/health"
if not exist "%CONFIG_FILE%" (
    echo   ERROR: GreenFrog is not installed yet.
    echo   Run install.ps1 first.
    pause
    exit /b 1
)

call :probe_health
if !errorlevel! equ 0 (
    echo   GreenFrog is already running.
    echo   Opening: %APP_URL%
    start "" "%APP_URL%"
    exit /b 0
)

echo   Starting GreenFrog...
echo   On first launch, local identity is initialized automatically.
echo   No server configuration required for personal use.
echo.
break > "%LOG_FILE%"
echo [bootstrap] Starting GreenFrog at %DATE% %TIME%>> "%LOG_FILE%"
start "GreenFrog" /min cmd /c ""%DATA_DIR%\bin\greenfrog.bat" >> "%LOG_FILE%" 2>&1"

echo   Waiting for http://127.0.0.1:18889/ ...
for /l %%I in (1,1,30) do (
    call :probe_health
    if !errorlevel! equ 0 goto :ready
    >nul timeout /t 1 /nobreak
)

echo.
echo   ERROR: GreenFrog did not become reachable within 30 seconds.
echo   Startup log:
echo     %LOG_FILE%
if exist "%LOG_FILE%" (
    echo.
    echo   ----- startup.log (tail) -----
    "%POWERSHELL_EXE%" -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Get-Content -Path '%LOG_FILE%' -Tail 60" 2>nul
    echo   ----- end startup.log -----
)
echo.
pause
exit /b 1

:ready
echo   GreenFrog is running.
echo   Opening: %APP_URL%
start "" "%APP_URL%"
exit /b 0

:probe_health
"%POWERSHELL_EXE%" -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "try { $r = Invoke-WebRequest -UseBasicParsing -Uri '%HEALTH_URL%' -TimeoutSec 2 -ErrorAction Stop; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
exit /b %ERRORLEVEL%
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
