#!/usr/bin/env bash
set -euo pipefail

APP_VERSION="${APP_VERSION:-dev-local}"
ENTRY_POINT="acronyms_v5.py"
APP_NAME="Acronyms"
OUTPUT_DIR="dist"

# ===== PLATFORM TOGGLES (DELETE WHAT YOU DON'T NEED) =====
BUILD_LINUX="${BUILD_LINUX:-1}"
BUILD_WINDOWS="${BUILD_WINDOWS:-1}"
# ==========================================================

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 no instalado"; exit 1; }
python3 -m pip install --upgrade pip >/dev/null
python3 -m pip install pyinstaller >/dev/null

mkdir -p "$OUTPUT_DIR"
TMP_VERSION_FILE="version.py"
echo "__version__ = '$APP_VERSION'" > "$TMP_VERSION_FILE"

cleanup() { rm -f "$TMP_VERSION_FILE"; }
trap cleanup EXIT

OS_NAME="$(uname -s || echo unknown)"
LINUX_DONE=0
WINDOWS_DONE=0

# ===== LINUX BUILD START (delete this block if linux is not needed) =====
if [ "$BUILD_LINUX" = "1" ]; then
  if [ "$OS_NAME" = "Linux" ]; then
    pyinstaller --onefile --name "$APP_NAME" --distpath "$OUTPUT_DIR" "$ENTRY_POINT"
    [ -f "$OUTPUT_DIR/$APP_NAME" ] || { echo "ERROR: falta binario Linux en dist/"; exit 1; }
    LINUX_DONE=1
  fi
fi
# ===== LINUX BUILD END =====

# ===== WINDOWS BUILD START (delete this block if windows is not needed) =====
if [ "$BUILD_WINDOWS" = "1" ]; then
  case "$OS_NAME" in
    MINGW*|MSYS*|CYGWIN*)
      pyinstaller --onefile --name "$APP_NAME" --distpath "$OUTPUT_DIR" "$ENTRY_POINT"
      [ -f "$OUTPUT_DIR/$APP_NAME.exe" ] || { echo "ERROR: falta .exe Windows en dist/"; exit 1; }
      WINDOWS_DONE=1
      ;;
  esac
fi
# ===== WINDOWS BUILD END =====

if [ "$BUILD_LINUX" = "1" ] && [ "$LINUX_DONE" -ne 1 ]; then
  echo "ERROR: Linux build habilitado pero no ejecutado. Usa runner Linux o BUILD_LINUX=0."
  exit 1
fi

if [ "$BUILD_WINDOWS" = "1" ] && [ "$WINDOWS_DONE" -ne 1 ]; then
  echo "ERROR: Windows build habilitado pero no ejecutado."
  echo "Python + PyInstaller no cross-compila .exe desde Linux de forma soportada en esta plantilla."
  echo "Solucion: ejecuta este mismo script en runner Windows o usa BUILD_WINDOWS=0."
  exit 1
fi

echo "[+] Artifacts generados en ${OUTPUT_DIR}/"
