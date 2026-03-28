# GreenFrog Child Instance — Upgrade Guide

## How Upgrades Work

GreenFrog child instances receive capability updates automatically from the mother-body.
The process is fully automatic and requires no manual intervention once enrolled.

### The Pull Model

The child instance periodically polls the mother-body distribution server:

```
GET /api/distribution/inheritance/latest
```

The server returns a signed **release manifest** describing the latest available capability bundle.
The child verifies the manifest, downloads the bundle, verifies its hash, then applies it.

### What Is Applied

An inheritance bundle is a set of capability modules (skills, workflows, configuration) that
the mother-body has promoted for distribution. It does **not** replace the child runtime itself —
only the inherited capabilities layer.

The runtime executable (`index.js`) is only updated by reinstalling (see below).

---

## Automatic Upgrade Flow

1. **Manifest fetch** — child downloads `manifest.json` for the latest version
2. **Signature verification** — Ed25519 signature checked against the bundled `public-key.pem`
3. **Key ID check** — manifest `keyId` must match the fingerprint of the trusted public key
4. **Compatibility check** — `compatibilityConstraint` (semver range) checked against installed version
5. **Bundle download** — bundle downloaded from `downloadUrl` in the manifest
6. **Hash verification** — SHA-256 of downloaded content checked against `bundleHash`
7. **Archive current** — current capabilities archived before applying new bundle
8. **Apply** — new bundle extracted; child restarts the capability layer

If any step fails, the upgrade is aborted and the existing capabilities remain intact.

---

## Checking the Current Inheritance Version

```bash
# Linux / macOS
greenfrog --status

# or via the API
curl http://localhost:18889/api/distribution/status
```

The response includes `inheritanceVersion` and `inheritanceLastAppliedAt`.

---

## Forcing an Upgrade Check

The child normally checks on a timer. To trigger an immediate check:

```bash
# Via API (requires authentication)
curl -X POST http://localhost:18889/api/distribution/inheritance/check \
  -H "Authorization: Bearer <your-token>"
```

---

## Manual Upgrade (Runtime Executable)

The child runtime executable is **not** updated automatically. To update the runtime:

### Linux / macOS

```bash
# Download the latest installer
curl -fsSL https://your-distribution-server/linux/install.sh | bash -s -- \
  --enrollment-url "$(cat ~/.greenfrog/config.sh | grep GF_ENROLLMENT_URL | cut -d= -f2)"
```

Or download and inspect before running:

```bash
curl -fsSL -o install.sh https://your-distribution-server/linux/install.sh
bash install.sh --enrollment-url "$GF_ENROLLMENT_URL"
```

### Windows

```powershell
# Download and run the installer
Invoke-WebRequest -Uri "https://your-distribution-server/windows/install.ps1" -OutFile install.ps1
.\install.ps1 -EnrollmentUrl $env:GF_ENROLLMENT_URL
```

The installer preserves your existing configuration and only updates the runtime files.

---

## Rollback

If an upgrade causes problems, the previous capability bundle is archived automatically.
To roll back:

```bash
# List available archives (Linux/macOS)
ls ~/.greenfrog/update-cache/

# Restore previous (set to exact archive name)
cp -r ~/.greenfrog/update-cache/<previous-version>/* ~/.greenfrog/runtime/capabilities/
```

Then restart the instance.

---

## Compatibility Constraints

Each manifest includes a `compatibilityConstraint` field (semver range, e.g. `>=1.0.0 <2.0.0`).
If your installed runtime version is outside this range, the bundle is skipped until you
upgrade the runtime executable.

---

## Inheritance Modes

| Mode | Description |
|------|-------------|
| `stable` | Default. Apply bundles once they have passed the stability window. |
| `latest` | Apply bundles as soon as they are available (may be experimental). |
| `pinned` | Never apply new bundles automatically. Manual only. |

Set in `~/.greenfrog/config.sh`:

```bash
export GF_INHERITANCE_MODE=stable
```

---

## Uninstall

To fully remove the child instance:

### Linux / macOS

```bash
rm -rf ~/.greenfrog
# Remove launcher from PATH
rm -f ~/.local/bin/greenfrog
```

### Windows

```powershell
Remove-Item -Recurse -Force "$env:APPDATA\GreenFrog"
# Remove from PATH (if added)
$path = [Environment]::GetEnvironmentVariable("PATH", "User")
$path = ($path -split ";") | Where-Object { $_ -notlike "*GreenFrog*" } | Join-String -Separator ";"
[Environment]::SetEnvironmentVariable("PATH", $path, "User")
```
