# GreenFrog — Product Overview

## What Is GreenFrog?

GreenFrog is a personal AI agent runtime that runs on your machine. It manages its own agent
loop, skill system, memory, and scheduling. It receives governed capability updates without
requiring you to reinstall anything.

It is a runtime — not a hosted service, not a chatbot UI, and not a cloud API. You control
where it runs, what it has access to, and whether it is online.

---

## Who Is It For?

GreenFrog is designed for individuals and small teams who want:

- An AI agent that operates on local data without routing it through a third-party cloud
- A system that can be extended with custom skills and workflows
- Governed capability updates they can verify before applying
- A runtime that works offline once enrolled

It is not a replacement for hosted AI services if your primary need is convenience or
maximum model capability. It is the right choice if you need local control, verifiability,
and a stable, extensible runtime.

---

## Core Capabilities

### Agent Loop

GreenFrog runs a full agent loop on your machine. It accepts messages, calls skills, manages
tool outputs, and produces responses — without sending your data to a third-party AI
orchestration service. The language model calls go to your configured provider (Anthropic,
OpenAI, Ollama, or a compatible relay).

### Skill System

Skills are callable units of capability — API lookups, file operations, workflow triggers,
custom logic. They are registered by name and invoked by the agent loop. New skills can be
added as plugins without restarting the runtime.

### Memory

The runtime maintains structured memory across sessions. Memory entries are stored locally
in SQLite and are never transmitted to other instances.

### Scheduling

GreenFrog includes a job scheduler (cron-based) and a workflow engine. Jobs and workflows
run locally, on your machine, under the runtime's agent loop.

### Inheritance (Capability Updates)

Child instances receive capability updates from a signed distribution server. Updates are
verified against the Ed25519 public key before being applied. No capability change enters
your instance without passing the full signature and hash verification chain.

See [How Updates Work (upgrade.md)](upgrade.md) for the pull model and rollback procedure.

---

## What GreenFrog Is Not

- **Not a cloud service.** GreenFrog runs on your hardware. There is no GreenFrog cloud to
  log into.
- **Not a model.** GreenFrog is a runtime that calls language models you configure. It is
  not a model itself.
- **Not a single-purpose chatbot.** GreenFrog is a general-purpose agent runtime. It is
  designed to be extended with skills and workflows specific to your use case.
- **Not open-source (fully).** The child runtime distribution uses standard open-source
  dependencies (Node.js, SQLite). The mother-body orchestration system — which signs and
  approves capability updates — is not publicly distributed. See the
  [Distribution Model](distribution-model.md) for details.

---

## Architecture in One Paragraph

Your instance is a **child runtime**. It enrolls with a **mother-body distribution server**
on first launch, receives a signed credential, and begins operation. Periodically, it checks
for new **inheritance bundles** — signed packages containing capability updates. Each bundle
is verified (signature, key fingerprint, bundle hash) before being applied. Your instance
may also contribute **backflow data** (anonymized experience records) back to the
distribution server, where it goes through a governed review process before influencing
future updates. None of this data flows directly between user instances.

Full details: [Distribution Model](distribution-model.md)

---

## Security Baseline

| Property | Implementation |
|----------|---------------|
| Update authenticity | Ed25519 signature over canonical manifest digest |
| Key integrity | keyId is included in the signed content |
| Bundle integrity | SHA-256 hash verified independently of signature |
| Private key exposure | Mother private key never included in any distribution artifact |
| Credential mechanism | Enrolled JWT — no shared secrets, no API keys in config |
| Enrollment requirement | Mandatory; establishes authenticated update channel |

The trust root is the Ed25519 public key (`public-key.pem`), distributed with every
package. It is not the GitHub repository.

Detailed trust model: [Trust Model](trust-model.md)

---

## Supported Platforms

| Platform | Minimum Version |
|----------|----------------|
| Linux    | Any distribution with glibc 2.17+ |
| macOS    | 11 (Big Sur) or later |
| Windows  | Windows 10 or later |

The current v1.4.0 child distribution bundles require Node.js 24.x on all platforms.

---

## Supported Locales

The runtime interface is available in:
English, German, Spanish, French, Italian, Japanese, Korean, Portuguese,
Simplified Chinese (zh-CN), and Traditional Chinese (zh-TW).

The language is auto-detected from your system locale, or you can set `GF_LOCALE`
in your configuration file.

---

## Getting Started

See the [Installation Guide](install.md) for download, verification, and first-launch steps.

*GreenFrog v1.4.0 — Key ID `c4ba4d8eeeb0ec21`*
