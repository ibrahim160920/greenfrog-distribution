#!/usr/bin/env bash
# GreenFrog Linux Installer
# ============================================================
# Installs the GreenFrog child runtime to <extract-parent>/GreenFrog/runtime
# and creates a launch wrapper at <extract-parent>/GreenFrog/bin/greenfrog.
#
# Usage:
#   bash install.sh [--enrollment-url <url>] [--data-dir <dir>]
#
# Options:
#   --enrollment-url <url>   Enrollment server URL (optional).
#                            For managed/organization deployments only.
#                            Writes to config.sh automatically.
#                            Omit for personal use — GreenFrog starts locally
#                            without any server configuration.
#   --data-dir <dir>         Override installation directory
#                            (default: <parent of extraction dir>/GreenFrog)
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# ── Defaults ──────────────────────────────────────────────────────────────────
# Default: install to a visible GreenFrog directory next to the extraction dir.
#   e.g. extracted to /home/user/Downloads/greenfrog-v1.4.0-linux/
#        installs to  /home/user/Downloads/GreenFrog
# GF_BASE_DIR env var or --data-dir flag override this default.
DATA_DIR="${GF_BASE_DIR:-$PARENT_DIR/GreenFrog}"
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
      echo "  --data-dir <dir>         Override install directory"
      echo "                           Default: <parent of extraction dir>/GreenFrog"
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
echo "  GreenFrog — Child Runtime Installer (Linux)"
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
  echo "    Ubuntu/Debian:"
  echo "      curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
  echo "      sudo apt-get install -y nodejs"
  echo
  echo "    Fedora/RHEL:    sudo dnf install nodejs"
  echo "    Arch Linux:     sudo pacman -S nodejs npm"
  echo "    Generic:        https://nodejs.org/en/download/"
  echo
  exit 1
fi

NODE_VERSION=$(node --version | sed 's/v//')
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo
  echo "  ERROR: Node.js $NODE_VERSION detected. Version 22 or later is required."
  echo "  Upgrade: https://nodejs.org/en/download/"
  echo
  exit 1
fi
echo "  Node.js v$NODE_VERSION — OK"
echo

# ── Step 2: Create directory structure ───────────────────────────────────────
echo "  Creating directories..."
mkdir -p "$RUNTIME_DIR" "$BIN_DIR" "$LOGS_DIR" "$CACHE_DIR"
mkdir -p "$DATA_DIR/identity" "$DATA_DIR/backflow" "$DATA_DIR/inheritance" "$DATA_DIR/update-cache"
echo "  Runtime  : $RUNTIME_DIR"
echo "  Data     : $DATA_DIR"
echo "  Logs     : $LOGS_DIR"
echo

# ── Step 3: Copy runtime files ────────────────────────────────────────────────
# Source is always the extraction directory (where install.sh lives).
# NEVER use ./* -- that copies from the current working directory, not the bundle.
echo "  Copying runtime files..."
if [ -d "$SCRIPT_DIR/runtime" ]; then
  # Bundle has explicit runtime/ subdirectory
  cp -r "$SCRIPT_DIR/runtime/." "$RUNTIME_DIR/"
else
  # Standard bundle layout: runtime files live alongside install.sh
  cp -r "$SCRIPT_DIR/." "$RUNTIME_DIR/"
  rm -f "$RUNTIME_DIR/install.sh" "$RUNTIME_DIR/public-key.pem" "$RUNTIME_DIR/bootstrap.bat"
fi

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
# Key is in the extraction directory alongside install.sh
if [ -f "$SCRIPT_DIR/public-key.pem" ]; then
  cp "$SCRIPT_DIR/public-key.pem" "$DATA_DIR/public-key.pem"
  echo "  Public key installed."
elif [ -f "$SCRIPT_DIR/../public-key.pem" ]; then
  cp "$SCRIPT_DIR/../public-key.pem" "$DATA_DIR/public-key.pem"
  echo "  Public key installed."
else
  echo "  WARNING: public-key.pem not found — manifest signature verification will be unavailable."
fi
echo

# ── Step 5: Write config (preserving existing) ────────────────────────────────
CONFIG_FILE="$DATA_DIR/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
  TEMPLATE=""
  for loc in "$SCRIPT_DIR/config.sh.template" "$SCRIPT_DIR/../runtime/config.sh.template"; do
    [ -f "$loc" ] && TEMPLATE="$loc" && break
  done

  if [ -n "$TEMPLATE" ]; then
    cp "$TEMPLATE" "$CONFIG_FILE"
  else
    cat > "$CONFIG_FILE" <<'CONF'
# GreenFrog Configuration
# Personal mode is the default — no server configuration required.
# GreenFrog runs locally and initializes its own identity on first launch.
#
# To connect to a managed distribution server (organizations / advanced use):
# export GF_ENROLLMENT_URL="https://your-server.example.com/api/distribution/enroll"
# export GF_DISTRIBUTION_URL="https://your-server.example.com"
#
# export GF_LOCALE=""  # Leave unset to auto-detect system locale
CONF
  fi
  echo "  Config created at: $CONFIG_FILE"
fi

# Write enrollment URL if provided via --enrollment-url (optional; only for managed deployments)
if [ -n "$ENROLLMENT_URL" ]; then
  if grep -q 'GF_ENROLLMENT_URL' "$CONFIG_FILE" 2>/dev/null; then
    sed -i "s|.*GF_ENROLLMENT_URL.*|export GF_ENROLLMENT_URL=\"$ENROLLMENT_URL\"|" "$CONFIG_FILE"
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
  SHELL_PROFILE="$HOME/.bashrc"
  [ -n "${ZSH_VERSION:-}" ] && SHELL_PROFILE="$HOME/.zshrc"
  [ -f "$HOME/.zshrc" ] && SHELL_PROFILE="$HOME/.zshrc"

  echo "  Add GreenFrog to your PATH — run these two commands:"
  echo
  echo "    echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> $SHELL_PROFILE"
  echo "    source $SHELL_PROFILE"
  echo
  echo "  Or use the full path: $LAUNCHER"
fi
echo
echo "  Next steps:"
echo
if [ -n "$ENROLLMENT_URL" ]; then
  echo "    Enrollment URL configured. GreenFrog will connect to your server on first launch."
  echo "    Run: greenfrog"
else
  echo "    GreenFrog is ready. Run it now:"
  echo
  echo "      greenfrog"
  echo
  echo "    On first launch, GreenFrog initializes its local identity automatically."
  echo "    No server configuration is required for personal use."
  echo
  echo "    For managed/organization deployments, set your server URL:"
  echo "      greenfrog --enrollment-url https://your-server/api/distribution/enroll"
fi
echo
echo "$SEP"
