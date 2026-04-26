#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  NODE.JS BUILD SCRIPT (cross-compiling via vercel/pkg)
#
#  Three zones below:
#    🔒 LAUNCHER CONTRACT   — do not edit, the CI workflow depends on this
#    ⚙️  PROJECT CONFIG      — fill in for your project
#    🔨 BUILD STEPS         — edit / add / remove freely
#
#  See BUILD_CONTRACT.md at the repo root for the full contract.
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔒  LAUNCHER CONTRACT — DO NOT EDIT                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
APP_VERSION="${APP_VERSION:-dev-local}"
APP_NAME="${APP_NAME:-$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')}"
OUTPUT_DIR="dist"
BUILD_LINUX="${BUILD_LINUX:-1}"
BUILD_WINDOWS="${BUILD_WINDOWS:-1}"

command -v node >/dev/null 2>&1 || { echo "ERROR: node is not installed"; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "ERROR: npm is not installed";  exit 1; }
mkdir -p "$OUTPUT_DIR"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ ⚙️   PROJECT CONFIG — FILL IN                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Entry point (auto-detected from package.json "main" or common locations).
ENTRY_POINT="${ENTRY_POINT:-}"
if [ -z "$ENTRY_POINT" ]; then
  if [ -f package.json ]; then
    ENTRY_POINT="$(node -e "try{const p=require('./package.json');if(p.main)process.stdout.write(p.main)}catch(e){}" 2>/dev/null || true)"
  fi
  if [ -z "$ENTRY_POINT" ]; then
    for c in src/index.js index.js src/main.js main.js dist/index.js; do
      [ -f "$c" ] && ENTRY_POINT="$c" && break
    done
  fi
  [ -n "$ENTRY_POINT" ] || {
    echo "ERROR: could not detect the Node.js entry point."
    echo "Set ENTRY_POINT=<file>.js or set the 'main' field in package.json."
    exit 1
  }
fi

# pkg target Node version. Match the version installed in CI.
PKG_NODE_VERSION="node20"

# Use `npm ci` (lockfile-strict) by default. Switch to `npm install` if you
# don't commit a lockfile, or to yarn/pnpm equivalents.
INSTALL_CMD="npm ci"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔨  BUILD STEPS — EDIT / ADD / REMOVE FREELY                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

$INSTALL_CMD
npm install --no-save pkg >/dev/null

TARGETS=()
[ "$BUILD_LINUX"   = "1" ] && TARGETS+=("$PKG_NODE_VERSION-linux-x64")
[ "$BUILD_WINDOWS" = "1" ] && TARGETS+=("$PKG_NODE_VERSION-win-x64")
[ "${#TARGETS[@]}" -gt 0 ] || { echo "ERROR: no build targets enabled (BUILD_LINUX and BUILD_WINDOWS are both 0)."; exit 1; }

npx pkg "$ENTRY_POINT" \
  --targets "$(IFS=,; echo "${TARGETS[*]}")" \
  --output "$OUTPUT_DIR/$APP_NAME"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔒  LAUNCHER CONTRACT — DO NOT EDIT                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
[ "$BUILD_LINUX"   = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME"     ] || { echo "ERROR: Linux binary missing in $OUTPUT_DIR/"; exit 1; }; }
[ "$BUILD_WINDOWS" = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME.exe" ] || { echo "ERROR: Windows EXE missing in $OUTPUT_DIR/"; exit 1; }; }
echo "[+] Artifacts written to $OUTPUT_DIR/"
