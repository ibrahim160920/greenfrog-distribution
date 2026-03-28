#!/usr/bin/env bash
# GreenFrog macOS Installer
# ============================================================
# Installs the GreenFrog child runtime to ~/.greenfrog/runtime
# and creates a launch wrapper at ~/.greenfrog/bin/greenfrog.
#
# Usage:
#   bash install.sh [--enrollment-url <url>] [--data-dir <dir>]
#
# Options:
#   --enrollment-url <url>   Mother-body enrollment endpoint.
#                            Writes to config.sh automatically.
#                            If omitted, you will be prompted on first launch.
#   --data-dir <dir>         Override installation directory
#                            (default: ~/.greenfrog)
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
DATA_DIR="${GF_BASE_DIR:-$HOME/.greenfrog}"
ENROLLMENT_URL=""

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --enrollment-url) ENROLLMENT_URL="$2"; shift 2 ;;
    --data-dir)       DATA_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: bash install.sh [--enrollment-url <url>] [--data-dir <dir>]"
      echo ""
      echo "  --enrollment-url <url>   Set enrollment server URL in config (optional)"
      echo "  --data-dir <dir>         Override install directory (default: ~/.greenfrog)"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

RUNTIME_DIR="$DATA_DIR/runtime"
BIN_DIR="$DATA_DIR/bin"
LOGS_DIR="$DATA_DIR/logs"
CACHE_DIR="$DATA_DIR/update-cache"

SEP="============================================================"

echo "$SEP"
echo "  GreenFrog — Child Runtime Installer (macOS)"
echo "$SEP"
echo

# ── Step 1: Check Node.js >= 22 ───────────────────────────────────────────────
echo "  Checking Node.js..."
if ! command -v node >/dev/null 2>&1; then
  echo
  echo "  ERROR: Node.js is not installed."
  echo
  echo "  Install Node.js 22 or later — choose one:"
  echo
  echo "    Homebrew (recommended):"
  echo "      brew install node"
  echo
  echo "    Official installer: https://nodejs.org/en/download/"
  echo
  echo "  If Homebrew is not installed:"
  echo "    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  echo
  exit 1
fi

NODE_VERSION=$(node --version | sed 's/v//')
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo
  echo "  ERROR: Node.js $NODE_VERSION detected. Version 22 or later is required."
  echo "  Upgrade: brew upgrade node  or  https://nodejs.org/en/download/"
  echo
  exit 1
fi
echo "  Node.js v$NODE_VERSION — OK"
echo

# ── Step 2: Create directory structure ───────────────────────────────────────
echo "  Creating directories..."
mkdir -p "$RUNTIME_DIR" "$BIN_DIR" "$LOGS_DIR" "$CACHE_DIR"
mkdir -p "$DATA_DIR/identity" "$DATA_DIR/backflow" "$DATA_DIR/inheritance"
echo "  Runtime  : $RUNTIME_DIR"
echo "  Data     : $DATA_DIR"
echo "  Logs     : $LOGS_DIR"
echo

# ── Step 3: Copy runtime files ────────────────────────────────────────────────
echo "  Copying runtime files..."
cp -r "$SCRIPT_DIR"/../runtime/. "$RUNTIME_DIR/" 2>/dev/null || \
  cp -r ./* "$RUNTIME_DIR/" 2>/dev/null || true

if [ ! -f "$RUNTIME_DIR/index.js" ]; then
  echo
  echo "  ERROR: index.js not found in runtime bundle."
  echo "  The installation package may be incomplete."
  echo
  exit 1
fi
echo "  Runtime files installed."
echo

# ── Step 4: Copy public key ───────────────────────────────────────────────────
if [ -f "$SCRIPT_DIR/../public-key.pem" ]; then
  cp "$SCRIPT_DIR/../public-key.pem" "$DATA_DIR/public-key.pem"
  echo "  Public key installed."
elif [ -f "./public-key.pem" ]; then
  cp "./public-key.pem" "$DATA_DIR/public-key.pem"
  echo "  Public key installed."
else
  echo "  WARNING: public-key.pem not found — manifest signature verification will be unavailable."
fi
echo

# ── Step 5: Write config (preserving existing) ────────────────────────────────
CONFIG_FILE="$DATA_DIR/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
  TEMPLATE=""
  for loc in "$SCRIPT_DIR/../runtime/config.sh.template" "./config.sh.template"; do
    [ -f "$loc" ] && TEMPLATE="$loc" && break
  done

  if [ -n "$TEMPLATE" ]; then
    cp "$TEMPLATE" "$CONFIG_FILE"
  else
    cat > "$CONFIG_FILE" <<'CONF'
# GreenFrog Child Instance Configuration
# export GF_ENROLLMENT_URL="https://your-server.example.com/api/distribution/enroll"
# export GF_DISTRIBUTION_URL="https://your-server.example.com"
# export GF_LOCALE=""  # Leave unset to auto-detect system locale
CONF
  fi
  echo "  Config created at: $CONFIG_FILE"
fi

# Write enrollment URL if provided via --enrollment-url
if [ -n "$ENROLLMENT_URL" ]; then
  if grep -q 'GF_ENROLLMENT_URL' "$CONFIG_FILE" 2>/dev/null; then
    sed -i '' "s|.*GF_ENROLLMENT_URL.*|export GF_ENROLLMENT_URL=\"$ENROLLMENT_URL\"|" "$CONFIG_FILE"
  else
    echo "" >> "$CONFIG_FILE"
    echo "export GF_ENROLLMENT_URL=\"$ENROLLMENT_URL\"" >> "$CONFIG_FILE"
  fi
  echo "  Enrollment URL written to config: $ENROLLMENT_URL"
fi
echo

# ── Step 6: Create launch wrapper ────────────────────────────────────────────
LAUNCHER="$BIN_DIR/greenfrog"
cat > "$LAUNCHER" <<LAUNCHER
#!/usr/bin/env bash
# GreenFrog Child Runtime Launcher
# Auto-generated by installer — do not edit manually
set -euo pipefail
CONFIG_FILE="$CONFIG_FILE"
RUNTIME_DIR="$RUNTIME_DIR"
source "\$CONFIG_FILE" 2>/dev/null || true
export GF_IS_CHILD_INSTANCE=true
export GF_BASE_DIR="\${GF_BASE_DIR:-$DATA_DIR}"
exec node "\$RUNTIME_DIR/index.js" "\$@"
LAUNCHER
chmod +x "$LAUNCHER"
echo "  Launcher created: $LAUNCHER"
echo

# ── Step 7: PATH guidance ─────────────────────────────────────────────────────
echo "$SEP"
echo "  Installation complete!"
echo "$SEP"
echo

if echo "$PATH" | grep -q "$BIN_DIR"; then
  echo "  $BIN_DIR is already in your PATH."
else
  # Detect shell profile
  SHELL_PROFILE="$HOME/.zshrc"
  if [ -n "${BASH_VERSION:-}" ]; then
    SHELL_PROFILE="$HOME/.bash_profile"
  fi

  echo "  Add GreenFrog to your PATH — run these two commands:"
  echo
  echo "    echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> $SHELL_PROFILE"
  echo "    source $SHELL_PROFILE"
  echo
  echo "  Or use the full path: $LAUNCHER"
fi
echo
echo "  Next steps:"

if [ -n "$ENROLLMENT_URL" ]; then
  echo "    Enrollment URL is set. Run: greenfrog"
  echo "    GreenFrog will complete enrollment automatically on first launch."
else
  echo "    1. Set your enrollment URL (provided by your administrator):"
  echo "       Run: greenfrog --enrollment-url https://your-server/api/distribution/enroll"
  echo "       Or edit: $CONFIG_FILE"
  echo "    2. Then run: greenfrog"
fi
echo
echo "$SEP"
