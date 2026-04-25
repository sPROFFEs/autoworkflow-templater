#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  PHP BUILD SCRIPT (PHAR archive + per-OS launcher wrappers)
#
#  PHP ships a portable PHAR. We add launcher scripts so each platform has
#  a binary with the right extension. Users still need PHP installed.
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

command -v php      >/dev/null 2>&1 || { echo "ERROR: php no instalado";      exit 1; }
command -v composer >/dev/null 2>&1 || { echo "ERROR: composer no instalado"; exit 1; }
mkdir -p "$OUTPUT_DIR"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ ⚙️   PROJECT CONFIG — FILL IN                                              ║
# ║                                                                           ║
# ║  PHP packaging tooling varies a lot. Pick ONE PHAR builder for your       ║
# ║  project and replace the BUILD_PHAR_CMD below to match it.                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# How to produce build/<APP_NAME>.phar. Replace with your tooling:
#   - box-project/box:    composer require --dev humbug/box && vendor/bin/box compile
#   - phar-composer:      vendor/bin/phar-composer build . build/${APP_NAME}.phar
#   - custom Makefile:    make phar
BUILD_PHAR_CMD=(echo "TODO: configura BUILD_PHAR_CMD en build.sh" "&&" "false")


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔨  BUILD STEPS — EDIT / ADD / REMOVE FREELY                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

composer install --no-interaction --no-progress --prefer-dist

# Run the user-defined PHAR builder.
"${BUILD_PHAR_CMD[@]}"

[ -f "build/${APP_NAME}.phar" ] || {
  echo "ERROR: el builder no produjo build/${APP_NAME}.phar"
  exit 1
}
cp "build/${APP_NAME}.phar" "$OUTPUT_DIR/${APP_NAME}.phar"

# ─── Linux launcher (delete if you don't ship Linux) ───────────────────────
if [ "$BUILD_LINUX" = "1" ]; then
  cat > "$OUTPUT_DIR/$APP_NAME" <<EOF
#!/usr/bin/env bash
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
exec php "\$SCRIPT_DIR/${APP_NAME}.phar" "\$@"
EOF
  chmod +x "$OUTPUT_DIR/$APP_NAME"
fi

# ─── Windows launcher (delete if you don't ship Windows) ───────────────────
if [ "$BUILD_WINDOWS" = "1" ]; then
  cat > "$OUTPUT_DIR/$APP_NAME.bat" <<EOF
@echo off
set SCRIPT_DIR=%~dp0
php "%SCRIPT_DIR%${APP_NAME}.phar" %*
EOF
fi


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔒  LAUNCHER CONTRACT — DO NOT EDIT                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
[ -f "$OUTPUT_DIR/${APP_NAME}.phar" ] || { echo "ERROR: falta PHAR en $OUTPUT_DIR/"; exit 1; }
[ "$BUILD_LINUX"   = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME"     ] || { echo "ERROR: falta launcher Linux";   exit 1; }; }
[ "$BUILD_WINDOWS" = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME.bat" ] || { echo "ERROR: falta launcher Windows"; exit 1; }; }
echo "[+] Artifacts generados en $OUTPUT_DIR/"
