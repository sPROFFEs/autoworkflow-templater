#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  RUBY BUILD SCRIPT (Gem package + per-OS launcher wrappers)
#
#  Ruby gems are portable. We build the .gem and add launcher scripts so each
#  platform ships a binary with the right extension. Users still need Ruby
#  installed to run the wrappers — for true static binaries see traveling-ruby.
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

command -v ruby >/dev/null 2>&1 || { echo "ERROR: ruby is not installed"; exit 1; }
command -v gem  >/dev/null 2>&1 || { echo "ERROR: gem is not installed";  exit 1; }
mkdir -p "$OUTPUT_DIR"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ ⚙️   PROJECT CONFIG — FILL IN                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Path to the .gemspec file. Defaults to <APP_NAME>.gemspec.
GEMSPEC="${GEMSPEC:-${APP_NAME}.gemspec}"

# Bundler install before build? Recommended if you have a Gemfile.
RUN_BUNDLE="${RUN_BUNDLE:-auto}"   # auto | yes | no


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔨  BUILD STEPS — EDIT / ADD / REMOVE FREELY                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

if { [ "$RUN_BUNDLE" = "yes" ] || { [ "$RUN_BUNDLE" = "auto" ] && [ -f Gemfile ]; }; }; then
  command -v bundle >/dev/null 2>&1 || gem install --no-document bundler
  bundle install --jobs 4
fi

[ -f "$GEMSPEC" ] || { echo "ERROR: gemspec not found at $GEMSPEC"; exit 1; }
APP_VERSION="$APP_VERSION" gem build "$GEMSPEC"

GEM_PATH="$(find . -maxdepth 1 -type f -name '*.gem' | head -n 1 || true)"
[ -n "$GEM_PATH" ] || { echo "ERROR: gem build produced no .gem file"; exit 1; }
cp "$GEM_PATH" "$OUTPUT_DIR/"

# ─── Linux launcher (delete if you don't ship Linux) ───────────────────────
if [ "$BUILD_LINUX" = "1" ]; then
  cat > "$OUTPUT_DIR/$APP_NAME" <<EOF
#!/usr/bin/env bash
exec ruby -S $APP_NAME "\$@"
EOF
  chmod +x "$OUTPUT_DIR/$APP_NAME"
fi

# ─── Windows launcher (delete if you don't ship Windows) ───────────────────
if [ "$BUILD_WINDOWS" = "1" ]; then
  cat > "$OUTPUT_DIR/$APP_NAME.bat" <<EOF
@echo off
ruby -S $APP_NAME %*
EOF
fi


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔒  LAUNCHER CONTRACT — DO NOT EDIT                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
[ "$BUILD_LINUX"   = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME"     ] || { echo "ERROR: Linux launcher missing in $OUTPUT_DIR/";   exit 1; }; }
[ "$BUILD_WINDOWS" = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME.bat" ] || { echo "ERROR: Windows launcher missing in $OUTPUT_DIR/"; exit 1; }; }
echo "[+] Artifacts written to $OUTPUT_DIR/"
