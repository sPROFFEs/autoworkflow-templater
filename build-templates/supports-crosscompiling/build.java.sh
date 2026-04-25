#!/usr/bin/env bash
set -euo pipefail

APP_VERSION="${APP_VERSION:-dev-local}"
APP_NAME="${APP_NAME:-$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')}"
OUTPUT_DIR="dist"

# ===== PLATFORM TOGGLES (DELETE WHAT YOU DON'T NEED) =====
BUILD_LINUX="${BUILD_LINUX:-1}"
BUILD_WINDOWS="${BUILD_WINDOWS:-1}"
# ==========================================================

command -v java >/dev/null 2>&1 || { echo "ERROR: java no instalado"; exit 1; }
command -v mvn >/dev/null 2>&1 || { echo "ERROR: maven no instalado"; exit 1; }

mkdir -p "$OUTPUT_DIR"
mvn -B -Drevision="$APP_VERSION" package

JAR_PATH="$(find target -maxdepth 1 -type f -name '*.jar' | head -n 1 || true)"
[ -n "$JAR_PATH" ] || { echo "ERROR: falta JAR en target/"; exit 1; }
cp "$JAR_PATH" "$OUTPUT_DIR/$APP_NAME.jar"

# Java produce un artefacto portable. Se generan launchers por plataforma.
# ===== LINUX BUILD START (delete this block if linux is not needed) =====
if [ "$BUILD_LINUX" = "1" ]; then
  cat > "$OUTPUT_DIR/$APP_NAME" <<EOF
#!/usr/bin/env bash
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
exec java -jar "\$SCRIPT_DIR/$APP_NAME.jar" "\$@"
EOF
  chmod +x "$OUTPUT_DIR/$APP_NAME"
  [ -f "$OUTPUT_DIR/$APP_NAME" ] || { echo "ERROR: falta launcher Linux"; exit 1; }
fi
# ===== LINUX BUILD END =====

# ===== WINDOWS BUILD START (delete this block if windows is not needed) =====
if [ "$BUILD_WINDOWS" = "1" ]; then
  cat > "$OUTPUT_DIR/$APP_NAME.bat" <<EOF
@echo off
set SCRIPT_DIR=%~dp0
java -jar "%SCRIPT_DIR%$APP_NAME.jar" %*
EOF
  [ -f "$OUTPUT_DIR/$APP_NAME.bat" ] || { echo "ERROR: falta launcher Windows"; exit 1; }
fi
# ===== WINDOWS BUILD END =====

echo "[+] Artifacts generados en ${OUTPUT_DIR}/"
