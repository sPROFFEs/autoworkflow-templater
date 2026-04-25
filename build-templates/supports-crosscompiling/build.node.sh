#!/usr/bin/env bash
set -euo pipefail

APP_VERSION="${APP_VERSION:-dev-local}"
APP_NAME="${APP_NAME:-$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')}"
OUTPUT_DIR="dist"

# ===== PLATFORM TOGGLES (DELETE WHAT YOU DON'T NEED) =====
BUILD_LINUX="${BUILD_LINUX:-1}"
BUILD_WINDOWS="${BUILD_WINDOWS:-1}"
# ==========================================================

command -v node >/dev/null 2>&1 || { echo "ERROR: node no instalado"; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "ERROR: npm no instalado"; exit 1; }

# Auto-detect ENTRY_POINT: package.json "main" field, then common file locations
ENTRY_POINT="${ENTRY_POINT:-}"
if [ -z "$ENTRY_POINT" ]; then
  if command -v node >/dev/null 2>&1 && [ -f package.json ]; then
    ENTRY_POINT="$(node -e "try{const p=require('./package.json');if(p.main)process.stdout.write(p.main)}catch(e){}" 2>/dev/null || true)"
  fi
  if [ -z "$ENTRY_POINT" ]; then
    for candidate in src/index.js index.js src/main.js main.js; do
      if [ -f "$candidate" ]; then
        ENTRY_POINT="$candidate"
        break
      fi
    done
  fi
  [ -n "$ENTRY_POINT" ] || {
    echo "ERROR: no se encontró entry point Node."
    echo "Define ENTRY_POINT=<archivo>.js o establece 'main' en package.json."
    exit 1
  }
fi

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
