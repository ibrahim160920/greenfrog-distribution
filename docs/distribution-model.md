# GreenFrog Distribution Model

## Overview

GreenFrog uses a **mother / child** distribution model. Understanding this model helps you
know what you are running, where updates come from, and what data leaves your machine.

---

## Mother Body vs. Child Instance

### The Child Instance (What You Install)

**What you download is a child instance.** It is a fully functional local AI agent runtime.
It runs on your hardware, uses your credentials, and keeps your sessions local.

A child instance:
- Runs the GreenFrog agent loop, skill system, memory, and scheduler on your machine
- Initializes its own local identity on first launch — no server required for personal use
- Optionally enrolls with a mother-body distribution server to receive signed capability
  updates and contribute to the governed backflow pipeline
- Periodically checks for capability updates (inheritance bundles) and applies them after
  verification (when connected to a distribution server)
- Does not directly communicate with other child instances

### The Mother Body (Not Publicly Distributed)

**The mother body is not distributed.** It is the governed system responsible for:
- Reviewing and approving capability updates
- Signing inheritance bundles with the operator's Ed25519 private key
- Operating the distribution server (enrollment, inheritance, backflow endpoints)
- Running the evolution pipeline that produces new capability candidates

You never interact with the mother body directly. It communicates with your child instance
through signed manifests and verifiable update bundles.

---

## The Public Distribution Repository

The GitHub repository (`github.com/ibrahim160920/greenfrog-distribution`) contains:

- Distribution bundles (`.tar.gz` / `.zip`) for Linux, macOS, and Windows
- Installer scripts (`install.sh`, `install.ps1`, `bootstrap.bat`)
- Signed manifests (`manifests/<version>/<platform>.json`)
- Detached signatures (`signatures/<version>/<platform>.sig`)
- The public signing key (`public-key.pem`) and its fingerprint document (`public-key.md`)
- A standalone verification tool (`tools/verify-release.js`)
- Documentation

**This repository is a delivery mechanism, not a trust anchor.** The Ed25519 public key
embedded in your installation is the trust root. See [Trust Model](trust-model.md) for why.

---

## Inheritance (Capability Updates)

Inheritance is the mechanism by which child instances receive capability updates from the
mother body.

**Pull model:** Your child instance initiates all update checks. Nothing is pushed to you.
You control the check frequency and can disable inheritance entirely.

**Update modes:**

| Mode | Behavior |
|------|----------|
| `stable` (default) | Apply updates tagged `mother_promoted` after full verification |
| `security_only` | Apply only updates tagged with a security flag |
| `disabled` | No update checks; current bundle is permanent until manually changed |

Set the mode in `~/.greenfrog/config.sh`:
```bash
export GF_INHERITANCE_MODE="stable"   # stable | security_only | disabled
```

**Verification chain:** Every bundle is verified before being applied. The full 12-step
chain is documented in [Trust Model](trust-model.md#the-full-verification-chain).

**Rollback:** The previous bundle is archived before each update is applied. If a new bundle
causes problems, the previous bundle can be restored. See [Upgrade Guide](upgrade.md) for
rollback instructions.

---

## Enrollment

### Personal Mode (Default)

**No server required.** On first launch, GreenFrog automatically initializes its own local
identity without contacting any external server:

1. A unique instance ID is generated and stored in `~/.greenfrog/identity/`
2. A local HMAC signing key is created
3. A self-signed JWT credential is issued — valid indefinitely, locally verifiable
4. The instance transitions to `enrolled` state and starts immediately

This is the default for individual users. You do not need an enrollment URL, an account, or
any network access to get started.

### Managed Mode (Optional — Organizations)

If you connect GreenFrog to a managed distribution server, enrollment establishes:
1. A unique instance identity (generated locally on first launch)
2. A signed JWT credential issued by the distribution server
3. The authenticated channel used for inheritance (capability updates) and backflow

Managed enrollment is automatic: pass the server URL at launch and GreenFrog completes
enrollment in one network round-trip without any manual key entry.

```bash
# Linux / macOS — pass at launch (one-time)
greenfrog --enrollment-url https://your-server.example.com/api/distribution/enroll

# Or set permanently in ~/.greenfrog/config.sh:
export GF_ENROLLMENT_URL="https://your-server.example.com/api/distribution/enroll"
```

Your organization's administrator will provide the enrollment URL.

### Migrating from Personal to Managed

If you started in personal mode and later receive a managed distribution server URL, pass
`--enrollment-url` on the command line. GreenFrog detects the migration intent and:

1. Clears only the personal credential, state, and local signing key
2. **Preserves the install record** — your `instanceId` does not change
3. Enrolls with the remote server using the same `instanceId`
4. Saves the server-issued JWT credential (replaces the personal one)

If remote enrollment fails, personal mode is automatically restored and the original
`instanceId` remains in use. The migration is an atomic swap of credentials, not a
re-installation.

---

## Backflow (Experience Data)

Backflow is the mechanism by which child instances contribute data back to the distribution
system.

**What is backflow?** Anonymized records of agent interactions, skill outcomes, and workflow
results. The specific content depends on the runtime version and your configuration.

**How it works:**
1. Your instance queues experience records locally (`~/.greenfrog/backflow/`)
2. Periodically, queued records are sent to the distribution server over the authenticated
   channel (JWT required)
3. At the distribution server, records go through a governed review process
4. Records that pass review may be promoted into future capability updates via the evolution
   pipeline

**What backflow is not:**
- Your local sessions, conversation history, and workspace data are **not** backflow targets
- Backflow records are not exchanged directly between user instances — they go through the mother body's
  review process
- Other users' raw experience data does not enter your instance directly

**Disabling backflow:**
```bash
export GF_BACKFLOW_ENABLED="false"   # in ~/.greenfrog/config.sh
```

---

## Data Isolation Between Instances

GreenFrog child instances are isolated from each other:

- Your local data (sessions, memory, workspace) stays on your machine
- Backflow data goes through the mother body's governance process before influencing future
  updates — it is not shared directly with other instances
- Inheritance bundles that reach your instance have been reviewed and approved by the
  operator — they are not raw data from other users

The distribution model is a **hub-and-spoke** architecture: data flows between each child
instance and the mother body. Direct instance-to-instance communication does not occur.

---

## What Is and Is Not in Your Installation

### Included in every child package

- GreenFrog Node.js runtime (`runtime/`)
- Distribution identity and enrollment subsystem
- Inheritance (update) client
- Backflow (telemetry) client
- Distribution server routes (for local API access)
- Public key for manifest verification (`public-key.pem`)
- Platform-specific installer script
- Configuration template

### NOT included (mother-body only)

- Packaging and signing infrastructure
- Mother private signing key (`keys/mother-private.pem`)
- OwnerKernel, TrustedSelector, CapabilityUnit (internal capability promotion modules)
- Evolution scheduler and source repository sync
- Any module matching `mother_*`, `evolution_*`, `source_repo_*`, `owner_kernel*`

The absence of mother-only modules is verified by the release pipeline at build time.
Any violation causes the build to exit with an error — these modules cannot be accidentally
included in a child distribution.

---

## Summary Diagram

```
Personal mode (default — no server needed):

           ┌────────────────────────────────┐
           │        Child Instance          │
           │  (your machine)                │
           │                               │
           │  Local identity self-init      │
           │  Agent loop + Skills + Memory  │
           │  Scheduler + Workflows         │
           │  ~/.greenfrog/                 │
           └────────────────────────────────┘


Managed mode (optional — organizations):

┌──────────────────────────────────────────────────────────┐
│                      Mother Body                         │
│  (private — not distributed)                             │
│                                                          │
│  Evolution pipeline → CapabilityUnit → sign-manifest.js  │
│                              │                           │
│                       Signed bundles                     │
│                              │                           │
│              Distribution Server (enrollment / API)      │
│                    ↑              ↓                       │
│               Backflow       Inheritance                  │
│               (governed)     (pull, verified)            │
└──────────────────────────────────────────────────────────┘
                    ↑                  ↓
           ┌────────────────────────────────┐
           │        Child Instance          │
           │  (your machine)                │
           │                               │
           │  Agent loop + Skills + Memory  │
           │  Scheduler + Workflows         │
           │  ~/.greenfrog/                 │
           └────────────────────────────────┘
```

The GitHub distribution repository is a read-only artifact store from which your installer
downloads the initial package. The trust chain runs through the signed manifests and the
public key, not through GitHub.
