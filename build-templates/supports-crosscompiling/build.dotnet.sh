#!/usr/bin/env bash
set -euo pipefail

APP_VERSION="${APP_VERSION:-dev-local}"
APP_NAME="${APP_NAME:-$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')}"
OUTPUT_DIR="dist"

# ===== PLATFORM TOGGLES (DELETE WHAT YOU DON'T NEED) =====
BUILD_LINUX="${BUILD_LINUX:-1}"
BUILD_WINDOWS="${BUILD_WINDOWS:-1}"
# ==========================================================

command -v dotnet >/dev/null 2>&1 || { echo "ERROR: dotnet no instalado"; exit 1; }
mkdir -p "$OUTPUT_DIR"
DOTNET_CLI_TELEMETRY_OPTOUT=1 dotnet restore

# ===== LINUX BUILD START (delete this block if linux is not needed) =====
if [ "$BUILD_LINUX" = "1" ]; then
  DOTNET_CLI_TELEMETRY_OPTOUT=1 dotnet publish -c Release -r linux-x64 --self-contained true -p:Version="$APP_VERSION" -o "$OUTPUT_DIR/linux"
  cp "$OUTPUT_DIR/linux/$APP_NAME" "$OUTPUT_DIR/$APP_NAME"
  [ -f "$OUTPUT_DIR/$APP_NAME" ] || { echo "ERROR: falta binario Linux"; exit 1; }
fi
# ===== LINUX BUILD END =====

# ===== WINDOWS BUILD START (delete this block if windows is not needed) =====
if [ "$BUILD_WINDOWS" = "1" ]; then
  DOTNET_CLI_TELEMETRY_OPTOUT=1 dotnet publish -c Release -r win-x64 --self-contained true -p:Version="$APP_VERSION" -o "$OUTPUT_DIR/win"
  cp "$OUTPUT_DIR/win/$APP_NAME.exe" "$OUTPUT_DIR/$APP_NAME.exe"
  [ -f "$OUTPUT_DIR/$APP_NAME.exe" ] || { echo "ERROR: falta EXE Windows"; exit 1; }
fi
# ===== WINDOWS BUILD END =====

echo "[+] Artifacts generados en ${OUTPUT_DIR}/"
