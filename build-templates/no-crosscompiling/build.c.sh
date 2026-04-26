#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  C BUILD SCRIPT (Make-based, native per-OS)
#
#  Cross-compiling C/C++ with system dependencies is fragile, so each platform
#  builds on its own native runner. Defaults to Makefile; switch to CMake by
#  replacing the BUILD STEPS block.
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
OS_NAME="$(uname -s || echo unknown)"

mkdir -p "$OUTPUT_DIR"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ ⚙️   PROJECT CONFIG — FILL IN                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Compiler. Override with CC=clang on the workflow if you prefer clang.
CC_BIN="${CC:-gcc}"

# Make target. Empty = default target (usually `all`). Override per project.
MAKE_TARGET="${MAKE_TARGET:-}"

# Where Make leaves the binary. Some Makefiles write to ./build/, some to ./bin/,
# some to the project root. Adjust this to match your Makefile output.
BUILT_BINARY_LINUX="$APP_NAME"
BUILT_BINARY_WINDOWS="${APP_NAME}.exe"

# Extra make flags. -jN for parallelism, VAR=value for Makefile variables.
EXTRA_MAKE_FLAGS=(-j"$(nproc 2>/dev/null || echo 2)")
# Example: EXTRA_MAKE_FLAGS+=(CFLAGS="-O2 -DNDEBUG")
# Example: EXTRA_MAKE_FLAGS+=(VERSION="$APP_VERSION")


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔨  BUILD STEPS — EDIT / ADD / REMOVE FREELY                               ║
# ║                                                                           ║
# ║  The default uses GNU make. Replace this entire block to use CMake,       ║
# ║  Meson, or raw gcc invocations.                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

command -v make >/dev/null 2>&1 || { echo "ERROR: make is not installed"; exit 1; }
command -v "$CC_BIN" >/dev/null 2>&1 || { echo "ERROR: $CC_BIN is not installed"; exit 1; }
[ -f Makefile ] || [ -f makefile ] || { echo "ERROR: Makefile not found in $PWD"; exit 1; }

# Inject APP_VERSION as a -D flag so the source can use it.
export CFLAGS="${CFLAGS:-} -DAPP_VERSION=\"$APP_VERSION\""

# Clean previous artefacts (best-effort).
make clean >/dev/null 2>&1 || true

LINUX_DONE=0
WINDOWS_DONE=0

# ─── Linux build (delete this block if you don't ship Linux) ───────────────
if [ "$BUILD_LINUX" = "1" ] && [ "$OS_NAME" = "Linux" ]; then
  CC="$CC_BIN" make $MAKE_TARGET "${EXTRA_MAKE_FLAGS[@]}"
  [ -f "$BUILT_BINARY_LINUX" ] || { echo "ERROR: Make did not produce $BUILT_BINARY_LINUX"; exit 1; }
  cp "$BUILT_BINARY_LINUX" "$OUTPUT_DIR/$APP_NAME"
  chmod +x "$OUTPUT_DIR/$APP_NAME"
  LINUX_DONE=1
fi

# ─── Windows build (delete this block if you don't ship Windows) ───────────
if [ "$BUILD_WINDOWS" = "1" ]; then
  case "$OS_NAME" in MINGW*|MSYS*|CYGWIN*)
    CC="$CC_BIN" make $MAKE_TARGET "${EXTRA_MAKE_FLAGS[@]}"
    [ -f "$BUILT_BINARY_WINDOWS" ] || { echo "ERROR: Make did not produce $BUILT_BINARY_WINDOWS"; exit 1; }
    cp "$BUILT_BINARY_WINDOWS" "$OUTPUT_DIR/$APP_NAME.exe"
    WINDOWS_DONE=1
    ;;
  esac
fi


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔒  LAUNCHER CONTRACT — DO NOT EDIT                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
if [ "$BUILD_LINUX" = "1" ] && [ "$LINUX_DONE" -ne 1 ]; then
  echo "ERROR: BUILD_LINUX=1 but this job is not running on Linux. Use a Linux runner or set BUILD_LINUX=0."; exit 1
fi
if [ "$BUILD_WINDOWS" = "1" ] && [ "$WINDOWS_DONE" -ne 1 ]; then
  echo "ERROR: BUILD_WINDOWS=1 but this job is not running on Windows. C does not cross-compile by default."; exit 1
fi
echo "[+] Artifacts written to $OUTPUT_DIR/"
