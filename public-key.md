# GreenFrog Distribution Signing Key

## Key Identity

| Field | Value |
|-------|-------|
| **Key ID (keyId)** | `c4ba4d8eeeb0ec21` |
| **Algorithm** | Ed25519 |
| **SHA-256 Fingerprint** | `c4ba4d8eeeb0ec21c2ef7ab1ffe6e29c27c332a38e76e8bb5a2c6279d457e69d` |
| **Exported At** | 2026-03-28T18:09:06.110Z |

## Public Key (PEM)

```
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAsb63QKdD4OhLs6Qx/HIwNuyPKZrBLvnqd9/CZi1nCi0=
-----END PUBLIC KEY-----
```

## How to Verify a Release Manifest

Each GreenFrog release manifest includes a `signature` field and a `keyId` field.
The signature covers all manifest fields except `signature` itself, including `keyId`.

**Using the bundled verify-release.js tool:**

```bash
node scripts/verify-release.js --manifest release/manifests/vX.Y.Z.json
```

**Manual verification with Node.js:**

```javascript
import crypto from 'node:crypto';
import fs from 'node:fs';

const manifest = JSON.parse(fs.readFileSync('manifest.json', 'utf-8'));
const pubPem = fs.readFileSync('public-key.pem', 'utf-8');
const publicKey = crypto.createPublicKey(pubPem);

// Reproduce the digest: SHA-256 of manifest without signature field, sorted keys
const { signature, ...withoutSig } = manifest;
const canonical = JSON.stringify(withoutSig, Object.keys(withoutSig).sort());
const digest = crypto.createHash('sha256').update(canonical).digest();

const valid = crypto.verify(null, digest, publicKey, Buffer.from(signature, 'base64url'));
console.log(valid ? 'VALID' : 'INVALID');
```

## Trust Model

- The private signing key never leaves the mother-body host.
- The `keyId` in every manifest must match this key's fingerprint.
- Bundles are only applied after both signature verification and SHA-256 hash check pass.
- Key rotation: if the keyId changes, the old public key will no longer verify new manifests.

## Pinning This Key

If you are distributing GreenFrog child packages through your own infrastructure,
pin this key's `keyId` (`c4ba4d8eeeb0ec21`) and store this PEM file in a location controlled
by you (not the GreenFrog runtime directory), then set `GF_PUBLIC_KEY_PATH` to that path.
