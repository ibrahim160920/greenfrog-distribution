# GreenFrog

**A local-first personal AI agent runtime — verified, updatable, yours.**

This is the official public distribution of the GreenFrog child runtime.
It runs on your machine. Capability updates are signed by the operator and verified
by your instance before being applied. Your sessions and data stay local.

> **This repository distributes signed release artifacts, not source code.**
> Each file here is produced and signed by the GreenFrog release pipeline.
> See [What This Repository Is](#what-this-repository-is) for the full explanation.

---

## Download v1.4.0

| Platform | Bundle | Installer |
|----------|--------|-----------|
| **Linux** | [greenfrog-v1.4.0-linux.tar.gz](linux/greenfrog-v1.4.0-linux.tar.gz) | `bash install.sh` |
| **macOS** | [greenfrog-v1.4.0-macos.tar.gz](macos/greenfrog-v1.4.0-macos.tar.gz) | `bash install.sh` |
| **Windows** | [greenfrog-v1.4.0-windows.zip](windows/greenfrog-v1.4.0-windows.zip) | `install.ps1` or `bootstrap.bat` |

**Requires Node.js 22 or later.** Check: `node --version`

[Release Notes v1.4.0](release-notes/v1.4.0.md) · [All Releases](release-notes/index.md) · [Checksums](checksums/SHA256SUMS) · [Public Key](public-key.md) · [Verify](docs/signature-verification.md)

---

## Quick Start

**Step 1 — Download and verify**

```bash
# One-step: download the latest bundle for your platform (Linux / macOS)
curl -fsSL -O https://raw.githubusercontent.com/ibrahim160920/greenfrog-distribution/main/tools/download-latest.js
node download-latest.js                  # auto-detects your platform
```

Or download a specific version manually:

```bash
# Linux / macOS — specific version
curl -fsSL -O https://raw.githubusercontent.com/ibrahim160920/greenfrog-distribution/main/linux/greenfrog-v1.4.0-linux.tar.gz
curl -fsSL -O https://raw.githubusercontent.com/ibrahim160920/greenfrog-distribution/main/manifests/1.4.0/linux.json
curl -fsSL -O https://raw.githubusercontent.com/ibrahim160920/greenfrog-distribution/main/tools/verify-release.js
curl -fsSL -O https://raw.githubusercontent.com/ibrahim160920/greenfrog-distribution/main/public-key.pem

# Verify (requires Node.js 22+)
node verify-release.js --manifest linux.json --bundle greenfrog-v1.4.0-linux.tar.gz
```

Expected output: `VERIFIED` with key ID `c4ba4d8eeeb0ec21`.

**Step 2 — Install**

```bash
tar -xzf greenfrog-v1.4.0-linux.tar.gz
cd greenfrog-v1.4.0-linux/
bash install.sh
```

For Windows: extract the `.zip` and run `bootstrap.bat` (guided) or `install.ps1`.

**Step 3 — Start**

```bash
greenfrog
```

On first launch, GreenFrog initializes its local identity automatically — no server or configuration required for personal use.
See [Installation Guide](docs/install.md) for full details, troubleshooting, and Windows instructions.

---

## Verifying Your Download

This repository is a delivery mechanism. **The trust root is the Ed25519 signing key,
not this GitHub repository.**

Every release is signed with key ID `c4ba4d8eeeb0ec21`. To verify:

```bash
node tools/verify-release.js \
  --manifest manifests/1.4.0/linux.json \
  --bundle   linux/greenfrog-v1.4.0-linux.tar.gz \
  --public-key public-key.pem
```

The verification tool (`tools/verify-release.js`) is included in every release bundle
and requires only Node.js built-in modules — no `npm install` needed.

Full verification documentation: [docs/signature-verification.md](docs/signature-verification.md)
Public key fingerprint and algorithm: [public-key.md](public-key.md)

---

## How Updates Work

GreenFrog child instances receive capability updates automatically:

1. Your instance periodically checks the distribution server for new signed manifests
2. The signature and key ID are verified against the public key installed on your machine
3. The bundle hash is independently verified
4. Only if all checks pass is the update applied

Updates are pulled by your instance — nothing is pushed to you without your instance
requesting it. You can set the inheritance mode to `stable` (default), `security_only`, or
`disabled` in `~/.greenfrog/config.sh`.

Details: [docs/upgrade.md](docs/upgrade.md)

---

## What This Repository Is

GreenFrog uses a **mother / child** distribution model:

**What you download is a child instance.** It is a fully functional local AI agent
runtime. It runs on your hardware, uses your credentials, and keeps your sessions local.

**The mother body is not publicly distributed.** It is the governed system that
reviews, approves, and signs capability updates. You never interact with it directly —
it communicates with your instance through signed manifests and verifiable update bundles.

**Updates flow one way: from mother to child.** When new capabilities are approved,
your instance inherits them after verifying the signature. No update is applied without
passing the full verification chain.

**Experience data flows back with governance.** Your instance may contribute anonymized
experience data back to the system — this is how the mother body learns what works.
This contribution goes through a governed review process. Your data is **not** directly
shared with other users' instances, and other users' raw experience does not directly
enter your instance.

**Personal mode runs without a server.** For individual users, GreenFrog initializes
its own local identity on first launch — no server URL required. The runtime starts
and operates fully offline from any distribution server.

**Remote enrollment is optional.** If you connect GreenFrog to a managed distribution
server (organization deployments), enrollment is automatic once the server URL is configured.
This enables signed capability updates and governed backflow.

Full explanation: [docs/distribution-model.md](docs/distribution-model.md)

---

## Why GreenFrog?

Most AI tools run in someone else's cloud. GreenFrog runs locally:

- **Local execution** — your data and conversations stay on your machine
- **Governed updates** — capability improvements are approved, signed, and verifiable before they reach you
- **Isolated experience** — your instance does not directly share data or learn from other users' sessions
- **Transparent trust chain** — every release is signed with Ed25519; you can verify the signature yourself before running anything
- **Multi-language runtime** — first-run experience in English, German, Spanish, French, Italian, Japanese, Korean, Portuguese, Simplified Chinese, and Traditional Chinese

---

## Documentation

| Document | Description |
|----------|-------------|
| [Installation Guide](docs/install.md) | Full install steps, config, troubleshooting |
| [Upgrade Guide](docs/upgrade.md) | How automatic updates work, manual upgrade, rollback |
| [Signature Verification](docs/signature-verification.md) | Verifying releases manually |
| [Trust Model](docs/trust-model.md) | Why the signing key is the trust root |
| [Distribution Model](docs/distribution-model.md) | Mother / child / inheritance / backflow explained |
| [Product Overview](docs/overview.md) | What GreenFrog is, who it's for, capability boundaries |
| [Downloads Guide](docs/downloads.md) | All download links, checksums, and signatures |
| [Public Key](public-key.md) | Key fingerprint, algorithm, how to pin it |
| [Release Notes](release-notes/index.md) | All release versions |

---

## FAQ

**Is this open-source?**
This repository contains the child runtime distribution artifacts. The mother body
orchestration system — which signs and approves capability updates — is not publicly
distributed. The runtime itself uses standard open-source dependencies (Node.js, SQLite).
This separation is intentional: it keeps the update authority clearly bounded and the
distribution channel independently verifiable.

**Why do I need to verify the signature?**
The GitHub repository is a delivery channel — it could theoretically be compromised.
The Ed25519 signing key (held offline by the operator) is the real trust root. Verifying
the signature confirms the release was authorized by the key holder, independent of
GitHub's integrity.

**Do I need a server to use GreenFrog?**
No. GreenFrog runs in personal mode by default — it initializes its own local identity
on first launch and starts immediately without any server. No enrollment URL, no
account, no external service required.

If you connect to a managed distribution server (optional, for organizations), you gain
signed capability updates and governed experience sharing. That connection is established
with a single `--enrollment-url` flag and is entirely optional.

**Will my local data be shared with other users automatically?**
No. Your local sessions, conversations, and workspace data are not directly shared with
other users. Experience data that your instance contributes back ("backflow") goes
through the mother body's governance process — it is reviewed and potentially promoted
into future updates, but it does not flow directly between instances.

**What's the difference between this and a regular AI chat app?**
GreenFrog runs locally on your machine. It manages its own agent loop, skill system,
memory, and scheduling. It can receive capability updates without you reinstalling
anything. It is a runtime, not a hosted service — you control where it runs and what
it has access to.

**Which languages does the runtime support?**
The runtime interface supports: English, German, Spanish, French, Italian, Japanese,
Korean, Portuguese, Simplified Chinese (zh-CN), and Traditional Chinese (zh-TW).
The language is auto-detected from your system locale, or you can set `GF_LOCALE`
in your config file.

**I found a problem with a release. How do I report it?**
Open an issue in this repository. Include the version number, platform, and the output
of `node tools/verify-release.js --manifest manifests/<version>/<platform>.json` so
we can confirm whether it is a signature or packaging issue.

---

## Requirements

- Node.js 22 or later ([nodejs.org](https://nodejs.org/en/download/))
- Linux (glibc 2.17+), macOS 11+, or Windows 10+
- 512 MB RAM available
- 200 MB disk space

---

*GreenFrog v1.4.0 — Key ID `c4ba4d8eeeb0ec21` — [Verify this release](docs/signature-verification.md)*
