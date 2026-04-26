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

# Windows .exe icon. Auto-detects icon.ico in any of these locations (first
# match wins). If only icon.png is present it is converted automatically using
# ImageMagick (magick/convert) or go-winres — no manual step required.
ICON_LOOKUP_PATHS=(icon.ico assets/icon.ico "${BUILD_PACKAGE}/icon.ico")


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔨  BUILD STEPS — EDIT / ADD / REMOVE FREELY                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ─── Windows .exe icon embedding (auto, no-op if no icon source found) ──────
# Generates a Windows resource file (.syso) that the Go linker picks up
# automatically because of its _windows suffix. Linux builds are unaffected.
ICON_EMBEDDED=0
if [ "$BUILD_WINDOWS" = "1" ]; then
  # 1. Prefer a pre-existing .ico.
  ICON_ICO=""
  for candidate in "${ICON_LOOKUP_PATHS[@]}"; do
    if [ -f "$candidate" ]; then ICON_ICO="$candidate"; break; fi
  done

  # 2. If only .png exists, convert it automatically.
  if [ -z "$ICON_ICO" ]; then
    PNG_SOURCE=""
    for png in icon.png assets/icon.png; do
      if [ -f "$png" ]; then PNG_SOURCE="$png"; break; fi
    done

    if [ -n "$PNG_SOURCE" ]; then
      if command -v magick >/dev/null 2>&1; then
        echo "[+] Converting $PNG_SOURCE → icon.ico via ImageMagick (magick)"
        magick "$PNG_SOURCE" -define icon:auto-resize=16,32,48,256 icon.ico
        ICON_ICO="icon.ico"
      elif command -v convert >/dev/null 2>&1 && [[ "$(uname -s)" != MINGW* ]] && [[ "$(uname -s)" != MSYS* ]] && [[ "$(uname -s)" != CYGWIN* ]]; then
        # `convert` on Windows is the system disk utility, not ImageMagick — skip it.
        echo "[+] Converting $PNG_SOURCE → icon.ico via ImageMagick (convert)"
        convert "$PNG_SOURCE" -define icon:auto-resize=16,32,48,256 icon.ico
        ICON_ICO="icon.ico"
      else
        # go-winres: pure-Go, reads PNG directly, writes the .syso itself.
        echo "[+] ImageMagick not found, trying go-winres (pure-Go PNG → .syso)"
        if ! command -v go-winres >/dev/null 2>&1; then
          GOBIN="$PWD/.go/bin" go install github.com/tc-hib/go-winres@latest
          export PATH="$PWD/.go/bin:$PATH"
        fi
        if command -v go-winres >/dev/null 2>&1; then
          WINRES_SYSO="${BUILD_PACKAGE}/rsrc_windows_amd64.syso"
          go-winres simply --icon "$PNG_SOURCE" --out "$WINRES_SYSO"
          trap 'rm -f "'"$WINRES_SYSO"'"' EXIT
          echo "[+] Icon embedded via go-winres → $WINRES_SYSO"
          ICON_EMBEDDED=1
        else
          echo "[!] go-winres install failed, building without embedded icon"
        fi
      fi
    fi
  fi

  # 3. Embed via rsrc if we have an .ico (and go-winres didn't already write the syso).
  if [ -n "$ICON_ICO" ] && [ "$ICON_EMBEDDED" = "0" ]; then
    if ! command -v rsrc >/dev/null 2>&1; then
      echo "[+] Installing rsrc (Windows resource embedder) into .go/bin"
      GOBIN="$PWD/.go/bin" go install github.com/akavel/rsrc@latest
      export PATH="$PWD/.go/bin:$PATH"
    fi
    RSRC_SYSO="${BUILD_PACKAGE}/rsrc_windows.syso"
    echo "[+] Embedding $ICON_ICO into Windows .exe via $RSRC_SYSO"
    rsrc -ico "$ICON_ICO" -o "$RSRC_SYSO"
    trap 'rm -f "'"$RSRC_SYSO"'"' EXIT
    ICON_EMBEDDED=1
  fi

  [ "$ICON_EMBEDDED" = "0" ] && echo "[!] No icon source found, building without embedded icon"
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
