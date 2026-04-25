#!/usr/bin/env bash
set -euo pipefail

APP_VERSION="${APP_VERSION:-dev-local}"
APP_NAME="${APP_NAME:-$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')}"
OUTPUT_DIR="dist"

# ===== PLATFORM TOGGLES (DELETE WHAT YOU DON'T NEED) =====
BUILD_LINUX="${BUILD_LINUX:-1}"
BUILD_WINDOWS="${BUILD_WINDOWS:-1}"
# ==========================================================

command -v php >/dev/null 2>&1 || { echo "ERROR: php no instalado"; exit 1; }
command -v composer >/dev/null 2>&1 || { echo "ERROR: composer no instalado"; exit 1; }

mkdir -p "$OUTPUT_DIR"
composer install --no-interaction --no-progress --prefer-dist

# Ejemplo real recomendado: generar PHAR.
# Ajusta este bloque a tu empaquetador (box/phive/phar-composer/etc.)
if [ -f "build/${APP_NAME}.phar" ]; then
  cp "build/${APP_NAME}.phar" "$OUTPUT_DIR/${APP_NAME}.phar"
fi

[ -f "$OUTPUT_DIR/${APP_NAME}.phar" ] || {
  echo "ERROR: falta artefacto PHP (esperado: dist/${APP_NAME}.phar)."
  echo "Define el paso real de empaquetado antes de usar esta plantilla."
  exit 1
}

# PHAR es portable; se generan wrappers por plataforma.
# ===== LINUX BUILD START (delete this block if linux is not needed) =====
if [ "$BUILD_LINUX" = "1" ]; then
  cat > "$OUTPUT_DIR/$APP_NAME" <<EOF
#!/usr/bin/env bash
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
exec php "\$SCRIPT_DIR/${APP_NAME}.phar" "\$@"
EOF
  chmod +x "$OUTPUT_DIR/$APP_NAME"
fi
# ===== LINUX BUILD END =====

# ===== WINDOWS BUILD START (delete this block if windows is not needed) =====
if [ "$BUILD_WINDOWS" = "1" ]; then
  cat > "$OUTPUT_DIR/$APP_NAME.bat" <<EOF
@echo off
set SCRIPT_DIR=%~dp0
php "%SCRIPT_DIR%${APP_NAME}.phar" %*
EOF
fi
# ===== WINDOWS BUILD END =====

echo "[+] Artifacts generados en ${OUTPUT_DIR}/"
