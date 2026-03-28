#!/usr/bin/env node
/**
 * verify-release.js — Standalone release manifest verification tool.
 *
 * Distributed as part of every GreenFrog release package.
 * Requires only Node.js built-in modules (no npm install needed).
 *
 * Verifies that a manifest is:
 *   1. Structurally valid
 *   2. keyId matches the provided public key fingerprint
 *   3. Ed25519 signature is valid
 *   4. Bundle file SHA-256 matches bundleHash (if --bundle is provided)
 *
 * Key resolution (first found):
 *   1. --public-key <path>
 *   2. $GF_BASE_DIR/public-key.pem
 *   3. $HOME/.greenfrog/public-key.pem
 *   4. %APPDATA%\GreenFrog\public-key.pem  (Windows)
 *   5. public-key.pem in the same directory as this script
 *
 * Usage:
 *   node verify-release.js --manifest <path> [--bundle <path>] [--public-key <path>]
 *
 * Exit codes:
 *   0  — all checks passed
 *   1  — verification failed
 *   2  — argument error or file not found
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ── Argument parsing ──────────────────────────────────────────────────────────

let opts;
try {
  opts = parseArgs({
    args: process.argv.slice(2),
    options: {
      manifest:     { type: 'string' },
      bundle:       { type: 'string' },
      'public-key': { type: 'string' },
      help:         { type: 'boolean', short: 'h' },
    },
    allowPositionals: false,
  }).values;
} catch (err) {
  console.error(`[verify-release] argument error: ${err.message}`);
  process.exit(2);
}

if (opts.help || !opts.manifest) {
  console.log([
    'Usage: node verify-release.js --manifest <path> [--bundle <path>] [--public-key <path>]',
    '',
    'Options:',
    '  --manifest   <path>   Path to signed manifest JSON (required)',
    '  --bundle     <path>   Path to bundle file to verify hash (optional)',
    '  --public-key <path>   Path to Ed25519 public key PEM (auto-resolved if omitted)',
    '  -h, --help            Show this help',
  ].join('\n'));
  process.exit(opts.help ? 0 : 2);
}

// ── Public key resolution ─────────────────────────────────────────────────────

function resolvePublicKeyPath(override) {
  if (override) return fs.existsSync(override) ? override : null;
  const candidates = [];
  const baseDir = process.env['GF_BASE_DIR'];
  if (baseDir) candidates.push(path.join(baseDir, 'public-key.pem'));
  candidates.push(path.join(os.homedir(), '.greenfrog', 'public-key.pem'));
  if (process.platform === 'win32' && process.env['APPDATA']) {
    candidates.push(path.join(process.env['APPDATA'], 'GreenFrog', 'public-key.pem'));
  }
  // Same directory as this script (distribution bundle includes public-key.pem alongside)
  candidates.push(path.join(__dirname, 'public-key.pem'));
  // One level up from tools/ (distribution root)
  candidates.push(path.join(__dirname, '..', 'public-key.pem'));
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  return null;
}

// ── Load manifest ─────────────────────────────────────────────────────────────

const manifestPath = path.resolve(opts.manifest);
if (!fs.existsSync(manifestPath)) {
  console.error(`ERROR: manifest not found: ${manifestPath}`);
  process.exit(2);
}

let manifest;
try {
  manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
} catch (err) {
  console.error(`ERROR: failed to parse manifest: ${err.message}`);
  process.exit(2);
}

// ── Structural validation ─────────────────────────────────────────────────────

const REQUIRED = [
  'manifestVersion', 'releaseId', 'version', 'releasedAt',
  'compatibilityConstraint', 'bundleType', 'bundleHash', 'bundleSize',
  'downloadUrl', 'keyId', 'signature',
];

let ok = true;
for (const f of REQUIRED) {
  if (!manifest[f] && manifest[f] !== 0) {
    console.error(`FAIL  structure: missing field: ${f}`);
    ok = false;
  }
}
if (manifest.bundleType !== 'mother_promoted') {
  console.error(`FAIL  structure: bundleType must be 'mother_promoted'`);
  ok = false;
}
if (typeof manifest.bundleHash === 'string' && manifest.bundleHash.length !== 64) {
  console.error('FAIL  structure: bundleHash must be 64 hex chars');
  ok = false;
}
if (!ok) process.exit(1);
console.log('OK    structure: all required fields present');

// ── Load public key ───────────────────────────────────────────────────────────

const keyPath = resolvePublicKeyPath(opts['public-key']);
if (!keyPath) {
  console.error('FAIL  key: no public key found');
  console.error('      Use --public-key, or place public-key.pem next to this script.');
  process.exit(1);
}

let publicKey, pubPem;
try {
  pubPem = fs.readFileSync(keyPath, 'utf-8');
  publicKey = crypto.createPublicKey(pubPem);
} catch (err) {
  console.error(`FAIL  key: ${err.message}`);
  process.exit(1);
}
console.log(`OK    key:  ${keyPath}`);

// ── keyId check ───────────────────────────────────────────────────────────────

const der = crypto.createPublicKey(pubPem).export({ type: 'spki', format: 'der' });
const actualKeyId = crypto.createHash('sha256').update(der).digest('hex').slice(0, 16);

if (manifest.keyId !== actualKeyId) {
  console.error(`FAIL  keyId: manifest=${manifest.keyId}, key=${actualKeyId}`);
  console.error('      This public key does not match the key that signed this manifest.');
  process.exit(1);
}
console.log(`OK    keyId: ${actualKeyId}`);

// ── Signature verification ────────────────────────────────────────────────────

try {
  const { signature, ...withoutSig } = manifest;
  const canonical = JSON.stringify(withoutSig, Object.keys(withoutSig).sort());
  const digest = crypto.createHash('sha256').update(canonical).digest();
  const sigBytes = Buffer.from(signature, 'base64url');
  const valid = crypto.verify(null, digest, publicKey, sigBytes);
  if (!valid) {
    console.error('FAIL  signature: Ed25519 verification FAILED — manifest may be tampered');
    process.exit(1);
  }
} catch (err) {
  console.error(`FAIL  signature: ${err.message}`);
  process.exit(1);
}
console.log('OK    signature: Ed25519 valid');

// ── Bundle hash check ─────────────────────────────────────────────────────────

if (opts.bundle) {
  const bundlePath = path.resolve(opts.bundle);
  if (!fs.existsSync(bundlePath)) {
    console.error(`FAIL  bundle: not found: ${bundlePath}`);
    process.exit(1);
  }
  const actual = crypto.createHash('sha256').update(fs.readFileSync(bundlePath)).digest('hex');
  if (actual !== manifest.bundleHash) {
    console.error('FAIL  bundle: SHA-256 mismatch');
    console.error(`      expected: ${manifest.bundleHash}`);
    console.error(`      actual:   ${actual}`);
    process.exit(1);
  }
  console.log('OK    bundle:  SHA-256 matches');
}

// ── Summary ───────────────────────────────────────────────────────────────────

console.log('');
console.log('VERIFIED');
console.log(`  Version  : ${manifest.version}  (${manifest.releaseId})`);
console.log(`  Released : ${manifest.releasedAt}`);
console.log(`  Key ID   : ${actualKeyId}`);
if (opts.bundle) console.log(`  Bundle   : ${path.basename(opts.bundle)} ✓`);
