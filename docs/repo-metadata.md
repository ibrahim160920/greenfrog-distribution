# GreenFrog — GitHub Repository Metadata

This document contains the recommended settings for the public distribution repository
on GitHub. Fill these in via GitHub → Settings → General when setting up or refreshing
the repository.

---

## Repository Name

```
greenfrog-distribution
```

Full name: `ibrahim160920/greenfrog-distribution`

---

## GitHub Repository Description

Recommended (160 characters max, no markdown):

```
GreenFrog child runtime distribution — local AI agent, signed releases, Ed25519-verified updates. Linux, macOS, Windows. Node.js 22+.
```

Short alternative (≤ 100 chars):

```
GreenFrog child runtime — local AI agent, signed releases, verified updates.
```

---

## Homepage URL

Set to the README anchor for Quick Start, or the install docs:

```
https://github.com/ibrahim160920/greenfrog-distribution#quick-start
```

If a dedicated landing page is available in future, use that instead.

---

## Topics (GitHub repository tags)

Recommended topic list for discoverability:

```
ai-agent
local-ai
runtime
distribution
signed-releases
ed25519
node
typescript
child-runtime
agent-runtime
```

How to set: GitHub → Settings → About section → Topics (gear icon).

---

## Release Naming Convention

| Item | Convention |
|------|------------|
| Git tag | `v1.4.0` (semver, `v` prefix) |
| `latest` tag | Always points to the most recent release commit |
| GitHub Release title | `GreenFrog v1.4.0` |
| Release body | Paste from `release-notes/vX.Y.Z.md` |
| Asset names | `greenfrog-v1.4.0-linux.tar.gz`, `greenfrog-v1.4.0-macos.tar.gz`, `greenfrog-v1.4.0-windows.zip` |

Create GitHub Releases for each version. Attach the three platform bundles
plus their checksums file as release assets. This makes them downloadable
from the GitHub Releases API.

---

## Social Preview (Open Graph Image)

GitHub → Settings → Social preview → Upload image.

Recommended image size: **1280 × 640 px** (GitHub renders at 1200 × 630).

### Suggested text layout for the social preview image

```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│   GreenFrog                                              │
│                                                          │
│   Local-first AI agent runtime                           │
│   Verified · Updatable · Yours                           │
│                                                          │
│   ┌────────────────────────────────────────────────┐    │
│   │  Linux · macOS · Windows · Node.js 22+         │    │
│   │  Ed25519-signed · Governed updates             │    │
│   └────────────────────────────────────────────────┘    │
│                                                          │
│   Key ID: c4ba4d8eeeb0ec21                               │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

Background: dark (e.g. `#0d1117` GitHub dark or `#1a2332`)
Primary text: white / near-white
Accent / badge row: muted teal or green

Alt text for accessibility:
```
GreenFrog v1.4.0 — Local-first AI agent runtime. Verified, updatable, yours.
Linux, macOS, Windows. Node.js 22+. Ed25519-signed releases.
```

---

## README First-Screen Structure

The README first screen (above the fold on a 1080p display) should convey:

1. Product name + one-line tagline
2. "This is a distribution repo, not source" — brief, not defensive
3. Download table with latest version — immediately actionable
4. Node.js requirement
5. Links to: release notes, all releases, checksums, public key, verify

Current README structure as of v1.4.0:

```
# GreenFrog
tagline + repo-type statement
> note: distribution artifacts, not source code

## Download v1.4.0
download table
node requirement
release notes · all releases · checksums · public key · verify

## Quick Start  (3 steps)
## Verifying Your Download
## How Updates Work
## What This Repository Is  (distribution model summary)
## Why GreenFrog?  (value props)
## Documentation  (table)
## FAQ
## Requirements
```

When updating the README, maintain this order. The download table must stay
above the Quick Start section.

---

## Pinned Repositories (if applicable)

If the organization profile allows pinning repositories, pin
`greenfrog-distribution` with the description above.

---

## Branch Protection Recommended Settings

| Setting | Value |
|---------|-------|
| Default branch | `main` |
| Require PR reviews before merging | Recommended for production |
| Require status checks | As applicable |
| Allow force push to `main` | Only for signed release commits |
| `latest` tag | Force-pushable by release automation |

---

## Notes

- The `latest` tag in this repository is not a GitHub Release — it is a git tag
  that always points to the most recent release commit. This is intentional for
  machine-readable `latest.json` consumers.
- Do not set the repository to "private" after publishing signed artifacts —
  the public key and manifests must remain publicly accessible for verification.
- The GitHub release page is secondary; the primary trust mechanism is the
  signed manifests and `public-key.pem`, not the GitHub UI.
