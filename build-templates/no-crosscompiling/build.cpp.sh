#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  C++ BUILD SCRIPT (CMake-based, native per-OS)
#
#  Cross-compiling C/C++ with system dependencies is fragile, so each platform
#  builds on its own native runner. Defaults to CMake; switch to Make/Meson/etc
#  by replacing the BUILD STEPS block.
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

# Build directory CMake will use. Wiped at the start of each build.
BUILD_DIR="build"

# CMake build type. Release / Debug / RelWithDebInfo / MinSizeRel.
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"

# CMake generator. Empty = let CMake pick the platform default.
#   "Ninja"        — fast, install with apt/choco
#   "Unix Makefiles"
#   "Visual Studio 17 2022"  — Windows only, MSVC
CMAKE_GENERATOR="${CMAKE_GENERATOR:-}"

# Extra cmake configure flags. Use -D<var>=<val> for project options.
EXTRA_CMAKE_FLAGS=()
# Example: EXTRA_CMAKE_FLAGS+=(-DUSE_OPENSSL=ON -DBUILD_TESTING=OFF)
# Example: EXTRA_CMAKE_FLAGS+=(-DCMAKE_PREFIX_PATH=/opt/myroot)

# CMake target name. Usually equals APP_NAME, sometimes different in CMakeLists.
CMAKE_TARGET="${CMAKE_TARGET:-$APP_NAME}"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔨  BUILD STEPS — EDIT / ADD / REMOVE FREELY                               ║
# ║                                                                           ║
# ║  Replace this entire block if you use Make/Meson/Bazel/etc.               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

command -v cmake >/dev/null 2>&1 || { echo "ERROR: cmake is not installed"; exit 1; }
[ -f CMakeLists.txt ] || { echo "ERROR: CMakeLists.txt not found in $PWD"; exit 1; }

rm -rf "$BUILD_DIR"
CMAKE_CONFIG_FLAGS=(
  -B "$BUILD_DIR"
  -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE"
  -DAPP_VERSION="$APP_VERSION"
  "${EXTRA_CMAKE_FLAGS[@]}"
)
[ -n "$CMAKE_GENERATOR" ] && CMAKE_CONFIG_FLAGS+=(-G "$CMAKE_GENERATOR")

cmake "${CMAKE_CONFIG_FLAGS[@]}"
cmake --build "$BUILD_DIR" --config "$CMAKE_BUILD_TYPE" --target "$CMAKE_TARGET" --parallel

LINUX_DONE=0
WINDOWS_DONE=0

# Find the produced binary. CMake writes to different paths per generator:
#   Single-config (Make/Ninja):    $BUILD_DIR/<APP_NAME>[.exe]
#   Multi-config (VS/Xcode):       $BUILD_DIR/<config>/<APP_NAME>[.exe]
locate_binary() {
  local name="$1"
  local candidates=(
    "$BUILD_DIR/$name"
    "$BUILD_DIR/$CMAKE_BUILD_TYPE/$name"
    "$BUILD_DIR/bin/$name"
    "$BUILD_DIR/bin/$CMAKE_BUILD_TYPE/$name"
  )
  for c in "${candidates[@]}"; do
    [ -f "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

# ─── Linux build (delete this block if you don't ship Linux) ───────────────
if [ "$BUILD_LINUX" = "1" ] && [ "$OS_NAME" = "Linux" ]; then
  bin="$(locate_binary "$APP_NAME")" || { echo "ERROR: Linux executable not found in $BUILD_DIR/"; exit 1; }
  cp "$bin" "$OUTPUT_DIR/$APP_NAME"
  chmod +x "$OUTPUT_DIR/$APP_NAME"
  LINUX_DONE=1
fi

# ─── Windows build (delete this block if you don't ship Windows) ───────────
if [ "$BUILD_WINDOWS" = "1" ]; then
  case "$OS_NAME" in MINGW*|MSYS*|CYGWIN*)
    bin="$(locate_binary "${APP_NAME}.exe")" || { echo "ERROR: Windows EXE not found in $BUILD_DIR/"; exit 1; }
    cp "$bin" "$OUTPUT_DIR/$APP_NAME.exe"
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
  echo "ERROR: BUILD_WINDOWS=1 but this job is not running on Windows. C++ does not cross-compile by default."; exit 1
fi
echo "[+] Artifacts written to $OUTPUT_DIR/"
