# GreenFrog Release Signature Verification

All GreenFrog release manifests are signed with an Ed25519 private key that never leaves the
mother-body host. Before any capability bundle is applied, the child runtime verifies the
signature. This document explains how to verify signatures yourself.

---

## Quick Verification

Every GreenFrog release package includes a standalone `tools/verify-release.js` script that
requires only Node.js built-in modules (no `npm install` needed).

```bash
# From your extracted release bundle:
node tools/verify-release.js --manifest manifests/1.4.0/linux.json

# With bundle hash check:
node tools/verify-release.js \
  --manifest manifests/1.4.0/linux.json \
  --bundle   linux/greenfrog-v1.4.0-linux.tar.gz

# With explicit public key (if not using bundled public-key.pem):
node tools/verify-release.js \
  --manifest manifests/1.4.0/linux.json \
  --public-key /path/to/your/trusted-public-key.pem
```

The tool auto-resolves `public-key.pem` from:
1. `--public-key` argument
2. `$GF_BASE_DIR/public-key.pem`
3. `~/.greenfrog/public-key.pem`
4. Same directory as the script (`tools/public-key.pem`)
5. Parent directory of tools/ (`public-key.pem` at distribution root)

Expected output:

```
OK    structure: all required fields present
OK    key:  loaded from keys/mother-public.pem
OK    keyId: a1b2c3d4e5f60718
OK    signature: Ed25519 signature valid
OK    bundle:  SHA-256 hash matches manifest

VERIFIED
  Release    : 1.4.0 (...)
  Key ID     : a1b2c3d4e5f60718
  Bundle hash: fb4879ce1af6f8...
```

---

## What Is Signed

Each manifest is a JSON document. The signed content is:

```
SHA-256( JSON.stringify(manifest_without_signature_field, sorted_keys) )
```

Specifically:
- The `signature` field is **excluded** from the digest
- The `keyId` field is **included** in the digest (so key rotation is tamper-proof)
- Keys are sorted alphabetically for determinism across platforms/runtimes

---

## Manual Verification (Node.js)

```javascript
import crypto from 'node:crypto';
import fs from 'node:fs';

const manifest = JSON.parse(fs.readFileSync('manifest.json', 'utf-8'));
const pubPem = fs.readFileSync('public-key.pem', 'utf-8');

// 1. Verify keyId matches public key
const keyObj = crypto.createPublicKey(pubPem);
const der = keyObj.export({ type: 'spki', format: 'der' });
const actualKeyId = crypto.createHash('sha256').update(der).digest('hex').slice(0, 16);

if (manifest.keyId !== actualKeyId) {
  throw new Error(`keyId mismatch: manifest=${manifest.keyId}, key=${actualKeyId}`);
}

// 2. Reproduce canonical digest
const { signature, ...withoutSig } = manifest;
const canonical = JSON.stringify(withoutSig, Object.keys(withoutSig).sort());
const digest = crypto.createHash('sha256').update(canonical).digest();

// 3. Verify Ed25519 signature
const publicKey = crypto.createPublicKey(pubPem);
const sigBytes = Buffer.from(signature, 'base64url');
const valid = crypto.verify(null, digest, publicKey, sigBytes);

console.log(valid ? 'VALID' : 'INVALID');
```

---

## Manual Verification (OpenSSL)

```bash
# Extract the raw public key bytes (DER) from PEM
openssl pkey -in public-key.pem -pubin -outform DER -out public-key.der

# Decode signature from base64url
SIGNATURE=$(node -e "
  const m = JSON.parse(require('fs').readFileSync('manifest.json'));
  process.stdout.write(Buffer.from(m.signature, 'base64url').toString('base64'));
")
echo "$SIGNATURE" | base64 -d > manifest.sig

# Produce the canonical manifest (without signature field, sorted keys)
node -e "
  const m = JSON.parse(require('fs').readFileSync('manifest.json'));
  const {signature, ...rest} = m;
  const canon = JSON.stringify(rest, Object.keys(rest).sort());
  process.stdout.write(canon);
" > manifest-canonical.json

# Compute SHA-256 of canonical manifest
openssl dgst -sha256 -binary manifest-canonical.json > manifest.digest

# Verify with OpenSSL (Ed25519)
openssl pkeyutl -verify -pubin -inkey public-key.pem \
  -sigfile manifest.sig \
  -in manifest.digest \
  && echo "VALID" || echo "INVALID"
```

---

## Verifying the Bundle Hash

The `bundleHash` field in the manifest is the SHA-256 hex digest of the full bundle file content.

```bash
# Linux / macOS
sha256sum greenfrog-v1.4.0-linux.tar.gz
# Compare to manifest.bundleHash

# Windows
Get-FileHash greenfrog-v1.4.0-windows.zip -Algorithm SHA256
```

Or with Node.js:

```javascript
import crypto from 'node:crypto';
import fs from 'node:fs';

const content = fs.readFileSync('bundle.tar.gz');
const hash = crypto.createHash('sha256').update(content).digest('hex');
console.log(hash); // compare to manifest.bundleHash
```

---

## The Key ID (keyId)

The `keyId` is the first 16 hex characters of the SHA-256 of the DER-encoded public key:

```javascript
const der = crypto.createPublicKey(pubPem).export({ type: 'spki', format: 'der' });
const keyId = crypto.createHash('sha256').update(der).digest('hex').slice(0, 16);
```

This fingerprint is:
- **Stable** — same key always produces the same keyId, regardless of PEM formatting
- **Covered by signature** — keyId is in the signed manifest content, so an attacker cannot swap keys without invalidating the signature
- **Used for key rotation detection** — if a new key is issued, manifests signed with it will have a different keyId

---

## Detached Signature Files

Each manifest has a corresponding `.sig` file containing the base64url-encoded signature alone:

```
release/signatures/v1.4.0.sig
public-distribution/signatures/1.4.0/linux.sig
```

These are provided for tooling that operates on detached signatures rather than embedded fields.

---

## Trust Model

The security of this system rests on:

1. **Private key secrecy** — `keys/mother-private.pem` is gitignored and never included in any
   distribution artifact. Only the mother-body operator holds this key.

2. **Public key distribution** — `public-key.pem` is embedded in every distribution package
   and in the public distribution repository. It is the trust anchor.

3. **Mandatory verification** — the child runtime never applies a bundle without first verifying
   the manifest signature. There is no override or skip path.

4. **Hash integrity** — even after signature verification, the downloaded bundle content is
   independently hashed and compared to `bundleHash`. This prevents MITM substitution.

5. **keyId pinning** — the `keyId` in the manifest is part of the signed content, so a bundle
   signed with the old key cannot be presented with the new key's ID (or vice versa).

---

## What Verification Does NOT Cover

- **Transport security** — use HTTPS for all manifest and bundle downloads.
- **Server-side compromise** — if the mother-body server is compromised, new bundles may be
  signed legitimately. The private key should be kept offline/air-gapped.
- **Replay attacks** — the `releaseId` and `releasedAt` fields help detect replays; the child
  runtime tracks the last-applied version to prevent downgrade if configured to do so.
