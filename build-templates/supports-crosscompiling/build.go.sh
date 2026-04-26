#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  GO BUILD SCRIPT (cross-compiling: one Linux job builds both targets)
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

command -v go >/dev/null 2>&1 || { echo "ERROR: go no instalado"; exit 1; }

export GOPATH="${GOPATH:-$PWD/.go}"
export GOMODCACHE="${GOMODCACHE:-$GOPATH/pkg/mod}"
export GOCACHE="${GOCACHE:-$PWD/.cache/go-build}"
mkdir -p "$OUTPUT_DIR" "$GOMODCACHE" "$GOCACHE"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ ⚙️   PROJECT CONFIG — FILL IN                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Linker flags. -s -w strips DWARF/symbols; the -X injects APP_VERSION into a
# variable named main.Version. Rename if your version variable lives elsewhere.
LDFLAGS="-s -w -X main.Version=${APP_VERSION}"

# Extra `go build` flags. Add tags, race detector, custom -gcflags here.
# -buildvcs=false avoids "error obtaining VCS status: exit status 128" when
# running inside CI runners with mismatched ownership (the build always runs
# from ./code/ inside the launcher-managed repo, so VCS stamping is fragile).
EXTRA_BUILD_FLAGS=(-trimpath -buildvcs=false)
# Example: EXTRA_BUILD_FLAGS+=(-tags "release netgo")

# CGO is off by default for fully static binaries. Set to 1 if you link against C.
CGO_ENABLED_VALUE="${CGO_ENABLED:-0}"

# Package to build. "." = main package at repo root. Change to "./cmd/foo" for
# multi-binary repos.
BUILD_PACKAGE="."

# Windows .exe icon. The build script auto-detects icon.ico in any of these
# locations (first match wins). Leave the file out and the build proceeds
# without a custom icon. To generate a multi-resolution icon.ico from a PNG:
#   magick icon.png -define icon:auto-resize=16,32,48,256 icon.ico
ICON_LOOKUP_PATHS=(icon.ico assets/icon.ico "${BUILD_PACKAGE}/icon.ico")


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔨  BUILD STEPS — EDIT / ADD / REMOVE FREELY                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ─── Windows .exe icon embedding (auto, no-op if no icon.ico is found) ─────
# Generates a Windows resource file (.syso) that the Go linker picks up
# automatically because of its _windows suffix. Linux builds are unaffected.
ICON_SYSO=""
if [ "$BUILD_WINDOWS" = "1" ]; then
  for candidate in "${ICON_LOOKUP_PATHS[@]}"; do
    if [ -f "$candidate" ]; then ICON_ICO="$candidate"; break; fi
  done
  if [ -n "${ICON_ICO:-}" ]; then
    if ! command -v rsrc >/dev/null 2>&1; then
      echo "[+] Installing rsrc (Windows resource embedder) into .go/bin"
      GOBIN="$PWD/.go/bin" go install github.com/akavel/rsrc@latest
      export PATH="$PWD/.go/bin:$PATH"
    fi
    ICON_SYSO="${BUILD_PACKAGE}/rsrc_windows.syso"
    echo "[+] Embedding $ICON_ICO into Windows .exe via $ICON_SYSO"
    rsrc -ico "$ICON_ICO" -o "$ICON_SYSO"
    # Trap removes the .syso on script exit so it never lands in git.
    trap 'rm -f "'"$ICON_SYSO"'"' EXIT
  fi
fi

# ─── Linux build (delete this block if you don't ship Linux) ───────────────
if [ "$BUILD_LINUX" = "1" ]; then
  CGO_ENABLED="$CGO_ENABLED_VALUE" GOOS=linux GOARCH=amd64 \
    go build "${EXTRA_BUILD_FLAGS[@]}" -ldflags "$LDFLAGS" \
    -o "$OUTPUT_DIR/$APP_NAME" "$BUILD_PACKAGE"
fi

# ─── Windows build (delete this block if you don't ship Windows) ───────────
if [ "$BUILD_WINDOWS" = "1" ]; then
  CGO_ENABLED="$CGO_ENABLED_VALUE" GOOS=windows GOARCH=amd64 \
    go build "${EXTRA_BUILD_FLAGS[@]}" -ldflags "$LDFLAGS" \
    -o "$OUTPUT_DIR/$APP_NAME.exe" "$BUILD_PACKAGE"
fi


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔒  LAUNCHER CONTRACT — DO NOT EDIT                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
[ "$BUILD_LINUX"   = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME"     ] || { echo "ERROR: falta ELF Linux en $OUTPUT_DIR/";  exit 1; }; }
[ "$BUILD_WINDOWS" = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME.exe" ] || { echo "ERROR: falta EXE Windows en $OUTPUT_DIR/"; exit 1; }; }
echo "[+] Artifacts generados en $OUTPUT_DIR/"
