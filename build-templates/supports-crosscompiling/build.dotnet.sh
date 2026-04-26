#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  .NET BUILD SCRIPT (cross-compiling via dotnet publish runtime identifiers)
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

command -v dotnet >/dev/null 2>&1 || { echo "ERROR: dotnet is not installed"; exit 1; }
export DOTNET_CLI_TELEMETRY_OPTOUT=1
mkdir -p "$OUTPUT_DIR"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ ⚙️   PROJECT CONFIG — FILL IN                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Path to the .csproj or .sln to publish. Empty = let dotnet auto-discover.
PROJECT_PATH=""

# self-contained: bundles the .NET runtime (~70MB but no install required).
# Set to false for framework-dependent builds (smaller, but user needs runtime).
SELF_CONTAINED="true"

# Extra MSBuild properties.
EXTRA_DOTNET_FLAGS=()
# Example single-file: EXTRA_DOTNET_FLAGS+=(-p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true)
# Example trimming:    EXTRA_DOTNET_FLAGS+=(-p:PublishTrimmed=true)
# Example AOT:         EXTRA_DOTNET_FLAGS+=(-p:PublishAot=true)


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔨  BUILD STEPS — EDIT / ADD / REMOVE FREELY                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

dotnet restore $PROJECT_PATH

# ─── Linux build (delete this block if you don't ship Linux) ───────────────
if [ "$BUILD_LINUX" = "1" ]; then
  dotnet publish $PROJECT_PATH \
    -c Release -r linux-x64 \
    --self-contained "$SELF_CONTAINED" \
    -p:Version="$APP_VERSION" \
    "${EXTRA_DOTNET_FLAGS[@]}" \
    -o "$OUTPUT_DIR/linux"
  cp "$OUTPUT_DIR/linux/$APP_NAME" "$OUTPUT_DIR/$APP_NAME"
fi

# ─── Windows build (delete this block if you don't ship Windows) ───────────
if [ "$BUILD_WINDOWS" = "1" ]; then
  dotnet publish $PROJECT_PATH \
    -c Release -r win-x64 \
    --self-contained "$SELF_CONTAINED" \
    -p:Version="$APP_VERSION" \
    "${EXTRA_DOTNET_FLAGS[@]}" \
    -o "$OUTPUT_DIR/win"
  cp "$OUTPUT_DIR/win/$APP_NAME.exe" "$OUTPUT_DIR/$APP_NAME.exe"
fi


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔒  LAUNCHER CONTRACT — DO NOT EDIT                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
[ "$BUILD_LINUX"   = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME"     ] || { echo "ERROR: Linux binary missing in $OUTPUT_DIR/"; exit 1; }; }
[ "$BUILD_WINDOWS" = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME.exe" ] || { echo "ERROR: Windows EXE missing in $OUTPUT_DIR/"; exit 1; }; }
echo "[+] Artifacts written to $OUTPUT_DIR/"
