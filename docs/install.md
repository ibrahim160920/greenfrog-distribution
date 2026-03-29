# GreenFrog — Installation Guide

## System Requirements

| Requirement | Minimum |
|-------------|---------|
| Node.js | Linux/macOS: 24.x for current v1.4.0 bundles; Windows: installer provisions a local runtime |
| macOS | 11 (Big Sur) or later |
| Linux | Any distribution with glibc 2.17+ |
| Windows | Windows 10 or later |
| RAM | 512 MB available |
| Disk | 200 MB free |

Check your Node.js version on Linux/macOS:
```sh
node --version   # must print v24.x.x for the current v1.4.0 Linux/macOS bundles
```

If Node.js is missing or outdated on Linux/macOS, install Node.js 24.x from:
- https://nodejs.org/en/download/releases/

---

## Installation

### Linux

```sh
# 1. Extract the distribution bundle
tar -xzf greenfrog-vX.Y.Z-linux.tar.gz
cd greenfrog-vX.Y.Z-linux/

# 2. Run the installer
bash install.sh

# 3. Add to PATH (one-time — the installer prints the exact command)
echo 'export PATH="/path/to/GreenFrog/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 4. Start GreenFrog
greenfrog
```

By default the installer creates a `GreenFrog/` folder **next to** the extracted bundle:

```
/home/user/Downloads/
├── greenfrog-vX.Y.Z-linux/   ← extracted bundle (can delete after install)
│   ├── install.sh
│   ├── index.js
│   └── ...
└── GreenFrog/                 ← install destination
    ├── runtime/               ← Node.js application files
    ├── bin/
    │   └── greenfrog          ← launch wrapper
    ├── logs/
    ├── identity/              ← created on first launch
    ├── backflow/              ← created on first launch
    ├── inheritance/           ← created on first launch
    ├── config.sh              ← optional: advanced configuration
    └── public-key.pem         ← manifest signature verification key
```

Override the default with `--data-dir`:
```sh
bash install.sh --data-dir /opt/greenfrog
```

### macOS

```sh
# 1. Extract the distribution bundle
tar -xzf greenfrog-vX.Y.Z-macos.tar.gz
cd greenfrog-vX.Y.Z-macos/

# 2. Run the installer
bash install.sh

# 3. Add to PATH (one-time — the installer prints the exact command)
echo 'export PATH="/path/to/GreenFrog/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 4. Start GreenFrog
greenfrog
```

Same layout as Linux — installs to a `GreenFrog/` folder next to the extracted bundle.
Override with `--data-dir`:
```sh
bash install.sh --data-dir ~/Applications/GreenFrog
```

### Windows

Extract the `.zip` bundle, then **double-click `bootstrap.bat`**. Windows uses a
local Node runtime, so the installer does not depend on your system `node`.
It installs GreenFrog, starts the runtime, waits for `http://127.0.0.1:18889/health`,
and opens the browser automatically when the local UI is ready.

Or run the installer directly from PowerShell:
```powershell
powershell -File install.ps1
```

By default the installer creates a `GreenFrog\` folder **next to** the extracted bundle:

```
D:\
├── greenfrog-vX.Y.Z-windows\   ← extracted bundle (can delete after install)
│   ├── bootstrap.bat
│   ├── install.ps1
│   ├── index.js
│   └── ...
└── GreenFrog\                   ← install destination
    ├── runtime\
    ├── bin\
    │   └── greenfrog.bat        ← launch wrapper
    ├── logs\
    ├── identity\
    ├── config.ps1
    └── public-key.pem
```

The installer adds `GreenFrog\bin` to your user PATH automatically.
Open a new terminal after installation for the PATH change to take effect.

Override the default with `--data-dir`:
```powershell
powershell -File install.ps1 -DataDir C:\Tools\GreenFrog
```

Then run:
```
greenfrog
```
(or double-click `GreenFrog\bin\bootstrap.bat`)

---

## First Launch

On first launch, GreenFrog:

1. Generates a unique local identity (stored in `GreenFrog/identity/`)
2. Creates a locally-signed credential
3. Starts the agent runtime at `http://localhost:18889`
4. Opens the web interface in your browser (automatic when launched via `bootstrap.bat`)

**No server configuration is required.** GreenFrog runs in personal mode by
default — it initializes itself locally and starts immediately.

---

## AI Provider Configuration

Personal mode and AI model connectivity are separate concerns:

- Personal mode means you do not need a GreenFrog distribution server.
- To use cloud models, you still need to configure an AI provider.
- If you want fully local inference instead, use a local provider such as Ollama.

### Profile A: quan2go / capi relay

Use this profile when your key is for `https://capi.quan2go.com/openai` and the
relay expects `api-key` authentication plus the Responses API.

Linux / macOS (`GreenFrog/config.sh`):

```sh
export OPENAI_API_KEY="your-relay-key"
export OPENAI_BASE_URL="https://capi.quan2go.com/openai"
export OPENAI_MODEL="gpt-5.4"
export OPENAI_USE_RESPONSES_API="true"
export OPENAI_AUTH_MODE="apikey"
export OPENAI_REASONING_EFFORT="high"
export OPENAI_DISABLE_RESPONSE_STORAGE="true"
```

Windows (`GreenFrog/config.ps1`):

```powershell
$env:OPENAI_API_KEY = "your-relay-key"
$env:OPENAI_BASE_URL = "https://capi.quan2go.com/openai"
$env:OPENAI_MODEL = "gpt-5.4"
$env:OPENAI_USE_RESPONSES_API = "true"
$env:OPENAI_AUTH_MODE = "apikey"
$env:OPENAI_REASONING_EFFORT = "high"
$env:OPENAI_DISABLE_RESPONSE_STORAGE = "true"
```

### Profile B: private / self-hosted OpenAI-compatible relay

Use this profile when you have your own relay host, for example
`http://your-relay-host:3000/openai`.

Linux / macOS (`GreenFrog/config.sh`):

```sh
export OPENAI_API_KEY="your-relay-key"
export OPENAI_BASE_URL="http://your-relay-host:3000/openai"
export OPENAI_MODEL="your-relay-model"
export OPENAI_USE_RESPONSES_API="true"
export OPENAI_AUTH_MODE="bearer"
```

Windows (`GreenFrog/config.ps1`):

```powershell
$env:OPENAI_API_KEY = "your-relay-key"
$env:OPENAI_BASE_URL = "http://your-relay-host:3000/openai"
$env:OPENAI_MODEL = "your-relay-model"
$env:OPENAI_USE_RESPONSES_API = "true"
$env:OPENAI_AUTH_MODE = "bearer"
```

Compatibility notes:

- `OPENAI_AUTH_MODE="bearer"` is the standard OpenAI-compatible default.
- If your relay expects `api-key: <token>` instead, change `OPENAI_AUTH_MODE` to `apikey`.
- If your relay expects a custom auth header, set `OPENAI_AUTH_MODE="raw"`, `OPENAI_AUTH_HEADER="x-auth-token"`, and `OPENAI_AUTH_SCHEME="Token"`.
- If your relay only supports `chat/completions`, leave `OPENAI_USE_RESPONSES_API` unset.
- `OPENAI_EXTRA_HEADERS` accepts a JSON object string for relay-specific headers.

After editing the config file, restart GreenFrog.

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
On Linux/macOS, install or upgrade to Node.js 24.x. The current v1.4.0 distribution bundles native modules built for the Node 24 ABI. On Windows, the installer provisions a matching local runtime automatically.

### "permission denied" on Linux/macOS
```sh
chmod +x /path/to/GreenFrog/bin/greenfrog
```

### "greenfrog: command not found"
The `bin/` directory is not on your PATH. The installer prints the exact
`echo 'export PATH=...'` command to run — copy and run it. Then `source` your
shell profile or open a new terminal.

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

# Or set permanently in GreenFrog/config.sh:
export GF_ENROLLMENT_URL="https://your-server.example.com/api/distribution/enroll"
export GF_DISTRIBUTION_URL="https://your-server.example.com"
```

```powershell
# Windows: in GreenFrog\config.ps1:
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
# Remove the install directory (wherever GreenFrog was installed)
rm -rf /path/to/GreenFrog

# Remove from PATH (edit ~/.bashrc or ~/.zshrc and delete the GreenFrog export line)
```

### Windows
```powershell
# Remove the install directory
Remove-Item -Recurse -Force "C:\path\to\GreenFrog"

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
