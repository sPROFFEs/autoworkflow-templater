#!/usr/bin/env bash
set -euo pipefail

APP_VERSION="${APP_VERSION:-dev-local}"
APP_NAME="my_tool"
ENTRY_POINT="src/index.js"
OUTPUT_DIR="dist"

# ===== PLATFORM TOGGLES (DELETE WHAT YOU DON'T NEED) =====
BUILD_LINUX="${BUILD_LINUX:-1}"
BUILD_WINDOWS="${BUILD_WINDOWS:-1}"
# ==========================================================

command -v node >/dev/null 2>&1 || { echo "ERROR: node no instalado"; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "ERROR: npm no instalado"; exit 1; }

mkdir -p "$OUTPUT_DIR"
npm ci

# Empaquetado recomendado para binarios multiplataforma.
npm install --no-save pkg >/dev/null

TARGETS=()
# ===== LINUX BUILD START (delete this block if linux is not needed) =====
if [ "$BUILD_LINUX" = "1" ]; then
  TARGETS+=("node20-linux-x64")
fi
# ===== LINUX BUILD END =====

# ===== WINDOWS BUILD START (delete this block if windows is not needed) =====
if [ "$BUILD_WINDOWS" = "1" ]; then
  TARGETS+=("node20-win-x64")
fi
# ===== WINDOWS BUILD END =====

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "ERROR: no hay targets habilitados (BUILD_LINUX/BUILD_WINDOWS)."
  exit 1
fi

npx pkg "$ENTRY_POINT" --targets "$(IFS=,; echo "${TARGETS[*]}")" --output "$OUTPUT_DIR/$APP_NAME"

if [ "$BUILD_LINUX" = "1" ]; then
  [ -f "$OUTPUT_DIR/$APP_NAME" ] || { echo "ERROR: falta binario Linux"; exit 1; }
fi
if [ "$BUILD_WINDOWS" = "1" ]; then
  [ -f "$OUTPUT_DIR/$APP_NAME.exe" ] || { echo "ERROR: falta EXE Windows"; exit 1; }
fi

echo "[+] Artifacts generados en ${OUTPUT_DIR}/"
