#!/usr/bin/env bash
set -euo pipefail

# Default build.sh shipped with the template.
# It is overwritten by the launcher when bootstrapping a project. If you
# bootstrap manually, copy a template from build-templates/ and adapt it.

APP_VERSION="${APP_VERSION:-dev-local}"
APP_NAME="${APP_NAME:-$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')}"
OUTPUT_DIR="dist"

# ===== PLATFORM TOGGLES (DELETE WHAT YOU DON'T NEED) =====
BUILD_LINUX="${BUILD_LINUX:-1}"
BUILD_WINDOWS="${BUILD_WINDOWS:-1}"
# ==========================================================

command -v go >/dev/null 2>&1 || { echo "ERROR: go no instalado"; exit 1; }

export GOPATH="${GOPATH:-$PWD/.go}"
export GOMODCACHE="${GOMODCACHE:-$GOPATH/pkg/mod}"
export GOCACHE="${GOCACHE:-$PWD/.cache/go-build}"
mkdir -p "$OUTPUT_DIR" "$GOMODCACHE" "$GOCACHE"

# ===== LINUX BUILD START (delete this block if linux is not needed) =====
if [ "$BUILD_LINUX" = "1" ]; then
  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags "-s -w -X main.Version=${APP_VERSION}" \
    -o "$OUTPUT_DIR/$APP_NAME"
  [ -f "$OUTPUT_DIR/$APP_NAME" ] || { echo "ERROR: falta ELF Linux"; exit 1; }
fi
# ===== LINUX BUILD END =====

# ===== WINDOWS BUILD START (delete this block if windows is not needed) =====
if [ "$BUILD_WINDOWS" = "1" ]; then
  CGO_ENABLED=0 GOOS=windows GOARCH=amd64 \
    go build -trimpath -ldflags "-s -w -X main.Version=${APP_VERSION}" \
    -o "$OUTPUT_DIR/$APP_NAME.exe"
  [ -f "$OUTPUT_DIR/$APP_NAME.exe" ] || { echo "ERROR: falta EXE Windows"; exit 1; }
fi
# ===== WINDOWS BUILD END =====

echo "[+] Artifacts generados en ${OUTPUT_DIR}/"
