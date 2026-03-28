# GreenFrog — Release History

All GreenFrog child runtime releases. Newest first.

---

| Version | Released | Notes | Platforms |
|---------|----------|-------|-----------|
| [v1.4.0](v1.4.0.md) | 2026-03-28 | Signed inheritance bundles, child status API, improved installer | Linux, macOS, Windows |

---

## How to Read These Notes

Each release note covers:

- **What's New** — new capabilities in this release
- **Compatibility** — Node.js requirement and compatibility constraint (the range of child
  runtime versions that can receive this update automatically)
- **Security** — any security-relevant changes
- **Upgrade** — whether enrolled instances receive this automatically and how to force a
  manual check

## Verifying a Release

Every release is signed with Ed25519 key `c4ba4d8eeeb0ec21`.

```bash
node tools/verify-release.js \
  --manifest manifests/<version>/<platform>.json \
  --bundle   <platform>/greenfrog-v<version>-<platform>.tar.gz
```

Expected output includes `VERIFIED` and the key ID.

Full verification instructions: [docs/signature-verification.md](../docs/signature-verification.md)
