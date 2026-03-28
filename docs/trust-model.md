# GreenFrog Trust Model

## The Trust Root Is the Signing Key, Not the Repository

The GitHub repository at `github.com/ibrahim160920/greenfrog-distribution` is a **delivery
channel**. It could theoretically be compromised — a repository can be force-pushed to, have
releases replaced, or have its contents modified by anyone with write access.

The **trust root** is the Ed25519 private key held by the GreenFrog operator —
NOT the GitHub repository. The corresponding public key (`public-key.pem`) is
distributed with every release package and embedded in every child runtime installation
at `~/.greenfrog/public-key.pem`.

A valid signature on a manifest proves that the operator who holds the private key authorized
that release — regardless of what is in the GitHub repository at any given moment.

---

## Why This Matters

Consider these scenarios:

**Scenario A — GitHub is compromised.** An attacker replaces `linux/greenfrog-v1.4.0-linux.tar.gz`
with a malicious bundle. Your child runtime downloads the new bundle. The bundle hash in the
signed manifest does not match. Update rejected.

**Scenario B — A manifest file is modified in the repo.** An attacker changes the `downloadUrl`
in `manifests/1.4.0/linux.json` to point to their server. The manifest no longer matches the
signature. Update rejected.

**Scenario C — The attacker also replaces the manifest and signature.** The new signature is
not valid under the public key embedded in your installation. Update rejected.

**Scenario D — The public key in the repo is replaced.** Your installation has the original
public key at `~/.greenfrog/public-key.pem`. The child runtime uses the locally installed
key, not what is in the repo. Update rejected.

The chain only breaks if the operator's private key is compromised. The private key is never
included in any distribution artifact and should be kept offline.

---

## The Full Verification Chain

Every time the child runtime applies an inheritance update, it performs these checks in order:

1. **Credential present** — The instance must be enrolled (valid JWT). No credential = no updates.
2. **Manifest fetch** — Pull `manifests/<version>/<platform>.json` over HTTPS from the
   distribution server.
3. **Structure validation** — All required manifest fields must be present; `bundleType` must
   be `mother_promoted`.
4. **keyId check** — `manifest.keyId` must match the fingerprint of the locally installed
   public key (`SHA-256(DER-encoded SPKI).hex.slice(0, 16)`). This prevents an attacker from
   silently swapping in a different key.
5. **Ed25519 signature verification** — The signature is verified over:
   `SHA-256(JSON.stringify(manifest_without_signature_field, sorted_keys))`
   using the locally installed public key.
6. **Compatibility check** — `manifest.compatibilityConstraint` (e.g. `>=1.0.0 <2.0.0`) is
   checked against the current runtime version.
7. **Version check** — If already at this version, skip (no reapply).
8. **Bundle download** — Download the bundle from `manifest.downloadUrl`.
9. **Bundle hash verification** — `SHA-256(bundle_bytes)` must match `manifest.bundleHash`.
   This is checked independently of the signature.
10. **Archive previous** — Current bundle archived to `inheritance/previous/` (enables rollback).
11. **Apply** — Write new bundle to `inheritance/current.json`.
12. **Record** — Update `inheritance/config.json` with `lastAppliedVersion` and `lastAppliedAt`.

Any failure at any step aborts the update. The current bundle is not modified.

---

## The Public Key

The public key fingerprint (key ID) for v1.4.0:

```
Key ID : c4ba4d8eeeb0ec21
Algorithm : Ed25519
```

Full fingerprint details and pinning instructions: [public-key.md](../public-key.md)

The key ID is the first 16 hex characters of the SHA-256 of the DER-encoded SPKI public key:

```javascript
const der = crypto.createPublicKey(pubPem).export({ type: 'spki', format: 'der' });
const keyId = crypto.createHash('sha256').update(der).digest('hex').slice(0, 16);
```

This value is stable across PEM formatting variations. It is included in the signed manifest
content, so an attacker cannot present a bundle signed with a different key while claiming
the original key ID.

---

## Key Rotation

If the signing key is rotated, new manifests will carry a different `keyId`. Child runtimes
with the old public key will reject new manifests (keyId mismatch). The upgrade path for a
key rotation is:

1. Operator issues a key-rotation manifest signed with the old key, containing the new
   public key material.
2. Child runtime verifies the key-rotation manifest with the old key.
3. New public key is written to `~/.greenfrog/public-key.pem`.
4. Subsequent manifests are verified with the new key.

This procedure is not yet implemented in v1.4.0. The current recommendation is to keep
the private key offline and treat it as a long-lived root key.

---

## What Verification Does Not Cover

- **Transport security.** Use HTTPS for all distribution endpoints. HTTP is not acceptable.
- **Server-side compromise.** If the distribution server is compromised and the attacker
  also obtains the private signing key, they can issue valid signed bundles. The private key
  should be kept offline or on air-gapped infrastructure.
- **Replay attacks (partial).** The `releaseId`, `version`, and `releasedAt` fields help
  detect replays. The child runtime tracks `lastAppliedVersion` to prevent downgrade within
  a running installation, but does not enforce a strict monotonic version floor across
  reinstalls.
- **Local file system integrity.** Once applied, the bundle at `~/.greenfrog/inheritance/`
  is trusted by the runtime. If an attacker has write access to your home directory, they
  can modify the applied bundle directly. Full-disk encryption and OS-level file permissions
  are outside the scope of this system.

---

## Verifying Independently

You do not need to run GreenFrog to verify a release. See
[Signature Verification](signature-verification.md) for step-by-step instructions using:

- The bundled `tools/verify-release.js` (no npm install required)
- Node.js manual verification
- OpenSSL command-line verification
