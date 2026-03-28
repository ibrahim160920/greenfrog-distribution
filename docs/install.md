# GreenFrog Child Runtime — Installation Guide

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
```

The installer creates `~/.greenfrog/` with the following layout:

```
~/.greenfrog/
├── runtime/        ← Node.js application files
├── bin/
│   └── greenfrog   ← Launch wrapper (add this dir to PATH)
├── logs/
├── identity/       ← Created on first launch
├── backflow/       ← Created on first launch
├── inheritance/    ← Created on first launch
├── config.sh       ← Edit this before first launch
└── public-key.pem  ← Manifest signature verification key
```

Add the launcher to your PATH (add to `~/.bashrc` or `~/.zshrc`):

```sh
export PATH="$HOME/.greenfrog/bin:$PATH"
```

### macOS

```sh
# 1. Extract the distribution bundle
tar -xzf greenfrog-vX.Y.Z-macos.tar.gz
cd greenfrog-vX.Y.Z-macos/

# 2. Run the installer
bash install.sh
```

Layout is identical to Linux. The installer detects your shell and prints the
exact command to add `~/.greenfrog/bin` to PATH for either `zsh` or `bash`.

### Windows

```powershell
# Extract the .zip bundle, then open PowerShell in the extracted folder:
powershell -File install.ps1
```

The installer creates `%APPDATA%\GreenFrog\` and adds
`%APPDATA%\GreenFrog\bin` to your user PATH automatically. Open a new
terminal after installation for the PATH change to take effect.

---

## Setting the Enrollment URL

Before first launch you must set the enrollment URL. This is the address of
your organization's GreenFrog mother-body server.

**Linux / macOS** — edit `~/.greenfrog/config.sh`:
```sh
export GF_ENROLLMENT_URL="https://your-server.example.com/api/distribution/enroll"
export GF_DISTRIBUTION_URL="https://your-server.example.com"
```

**Windows** — edit `%APPDATA%\GreenFrog\config.ps1`:
```powershell
$env:GF_ENROLLMENT_URL = "https://your-server.example.com/api/distribution/enroll"
$env:GF_DISTRIBUTION_URL = "https://your-server.example.com"
```

The enrollment URL and any required access code are provided by your
organization's administrator with your distribution package.

---

## First Boot and Automatic Enrollment

Once the enrollment URL is set, run `greenfrog` (or `greenfrog.bat` on
Windows). On first launch the runtime automatically:

1. Generates a unique instance identity (never sent in plaintext)
2. Contacts the enrollment endpoint
3. Receives a signed JWT credential
4. Saves the credential locally
5. Begins normal operation

No typing or copy-pasting of keys is required. Enrollment is completed in
one network round-trip. If enrollment fails (server unreachable, incorrect
URL), the process exits with an error message — simply correct the config
and run again.

---

## Manual Enrollment

If you prefer to enroll from the command line without the launcher:

```sh
# Linux / macOS
node ~/.greenfrog/runtime/index.js --enroll --url https://your-server.example.com/api/distribution/enroll

# Windows
node "%APPDATA%\GreenFrog\runtime\index.js" --enroll --url https://your-server.example.com/api/distribution/enroll
```

Or use the enroll script (if bundled):
```sh
node scripts/enroll.js --url https://your-server.example.com/api/distribution/enroll
```

---

## Verifying Installation

After enrollment you can verify the installation status:

```sh
# Check enrollment state and runtime info
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

If `enrollmentState` is `unregistered`, enrollment has not completed — check
your `GF_ENROLLMENT_URL` setting and re-run the launcher.

---

## Bundle Verification (optional)

All distribution bundles include a SHA-256 checksum file, a signed manifest,
and a standalone verification tool. The public key (`public-key.pem`) is the
**trust root** — it is distributed with every package and is what makes the
signature chain meaningful.

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

**Important:** The GitHub distribution repository is a delivery mechanism,
not a trust anchor. The Ed25519 public key (`public-key.pem`) is the trust
root. A valid signature proves the release was authorized by the operator who
holds the corresponding private key. See `docs/signature-verification.md` for
manual verification steps.

---

## Troubleshooting

### "Node.js is not installed" or version too old
Install or upgrade Node.js to version 22 or later. See System Requirements above.

### "GF_ENROLLMENT_URL is not set"
Edit `~/.greenfrog/config.sh` (Linux/macOS) or `%APPDATA%\GreenFrog\config.ps1`
(Windows) and set the `GF_ENROLLMENT_URL` variable. Obtain the URL from your
organization's administrator.

### "Enrollment failed: connection refused" or network error
- Confirm the server address is correct
- Check that the server is reachable: `curl https://your-server.example.com/api/distribution/status`
- Confirm your firewall allows outbound HTTPS (port 443) to the server

### "permission denied" on Linux/macOS
```sh
chmod +x ~/.greenfrog/bin/greenfrog
```

### "greenfrog: command not found"
The `bin/` directory is not on your PATH. Add it:
```sh
export PATH="$HOME/.greenfrog/bin:$PATH"
```
Then add this line permanently to your shell profile (`~/.bashrc` or `~/.zshrc`).

### SQLite lock error on startup
Another GreenFrog process is running. Stop all running instances:
```sh
pkill -f greenfrog   # Linux / macOS
```
Then retry.

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

## Security Model — Why Enrollment Cannot Be Skipped

Every child instance must register with the mother-body server before
entering normal operation. This is not optional for the following reasons:

1. **Identity**: The server issues a signed JWT tied to a unique instance ID.
   Without it the child cannot authenticate to any distribution endpoint.
2. **Credential binding**: The JWT is the only authentication mechanism for
   the inheritance and backflow APIs. There is no local-only mode.
3. **Integrity**: The enrollment handshake confirms the server has a matching
   record for this instance, preventing unauthorized instances from consuming
   updates or sending backflow data.

Enrollment is a one-time, automatic operation — it does not require any user
interaction beyond setting the enrollment URL.

---

## What Is and Is Not in the Package

### Included in every child package
- GreenFrog Node.js runtime (`runtime/`)
- Distribution identity and enrollment subsystem
- Inheritance (update) client
- Backflow (telemetry) client
- Distribution server routes (for local API access)
- Public key for manifest verification (`public-key.pem`)
- Platform-specific installer script
- Config template

### NOT included (mother-body only)
- Packaging and signing infrastructure (`scripts/package-child.js`, `sign-manifest.js`)
- Mother private signing key (`keys/mother-private.pem`)
- OwnerKernel, TrustedSelector, CapabilityUnit (internal capability promotion modules)
- Evolution scheduler and source repository sync
- Any module matching the pattern `mother_*`, `evolution_*`, `source_repo_*`, `owner_kernel*`

The absence of mother-only modules is verified by `scripts/package-child.js` at
build time (exits with code 2 on any violation) and by `build-child-release.js`
at release time (security audit step).
