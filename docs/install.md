# GreenFrog — Installation Guide

## System Requirements

| Requirement | Minimum |
|-------------|---------|
| Node.js | 22 or later |
| macOS | 11 (Big Sur) or later |
| Linux | Any distribution with glibc 2.17+ |
| Windows | Windows 10 or later |
| RAM | 512 MB available |
| Disk | 200 MB free |

Check your Node.js version:
```sh
node --version   # must print v22.x.x or higher
```

If Node.js is missing or outdated:
- **macOS**: `brew install node` or https://nodejs.org/en/download/
- **Linux (Ubuntu/Debian)**: `sudo apt-get install nodejs npm`
- **Linux (Fedora/RHEL)**: `sudo dnf install nodejs`
- **Windows**: `winget install OpenJS.NodeJS` or https://nodejs.org/en/download/

---

## Installation

### Linux

```sh
# 1. Extract the distribution bundle
tar -xzf greenfrog-vX.Y.Z-linux.tar.gz
cd greenfrog-vX.Y.Z-linux/

# 2. Run the installer
bash install.sh

# 3. Add to PATH (one-time)
echo 'export PATH="$HOME/.greenfrog/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 4. Start GreenFrog
greenfrog
```

The installer creates `~/.greenfrog/` with the following layout:

```
~/.greenfrog/
├── runtime/        ← Node.js application files
├── bin/
│   └── greenfrog   ← Launch wrapper
├── logs/
├── identity/       ← Created on first launch
├── backflow/       ← Created on first launch
├── inheritance/    ← Created on first launch
├── config.sh       ← Optional: advanced configuration
└── public-key.pem  ← Manifest signature verification key
```

### macOS

```sh
# 1. Extract the distribution bundle
tar -xzf greenfrog-vX.Y.Z-macos.tar.gz
cd greenfrog-vX.Y.Z-macos/

# 2. Run the installer
bash install.sh

# 3. Add to PATH (one-time — the installer prints the exact command)
echo 'export PATH="$HOME/.greenfrog/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 4. Start GreenFrog
greenfrog
```

### Windows

```powershell
# Extract the .zip bundle, then double-click bootstrap.bat
# Or from PowerShell:
powershell -File install.ps1
```

The installer creates `%APPDATA%\GreenFrog\` and adds
`%APPDATA%\GreenFrog\bin` to your user PATH automatically.
Open a new terminal after installation for the PATH change to take effect.

Then run:
```
greenfrog
```
(or double-click `bootstrap.bat`)

---

## First Launch

On first launch, GreenFrog:

1. Generates a unique local identity (stored in `~/.greenfrog/identity/`)
2. Creates a locally-signed credential
3. Starts the agent runtime at `http://localhost:18889`
4. Opens the web interface in your browser

**No server configuration is required.** GreenFrog runs in personal mode by
default — it initializes itself locally and starts immediately.

---

## Verifying Installation

After the first successful launch, you can check the runtime status:

```sh
curl http://localhost:18889/api/distribution/status
```

Expected response:
```json
{
  "ok": true,
  "runMode": "child",
  "enrollmentState": "enrolled",
  "instanceId": "abc123...",
  "platform": "linux",
  "credentialPresent": true,
  "publicKeyPresent": true
}
```

---

## Bundle Verification (optional but recommended)

All distribution bundles include a SHA-256 checksum file, a signed manifest,
and a standalone verification tool. Verification confirms the bundle was
produced and authorized by the GreenFrog operator.

```sh
# Verify checksum (Linux / macOS)
sha256sum -c checksums/SHA256SUMS

# Verify manifest signature using the bundled tool (no npm install required)
node tools/verify-release.js \
  --manifest manifests/1.4.0/linux.json \
  --bundle   linux/greenfrog-v1.4.0-linux.tar.gz

# With explicit public key:
node tools/verify-release.js \
  --manifest manifests/1.4.0/linux.json \
  --public-key public-key.pem
```

Expected output: `VERIFIED` with key ID `c4ba4d8eeeb0ec21`.

The public key (`public-key.pem`) is the trust root — not the GitHub repository.
See [docs/signature-verification.md](signature-verification.md) for manual steps.

---

## Troubleshooting

### "Node.js is not installed" or version too old
Install or upgrade Node.js to version 22 or later. See System Requirements above.

### "permission denied" on Linux/macOS
```sh
chmod +x ~/.greenfrog/bin/greenfrog
```

### "greenfrog: command not found"
The `bin/` directory is not on your PATH. Add it:
```sh
export PATH="$HOME/.greenfrog/bin:$PATH"
```
Add this line permanently to your shell profile (`~/.bashrc` or `~/.zshrc`).

### SQLite lock error on startup
Another GreenFrog process is already running. Stop all running instances:
```sh
pkill -f greenfrog   # Linux / macOS
```
Then retry.

### "index.js not found in runtime bundle"
The bundle was incomplete or extracted incorrectly. Re-download and re-extract.

---

## Connecting to a Managed Server (Organizations)

For organization deployments where a central GreenFrog distribution server
provides signed capability updates and governed data sharing:

```sh
# Linux / macOS: pass the URL at launch (one-time)
greenfrog --enrollment-url https://your-server.example.com/api/distribution/enroll

# Or set permanently in ~/.greenfrog/config.sh:
export GF_ENROLLMENT_URL="https://your-server.example.com/api/distribution/enroll"
export GF_DISTRIBUTION_URL="https://your-server.example.com"
```

```powershell
# Windows: in %APPDATA%\GreenFrog\config.ps1:
$env:GF_ENROLLMENT_URL = "https://your-server.example.com/api/distribution/enroll"
$env:GF_DISTRIBUTION_URL = "https://your-server.example.com"
```

Once the enrollment URL is set, GreenFrog connects and enrolls automatically
on the next launch — no further configuration required.

Your organization's administrator will provide the enrollment URL.

---

## Uninstallation

### Linux / macOS
```sh
# Remove the runtime and data directory
rm -rf ~/.greenfrog

# Remove from PATH (edit ~/.bashrc or ~/.zshrc and remove the export line)
```

### Windows
```powershell
# Remove the data directory
Remove-Item -Recurse -Force "$env:APPDATA\GreenFrog"

# Remove from user PATH (System Properties → Environment Variables)
# Or via PowerShell:
$p = [System.Environment]::GetEnvironmentVariable("Path", "User")
$p = ($p -split ";" | Where-Object { $_ -notlike "*GreenFrog*" }) -join ";"
[System.Environment]::SetEnvironmentVariable("Path", $p, "User")
```

---

## What Is and Is Not in the Package

### Included in every distribution bundle
- GreenFrog Node.js runtime (`runtime/`)
- Distribution identity subsystem (local and remote enrollment)
- Inheritance (update) client
- Backflow (telemetry) client
- Public key for manifest verification (`public-key.pem`)
- Platform-specific installer script
- Config template (all fields optional for personal use)

### NOT included (mother-body only)
- Packaging and signing infrastructure
- Mother private signing key
- Internal capability promotion and governance modules
- Evolution scheduler and source repository sync

The absence of mother-only modules is verified at build time.
