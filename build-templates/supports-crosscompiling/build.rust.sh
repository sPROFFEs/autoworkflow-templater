#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  RUST BUILD SCRIPT (cross-compiling via x86_64-pc-windows-gnu)
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

command -v cargo >/dev/null 2>&1 || { echo "ERROR: cargo no instalado"; exit 1; }
mkdir -p "$OUTPUT_DIR"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ ⚙️   PROJECT CONFIG — FILL IN                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Cargo profile. "release" by default. Use a custom profile name from Cargo.toml
# (e.g. "release-lto") if you defined one.
CARGO_PROFILE="release"

# Rustflags applied to every target. -C strip=symbols shrinks the binary.
export RUSTFLAGS="${RUSTFLAGS:--C strip=symbols}"

# Extra cargo flags. Add --features, --no-default-features, workspace selectors here.
EXTRA_CARGO_FLAGS=()
# Example: EXTRA_CARGO_FLAGS+=(--features "tls,zstd")
# Example: EXTRA_CARGO_FLAGS+=(--bin "$APP_NAME")    # for workspaces

# Windows cross-target. x86_64-pc-windows-gnu uses MinGW (linker required on
# the Linux runner). x86_64-pc-windows-msvc requires lld + Windows SDK.
WIN_TARGET="x86_64-pc-windows-gnu"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔨  BUILD STEPS — EDIT / ADD / REMOVE FREELY                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ─── Linux build (delete this block if you don't ship Linux) ───────────────
if [ "$BUILD_LINUX" = "1" ]; then
  cargo build --profile "$CARGO_PROFILE" "${EXTRA_CARGO_FLAGS[@]}"
  # cargo writes to target/release/ for the default release profile and to
  # target/<profile>/ for any custom profile.
  REL_DIR="target/release"
  [ "$CARGO_PROFILE" != "release" ] && REL_DIR="target/$CARGO_PROFILE"
  cp "$REL_DIR/$APP_NAME" "$OUTPUT_DIR/$APP_NAME"
fi

# ─── Windows build (delete this block if you don't ship Windows) ───────────
if [ "$BUILD_WINDOWS" = "1" ]; then
  command -v rustup >/dev/null 2>&1 || { echo "ERROR: rustup no instalado"; exit 1; }
  rustup target add "$WIN_TARGET" >/dev/null
  if [[ "$WIN_TARGET" == *gnu* ]] && ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
    echo "ERROR: falta linker MinGW (x86_64-w64-mingw32-gcc) para Windows cross-build."
    exit 1
  fi
  cargo build --profile "$CARGO_PROFILE" --target "$WIN_TARGET" "${EXTRA_CARGO_FLAGS[@]}"
  REL_DIR="target/$WIN_TARGET/release"
  [ "$CARGO_PROFILE" != "release" ] && REL_DIR="target/$WIN_TARGET/$CARGO_PROFILE"
  cp "$REL_DIR/$APP_NAME.exe" "$OUTPUT_DIR/$APP_NAME.exe"
fi


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔒  LAUNCHER CONTRACT — DO NOT EDIT                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
[ "$BUILD_LINUX"   = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME"     ] || { echo "ERROR: falta ELF Linux en $OUTPUT_DIR/";  exit 1; }; }
[ "$BUILD_WINDOWS" = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME.exe" ] || { echo "ERROR: falta EXE Windows en $OUTPUT_DIR/"; exit 1; }; }
echo "[+] Artifacts generados en $OUTPUT_DIR/"
