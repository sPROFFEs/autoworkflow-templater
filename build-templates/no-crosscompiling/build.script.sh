#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  SCRIPT / NO-COMPILE BUILD SCRIPT
#
#  For projects that don't need compilation: shell scripts, Docker Compose
#  stacks, Ansible playbooks, config bundles, etc.
#
#  Three zones below:
#    🔒 LAUNCHER CONTRACT   — do not edit, the CI workflow depends on this
#    ⚙️  PROJECT CONFIG      — fill in for your project
#    🔨 BUILD STEPS         — edit / add / remove freely
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔒  LAUNCHER CONTRACT — DO NOT EDIT                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
APP_VERSION="${APP_VERSION:-dev-local}"
APP_NAME="${APP_NAME:-my-project}"
OUTPUT_DIR="dist"
BUILD_LINUX="${BUILD_LINUX:-1}"
BUILD_WINDOWS="${BUILD_WINDOWS:-0}"

mkdir -p "$OUTPUT_DIR"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ ⚙️   PROJECT CONFIG — FILL IN                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# RELEASE_MODE controls what gets packaged into the release:
#   "archive" — zip the entire code/ folder (current directory when script runs)
#   "files"   — copy only the paths listed in RELEASE_FILES
RELEASE_MODE="${RELEASE_MODE:-archive}"

# RELEASE_FILES: space-separated list of files or directories to include in the
# release. Paths are relative to the code/ directory. Used only when
# RELEASE_MODE=files.
# Example: RELEASE_FILES="README.md config/ scripts/deploy.sh"
RELEASE_FILES="${RELEASE_FILES:-}"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔨  BUILD STEPS — EDIT / ADD / REMOVE FREELY                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

if [ "$RELEASE_MODE" = "archive" ]; then
  # Archive the entire code/ directory (current dir after launcher cd's into it).
  ARCHIVE="${APP_NAME}-${APP_VERSION}.zip"
  echo "[+] Archiving current directory → $OUTPUT_DIR/$ARCHIVE"
  if command -v zip >/dev/null 2>&1; then
    zip -r "$OUTPUT_DIR/$ARCHIVE" . \
      --exclude '.git/*' \
      --exclude '*.syso' \
      --exclude '.go/*' \
      --exclude '.cache/*'
  else
    # zip is not installed — fall back to tar.gz (always available on Linux runners).
    ARCHIVE="${APP_NAME}-${APP_VERSION}.tar.gz"
    echo "[!] zip not found, falling back to tar.gz: $OUTPUT_DIR/$ARCHIVE"
    tar -czf "$OUTPUT_DIR/$ARCHIVE" \
      --exclude='.git' \
      --exclude='.go' \
      --exclude='.cache' \
      .
  fi

elif [ "$RELEASE_MODE" = "files" ]; then
  if [ -z "$RELEASE_FILES" ]; then
    echo "ERROR: RELEASE_MODE=files but RELEASE_FILES is empty."
    echo "Set RELEASE_FILES to the space-separated list of files/dirs to include."
    exit 1
  fi
  echo "[+] Copying release files to $OUTPUT_DIR/"
  for item in $RELEASE_FILES; do
    if [ -e "$item" ]; then
      cp -r "$item" "$OUTPUT_DIR/"
      echo "    ✓ $item"
    else
      echo "    [!] '$item' not found, skipping"
    fi
  done

else
  echo "ERROR: RELEASE_MODE must be 'archive' or 'files', got: '$RELEASE_MODE'"
  exit 1
fi


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔒  LAUNCHER CONTRACT — DO NOT EDIT                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
test -n "$(find "$OUTPUT_DIR" -type f -print -quit)" || {
  echo "ERROR: no artifacts found in $OUTPUT_DIR/ — nothing to release."
  exit 1
}
echo "[+] Artifacts generados en $OUTPUT_DIR/"
