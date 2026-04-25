#!/usr/bin/env bash
set -euo pipefail

APP_VERSION="${APP_VERSION:-dev-local}"
APP_NAME="${APP_NAME:-$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')}"
OUTPUT_DIR="dist"

# ===== PLATFORM TOGGLES (DELETE WHAT YOU DON'T NEED) =====
BUILD_LINUX="${BUILD_LINUX:-1}"
BUILD_WINDOWS="${BUILD_WINDOWS:-1}"
# ==========================================================

command -v cargo >/dev/null 2>&1 || { echo "ERROR: cargo no instalado"; exit 1; }
mkdir -p "$OUTPUT_DIR"

# ===== LINUX BUILD START (delete this block if linux is not needed) =====
if [ "$BUILD_LINUX" = "1" ]; then
  RUSTFLAGS="-C strip=symbols" cargo build --release
  cp "target/release/$APP_NAME" "$OUTPUT_DIR/$APP_NAME"
  [ -f "$OUTPUT_DIR/$APP_NAME" ] || { echo "ERROR: falta ELF Linux"; exit 1; }
fi
# ===== LINUX BUILD END =====

# ===== WINDOWS BUILD START (delete this block if windows is not needed) =====
if [ "$BUILD_WINDOWS" = "1" ]; then
  command -v rustup >/dev/null 2>&1 || { echo "ERROR: rustup no instalado"; exit 1; }
  rustup target add x86_64-pc-windows-gnu >/dev/null

  if ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
    echo "ERROR: falta linker MinGW (x86_64-w64-mingw32-gcc) para Windows cross-build."
    exit 1
  fi

  cargo build --release --target x86_64-pc-windows-gnu
  cp "target/x86_64-pc-windows-gnu/release/$APP_NAME.exe" "$OUTPUT_DIR/$APP_NAME.exe"
  [ -f "$OUTPUT_DIR/$APP_NAME.exe" ] || { echo "ERROR: falta EXE Windows"; exit 1; }
fi
# ===== WINDOWS BUILD END =====

echo "[+] Artifacts generados en ${OUTPUT_DIR}/"
