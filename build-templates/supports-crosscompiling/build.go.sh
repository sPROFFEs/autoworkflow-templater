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

command -v go >/dev/null 2>&1 || { echo "ERROR: go is not installed"; exit 1; }

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

# Windows .exe icon. Place icon.png at the repo root (or assets/icon.png) and
# it will be embedded automatically via go-winres — no extra step needed.


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔨  BUILD STEPS — EDIT / ADD / REMOVE FREELY                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ─── Windows .exe icon embedding (auto, no-op if no icon.png found) ─────────
# go-winres reads the PNG directly and generates rsrc_windows_amd64.syso inside
# the package directory. The Go linker picks it up automatically.
# Using go-winres (instead of rsrc) avoids the i386/x86-64 COFF mismatch that
# rsrc triggers with MinGW 15+ when cross-compiling from Linux.
ICON_EMBEDDED=0
if [ "$BUILD_WINDOWS" = "1" ]; then
  # Purge stale syso files — a leftover from a crashed prior run causes
  # "duplicate leaf" link errors with newer MinGW (15.x+).
  find "$BUILD_PACKAGE" -maxdepth 1 -name "*.syso" -delete 2>/dev/null || true

  PNG_SOURCE=""
  for png in icon.png assets/icon.png; do
    if [ -f "$png" ]; then PNG_SOURCE="$png"; break; fi
  done

  if [ -n "$PNG_SOURCE" ]; then
    if ! command -v go-winres >/dev/null 2>&1; then
      echo "[+] Installing go-winres (pure-Go PNG → .syso embedder)"
      GOBIN="$PWD/.go/bin" go install github.com/tc-hib/go-winres@latest
      export PATH="$PWD/.go/bin:$PATH"
    fi

    if command -v go-winres >/dev/null 2>&1; then
      # Must run inside the package dir so the syso lands next to the Go sources.
      ICON_ABS="$(pwd)/$PNG_SOURCE"
      PKG_DIR="$(pwd)/$BUILD_PACKAGE"
      ( cd "$PKG_DIR" && go-winres simply --arch amd64 --icon "$ICON_ABS" )
      WINRES_SYSO="$PKG_DIR/rsrc_windows_amd64.syso"
      trap 'rm -f "'"$WINRES_SYSO"'"' EXIT
      echo "[+] Icon embedded via go-winres → $WINRES_SYSO"
      ICON_EMBEDDED=1
    else
      echo "[!] go-winres install failed, building without embedded icon"
    fi
  else
    echo "[!] No icon source found (icon.png), building without embedded icon"
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
[ "$BUILD_LINUX"   = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME"     ] || { echo "ERROR: Linux ELF binary missing in $OUTPUT_DIR/";  exit 1; }; }
[ "$BUILD_WINDOWS" = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME.exe" ] || { echo "ERROR: Windows EXE missing in $OUTPUT_DIR/"; exit 1; }; }
echo "[+] Artifacts written to $OUTPUT_DIR/"
