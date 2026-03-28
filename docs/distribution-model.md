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
- Enrolls with a mother-body distribution server to receive a signed credential
- Periodically checks for capability updates (inheritance bundles) and applies them after
  verification
- May contribute anonymized experience data back to the distribution system (backflow)
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

**Enrollment is required.** A child instance cannot receive capability updates or contribute
backflow data without first enrolling with a distribution server.

Enrollment establishes:
1. A unique instance identity (generated locally on first launch)
2. A signed JWT credential from the distribution server
3. The authenticated channel used for all subsequent distribution operations

Enrollment is automatic: set `GF_ENROLLMENT_URL` in your config file and launch GreenFrog.
The process completes in one network round-trip without any manual key entry.

**Why enrollment cannot be skipped:**

- The JWT is the only authentication mechanism for inheritance and backflow endpoints
- Without enrollment, the distribution server has no record of your instance and will not
  serve signed bundles to it
- Enrollment is a one-time operation — not a recurring login

Enrollment URL and any required access code are provided by your organization's
administrator alongside the distribution package.

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

The GitHub distribution repository sits to the right of this diagram — a read-only artifact
store from which your installer downloads the initial package. The trust chain runs through
the signed manifests and the public key, not through GitHub.
