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

# Resolve Python interpreter.
#
# Priority:
#   1. $pythonLocation (set by actions/setup-python) – avoids the Windows App
#      Execution Alias stub that intercepts 'python'/'python3' on the PATH and
#      exits with code 49 when no argument is the Microsoft Store redirect.
#   2. Runtime --version test of python3 / python – catches real installs even
#      when $pythonLocation is absent (local dev, non-GitHub runners, etc.).
#
# We deliberately do NOT use `command -v` because on Windows the alias stub
# passes `command -v` but fails on actual execution.
PYTHON_CMD=""

if [ -n "${pythonLocation:-}" ]; then
  # Normalize Windows backslashes so bash path tests work inside Git Bash.
  PY_DIR="${pythonLocation//\\//}"
  for candidate in "${PY_DIR}/python3" "${PY_DIR}/python3.exe" \
                   "${PY_DIR}/python"  "${PY_DIR}/python.exe"; do
    if [ -f "$candidate" ]; then
      PYTHON_CMD="$candidate"
      break
    fi
  done
fi

if [ -z "$PYTHON_CMD" ]; then
  for candidate in python3 python; do
    if $candidate --version >/dev/null 2>&1; then
      PYTHON_CMD="$candidate"
      break
    fi
  done
fi

[ -n "$PYTHON_CMD" ] || {
  echo "ERROR: python/python3 no instalado o no accesible."
  exit 1
}

$PYTHON_CMD -m pip install --upgrade pip >/dev/null
$PYTHON_CMD -m pip install pyinstaller >/dev/null

# Install project dependencies so PyInstaller can bundle them.
# Checks the most common requirements file locations; installs all that exist.
for req in requirements.txt requirements/base.txt requirements/prod.txt requirements/main.txt; do
  if [ -f "$req" ]; then
    echo "[+] Installing dependencies from $req"
    $PYTHON_CMD -m pip install -r "$req"
  fi
done

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
