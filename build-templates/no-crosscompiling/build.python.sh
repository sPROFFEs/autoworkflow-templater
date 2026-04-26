#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  PYTHON BUILD SCRIPT (PyInstaller, no cross-compiling)
#  Each platform must build on its native runner. The workflow handles that.
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
# ║                                                                           ║
# ║  These variables are injected by the workflow / launcher. Renaming them   ║
# ║  or removing the asserts at the bottom WILL break the release pipeline.   ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
APP_VERSION="${APP_VERSION:-dev-local}"          # tag-driven, set by workflow
APP_NAME="${APP_NAME:-$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')}"
OUTPUT_DIR="dist"                                # release job reads from here
BUILD_LINUX="${BUILD_LINUX:-1}"                  # 0|1, set by plan job
BUILD_WINDOWS="${BUILD_WINDOWS:-1}"              # 0|1, set by plan job
OS_NAME="$(uname -s || echo unknown)"

# Resolve a real Python interpreter (avoids the Windows App Execution Alias
# stub that intercepts python/python3 on PATH). Prefers $pythonLocation set
# by actions/setup-python, falls back to a runtime --version test.
PYTHON_CMD=""
if [ -n "${pythonLocation:-}" ]; then
  PY_DIR="${pythonLocation//\\//}"
  for c in "$PY_DIR/python3" "$PY_DIR/python3.exe" "$PY_DIR/python" "$PY_DIR/python.exe"; do
    [ -f "$c" ] && PYTHON_CMD="$c" && break
  done
fi
if [ -z "$PYTHON_CMD" ]; then
  for c in python3 python; do
    if $c --version >/dev/null 2>&1; then PYTHON_CMD="$c"; break; fi
  done
fi
[ -n "$PYTHON_CMD" ] || { echo "ERROR: python/python3 is not installed or not accessible."; exit 1; }
# ╚═══════════════════════════════════════════════════════════════════════════╝


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ ⚙️   PROJECT CONFIG — FILL IN                                              ║
# ║                                                                           ║
# ║  Tweak these to match your project. Defaults try common conventions.      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Entry point (auto-detected from common filenames if left empty).
ENTRY_POINT="${ENTRY_POINT:-}"
if [ -z "$ENTRY_POINT" ]; then
  for candidate in main.py app.py src/main.py src/app.py __main__.py; do
    [ -f "$candidate" ] && ENTRY_POINT="$candidate" && break
  done
  [ -n "$ENTRY_POINT" ] || {
    echo "ERROR: could not detect the Python entry point."
    echo "Set ENTRY_POINT=<file>.py or create main.py."
    exit 1
  }
fi

# Extra PyInstaller flags. Common needs:
#   --hidden-import=<module>     for imports PyInstaller can't see statically
#   --add-data "src;dst"         to bundle non-code files (use ; on Windows, : on Linux)
#   --collect-all=<package>      for packages with data files (numpy, scipy, etc.)
#   --icon=icon.ico              custom icon (Windows/Mac)
EXTRA_PYINSTALLER_FLAGS=()
# Example: EXTRA_PYINSTALLER_FLAGS+=("--hidden-import=pkg_resources.py2_warn")
# ╚═══════════════════════════════════════════════════════════════════════════╝


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔨  BUILD STEPS — EDIT / ADD / REMOVE FREELY                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

mkdir -p "$OUTPUT_DIR"

# Inject __version__ for the build (cleaned up on exit).
TMP_VERSION_FILE="version.py"
echo "__version__ = '$APP_VERSION'" > "$TMP_VERSION_FILE"
trap 'rm -f "$TMP_VERSION_FILE"' EXIT

# Install PyInstaller and project dependencies.
$PYTHON_CMD -m pip install --upgrade pip >/dev/null
$PYTHON_CMD -m pip install pyinstaller >/dev/null
for req in requirements.txt requirements/base.txt requirements/prod.txt requirements/main.txt; do
  if [ -f "$req" ]; then
    echo "[+] Installing dependencies from $req"
    $PYTHON_CMD -m pip install -r "$req"
  fi
done

LINUX_DONE=0
WINDOWS_DONE=0

# ─── Linux build (delete this block if you don't ship Linux) ───────────────
if [ "$BUILD_LINUX" = "1" ] && [ "$OS_NAME" = "Linux" ]; then
  $PYTHON_CMD -m PyInstaller --onefile \
    --name "$APP_NAME" \
    --distpath "$OUTPUT_DIR" \
    "${EXTRA_PYINSTALLER_FLAGS[@]}" \
    "$ENTRY_POINT"
  LINUX_DONE=1
fi

# ─── Windows build (delete this block if you don't ship Windows) ───────────
if [ "$BUILD_WINDOWS" = "1" ]; then
  case "$OS_NAME" in MINGW*|MSYS*|CYGWIN*)
    $PYTHON_CMD -m PyInstaller --onefile \
      --name "$APP_NAME" \
      --distpath "$OUTPUT_DIR" \
      "${EXTRA_PYINSTALLER_FLAGS[@]}" \
      "$ENTRY_POINT"
    WINDOWS_DONE=1
    ;;
  esac
fi


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔒  LAUNCHER CONTRACT — DO NOT EDIT                                       ║
# ║                                                                           ║
# ║  Final asserts. The release job fails if these aren't met.                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
if [ "$BUILD_LINUX" = "1" ] && [ "$LINUX_DONE" = "1" ]; then
  [ -f "$OUTPUT_DIR/$APP_NAME" ] || { echo "ERROR: Linux binary missing in $OUTPUT_DIR/"; exit 1; }
fi
if [ "$BUILD_WINDOWS" = "1" ] && [ "$WINDOWS_DONE" = "1" ]; then
  [ -f "$OUTPUT_DIR/$APP_NAME.exe" ] || { echo "ERROR: Windows EXE missing in $OUTPUT_DIR/"; exit 1; }
fi
if [ "$BUILD_LINUX" = "1" ] && [ "$LINUX_DONE" -ne 1 ]; then
  echo "ERROR: BUILD_LINUX=1 but this job is not running on Linux. Use a Linux runner or set BUILD_LINUX=0."
  exit 1
fi
if [ "$BUILD_WINDOWS" = "1" ] && [ "$WINDOWS_DONE" -ne 1 ]; then
  echo "ERROR: BUILD_WINDOWS=1 but this job is not running on Windows. PyInstaller does not cross-compile."
  exit 1
fi
echo "[+] Artifacts written to $OUTPUT_DIR/"
