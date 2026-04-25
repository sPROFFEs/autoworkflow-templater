#!/usr/bin/env bash
set -euo pipefail

APP_VERSION="${APP_VERSION:-dev-local}"
OUTPUT_DIR="dist"

# ===== PLATFORM TOGGLES (DELETE WHAT YOU DON'T NEED) =====
BUILD_LINUX="${BUILD_LINUX:-1}"
BUILD_WINDOWS="${BUILD_WINDOWS:-1}"
# ==========================================================

# Auto-detect APP_NAME from the project directory if not provided
APP_NAME="${APP_NAME:-$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')}"

# Auto-detect ENTRY_POINT: check common conventions before giving up
ENTRY_POINT="${ENTRY_POINT:-}"
if [ -z "$ENTRY_POINT" ]; then
  for candidate in main.py app.py src/main.py src/app.py __main__.py; do
    if [ -f "$candidate" ]; then
      ENTRY_POINT="$candidate"
      break
    fi
  done
  [ -n "$ENTRY_POINT" ] || {
    echo "ERROR: no se encontró entry point Python."
    echo "Define la variable ENTRY_POINT=<archivo>.py o crea main.py en la raíz."
    exit 1
  }
fi

# Resolve Python interpreter: Windows runners expose 'python', not 'python3'
PYTHON_CMD=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_CMD="python"
else
  echo "ERROR: python/python3 no instalado"
  exit 1
fi

$PYTHON_CMD -m pip install --upgrade pip >/dev/null
$PYTHON_CMD -m pip install pyinstaller >/dev/null

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
    $PYTHON_CMD -m PyInstaller --onefile --name "$APP_NAME" --distpath "$OUTPUT_DIR" "$ENTRY_POINT"
    [ -f "$OUTPUT_DIR/$APP_NAME" ] || { echo "ERROR: falta binario Linux en dist"; exit 1; }
    LINUX_DONE=1
  fi
fi
# ===== LINUX BUILD END =====

# ===== WINDOWS BUILD START (delete this block if windows is not needed) =====
if [ "$BUILD_WINDOWS" = "1" ]; then
  case "$OS_NAME" in
    MINGW*|MSYS*|CYGWIN*)
      $PYTHON_CMD -m PyInstaller --onefile --name "$APP_NAME" --distpath "$OUTPUT_DIR" "$ENTRY_POINT"
      [ -f "$OUTPUT_DIR/$APP_NAME.exe" ] || { echo "ERROR: falta EXE Windows en dist"; exit 1; }
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
  echo "PyInstaller no cross-compila .exe desde Linux de forma soportada en esta plantilla."
  echo "Usa runner Windows o BUILD_WINDOWS=0."
  exit 1
fi

echo "[+] Artifacts generados en ${OUTPUT_DIR}/"
