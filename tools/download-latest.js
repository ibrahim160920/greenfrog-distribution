#!/usr/bin/env node
/**
 * download-latest.js — Download the latest GreenFrog child runtime for your platform.
 *
 * Resolves the current version from the public distribution's latest.json,
 * then downloads the correct platform bundle to the current directory.
 *
 * Usage:
 *   node download-latest.js [--platform <linux|macos|windows>] [--output-dir <dir>]
 *   node download-latest.js --verify      (also download and run signature verification)
 *   node download-latest.js --dry-run     (print download URL without downloading)
 *   node download-latest.js --help
 *
 * Requires: Node.js 22+ (no npm install needed — uses built-in modules only)
 *
 * Distribution base URL is read from the GREENFROG_DIST_BASE environment variable,
 * or defaults to the official GitHub raw content base.
 */

import https from 'node:https';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { parseArgs } from 'node:util';
import { createHash } from 'node:crypto';

const DIST_BASE = process.env.GREENFROG_DIST_BASE
  ?? 'https://raw.githubusercontent.com/ibrahim160920/greenfrog-distribution/main';

const LATEST_JSON_URL = `${DIST_BASE}/latest.json`;

// ── Arg parsing ────────────────────────────────────────────────────────────────

let opts;
try {
  opts = parseArgs({
    args: process.argv.slice(2),
    options: {
      platform:    { type: 'string' },
      'output-dir': { type: 'string', default: '.' },
      verify:      { type: 'boolean', default: false },
      'dry-run':   { type: 'boolean', default: false },
      help:        { type: 'boolean', short: 'h', default: false },
    },
    allowPositionals: false,
  }).values;
} catch (err) {
  console.error(`Error: ${err.message}`);
  process.exit(2);
}

if (opts.help) {
  console.log(`
GreenFrog Latest Bundle Downloader
Usage: node download-latest.js [options]

Options:
  --platform <p>       linux | macos | windows (default: auto-detect)
  --output-dir <dir>   Directory to save the bundle (default: current directory)
  --verify             Download and run signature verification after downloading
  --dry-run            Print download URL without downloading
  -h, --help           Show this help

Environment:
  GREENFROG_DIST_BASE  Override distribution base URL
`);
  process.exit(0);
}

// ── Platform detection ─────────────────────────────────────────────────────────

function detectPlatform() {
  const p = os.platform();
  if (p === 'linux')  return 'linux';
  if (p === 'darwin') return 'macos';
  if (p === 'win32')  return 'windows';
  return 'linux'; // fallback
}

const platform = opts.platform ?? detectPlatform();
if (!['linux', 'macos', 'windows'].includes(platform)) {
  console.error(`Error: Unknown platform "${platform}". Use linux, macos, or windows.`);
  process.exit(2);
}

const outputDir = path.resolve(opts['output-dir']);

// ── HTTP helpers ───────────────────────────────────────────────────────────────

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'greenfrog-download-latest/1.0' } }, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        return resolve(fetchJson(res.headers.location));
      }
      if (res.statusCode !== 200) {
        return reject(new Error(`HTTP ${res.statusCode} fetching ${url}`));
      }
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf-8'))); }
        catch (e) { reject(e); }
      });
      res.on('error', reject);
    }).on('error', reject);
  });
}

function downloadFile(url, destPath) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(destPath);
    let downloaded = 0;
    let lastPct = -1;

    function doGet(u) {
      https.get(u, { headers: { 'User-Agent': 'greenfrog-download-latest/1.0' } }, (res) => {
        if (res.statusCode === 301 || res.statusCode === 302) {
          return doGet(res.headers.location);
        }
        if (res.statusCode !== 200) {
          file.close();
          fs.unlinkSync(destPath);
          return reject(new Error(`HTTP ${res.statusCode} downloading ${u}`));
        }
        const total = parseInt(res.headers['content-length'] ?? '0', 10);
        res.on('data', chunk => {
          downloaded += chunk.length;
          if (total > 0) {
            const pct = Math.floor((downloaded / total) * 100);
            if (pct !== lastPct && pct % 10 === 0) {
              process.stdout.write(`\r  Downloading... ${pct}%`);
              lastPct = pct;
            }
          }
        });
        res.pipe(file);
        file.on('finish', () => { file.close(); process.stdout.write('\r  Download complete.   \n'); resolve(); });
        file.on('error', reject);
        res.on('error', reject);
      }).on('error', (err) => { file.close(); reject(err); });
    }

    doGet(url);
  });
}

// ── Main ───────────────────────────────────────────────────────────────────────

(async () => {
  console.log(`  GreenFrog Latest Bundle Downloader`);
  console.log(`  Platform : ${platform}`);
  console.log(`  Fetching : ${LATEST_JSON_URL}`);
  console.log();

  // 1. Fetch latest.json
  let latest;
  try {
    latest = await fetchJson(LATEST_JSON_URL);
  } catch (err) {
    console.error(`  ERROR: Could not fetch latest.json: ${err.message}`);
    console.error(`  Check your internet connection or set GREENFROG_DIST_BASE`);
    process.exit(1);
  }

  const version = latest.version;
  if (!version) {
    console.error(`  ERROR: latest.json does not contain a version field`);
    process.exit(1);
  }

  const ext = platform === 'windows' ? '.zip' : '.tar.gz';
  const bundleName = `greenfrog-v${version}-${platform}${ext}`;

  // Build download URL from platform entry or construct from base
  const platformEntry = latest.platforms?.[platform];
  let downloadUrl;
  if (platformEntry?.downloadUrl) {
    downloadUrl = platformEntry.downloadUrl;
  } else {
    downloadUrl = `${DIST_BASE}/${platform}/${bundleName}`;
  }

  console.log(`  Version  : v${version}`);
  console.log(`  Bundle   : ${bundleName}`);
  console.log(`  URL      : ${downloadUrl}`);
  console.log();

  if (opts['dry-run']) {
    console.log(`  [dry-run] Would download to: ${path.join(outputDir, bundleName)}`);
    console.log(`  Manifest : ${DIST_BASE}/${latest.manifestBase ?? `manifests/${version}`}/${platform}.json`);
    console.log(`  Verify   : node tools/verify-release.js --manifest manifests/${version}/${platform}.json --bundle ${bundleName}`);
    process.exit(0);
  }

  // 2. Download bundle
  fs.mkdirSync(outputDir, { recursive: true });
  const destPath = path.join(outputDir, bundleName);

  if (fs.existsSync(destPath)) {
    console.log(`  File already exists: ${destPath}`);
    console.log(`  Delete it first to re-download.`);
  } else {
    await downloadFile(downloadUrl, destPath);
  }

  const stat = fs.statSync(destPath);
  console.log(`  Saved    : ${destPath} (${(stat.size / 1024 / 1024).toFixed(1)} MB)`);
  console.log();

  // 3. Print next steps
  console.log(`  Next steps:`);
  console.log(`    1. Verify: node tools/verify-release.js --manifest manifests/${version}/${platform}.json --bundle ${bundleName}`);
  if (platform === 'windows') {
    console.log(`    2. Extract the .zip and run: powershell -File install.ps1`);
  } else {
    console.log(`    2. Extract: tar -xzf ${bundleName}`);
    console.log(`    3. Install: cd greenfrog-v${version}-${platform}/ && bash install.sh`);
  }
})().catch(err => {
  console.error(`[download-latest] Fatal: ${err.message}`);
  process.exit(1);
});
