#!/usr/bin/env bash
set -euo pipefail

APP_VERSION="${APP_VERSION:-dev-local}"
APP_NAME="my_tool"
OUTPUT_DIR="dist"

# ===== PLATFORM TOGGLES (DELETE WHAT YOU DON'T NEED) =====
BUILD_LINUX="${BUILD_LINUX:-1}"
BUILD_WINDOWS="${BUILD_WINDOWS:-1}"
# ==========================================================

command -v ruby >/dev/null 2>&1 || { echo "ERROR: ruby no instalado"; exit 1; }
command -v gem >/dev/null 2>&1 || { echo "ERROR: gem no instalado"; exit 1; }

mkdir -p "$OUTPUT_DIR"
APP_VERSION="$APP_VERSION" gem build "$APP_NAME".gemspec

GEM_PATH="$(find . -maxdepth 1 -type f -name '*.gem' | head -n 1 || true)"
[ -n "$GEM_PATH" ] || { echo "ERROR: falta paquete .gem"; exit 1; }
cp "$GEM_PATH" "$OUTPUT_DIR/"

# Ruby gem es portable; se generan wrappers por plataforma para CLI.
# ===== LINUX BUILD START (delete this block if linux is not needed) =====
if [ "$BUILD_LINUX" = "1" ]; then
  cat > "$OUTPUT_DIR/$APP_NAME" <<EOF
#!/usr/bin/env bash
exec ruby -S $APP_NAME "\$@"
EOF
  chmod +x "$OUTPUT_DIR/$APP_NAME"
fi
# ===== LINUX BUILD END =====

# ===== WINDOWS BUILD START (delete this block if windows is not needed) =====
if [ "$BUILD_WINDOWS" = "1" ]; then
  cat > "$OUTPUT_DIR/$APP_NAME.bat" <<EOF
@echo off
ruby -S $APP_NAME %*
EOF
fi
# ===== WINDOWS BUILD END =====

echo "[+] Artifacts generados en ${OUTPUT_DIR}/"
