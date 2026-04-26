#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  JAVA BUILD SCRIPT (Maven → portable JAR + per-OS launcher wrappers)
#
#  Java produces a portable JAR; we add small launcher scripts (.sh / .bat) so
#  each platform has a binary with the right extension for the release page.
#  If you need a true single binary, switch this to GraalVM native-image.
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

command -v java >/dev/null 2>&1 || { echo "ERROR: java is not installed"; exit 1; }
mkdir -p "$OUTPUT_DIR"


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ ⚙️   PROJECT CONFIG — FILL IN                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Build tool: "maven" (uses pom.xml) or "gradle" (uses build.gradle[.kts]).
BUILD_TOOL="maven"

# Maven goals. "package" produces a JAR. Use "package shade:shade" or similar
# if you need a fat/uber JAR. Override via MAVEN_GOALS=... if needed.
MAVEN_GOALS=(-B "-Drevision=$APP_VERSION" package)

# Gradle tasks. "clean shadowJar" if you use the Shadow plugin for fat JARs.
GRADLE_TASKS=(clean build "-Pversion=$APP_VERSION")


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔨  BUILD STEPS — EDIT / ADD / REMOVE FREELY                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

case "$BUILD_TOOL" in
  maven)
    command -v mvn >/dev/null 2>&1 || { echo "ERROR: maven is not installed"; exit 1; }
    mvn "${MAVEN_GOALS[@]}"
    JAR_PATH="$(find target -maxdepth 1 -type f -name '*.jar' ! -name '*-sources.jar' ! -name '*-javadoc.jar' | head -n 1 || true)"
    ;;
  gradle)
    if [ -x ./gradlew ]; then GRADLE_BIN="./gradlew"; else GRADLE_BIN="gradle"; fi
    command -v "$GRADLE_BIN" >/dev/null 2>&1 || [ -x "$GRADLE_BIN" ] || { echo "ERROR: gradle is not installed"; exit 1; }
    "$GRADLE_BIN" "${GRADLE_TASKS[@]}"
    JAR_PATH="$(find build/libs -maxdepth 1 -type f -name '*.jar' ! -name '*-sources.jar' ! -name '*-javadoc.jar' | head -n 1 || true)"
    ;;
  *) echo "ERROR: unknown BUILD_TOOL: $BUILD_TOOL"; exit 1 ;;
esac

[ -n "$JAR_PATH" ] || { echo "ERROR: no JAR file found after build."; exit 1; }
cp "$JAR_PATH" "$OUTPUT_DIR/$APP_NAME.jar"

# ─── Linux launcher (delete if you don't ship Linux) ───────────────────────
if [ "$BUILD_LINUX" = "1" ]; then
  cat > "$OUTPUT_DIR/$APP_NAME" <<EOF
#!/usr/bin/env bash
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
exec java -jar "\$SCRIPT_DIR/$APP_NAME.jar" "\$@"
EOF
  chmod +x "$OUTPUT_DIR/$APP_NAME"
fi

# ─── Windows launcher (delete if you don't ship Windows) ───────────────────
if [ "$BUILD_WINDOWS" = "1" ]; then
  cat > "$OUTPUT_DIR/$APP_NAME.bat" <<EOF
@echo off
set SCRIPT_DIR=%~dp0
java -jar "%SCRIPT_DIR%$APP_NAME.jar" %*
EOF
fi


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ 🔒  LAUNCHER CONTRACT — DO NOT EDIT                                       ║
# ║                                                                           ║
# ║  Java releases ship: <APP_NAME>.jar + launcher wrapper per platform.      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
[ -f "$OUTPUT_DIR/$APP_NAME.jar" ] || { echo "ERROR: JAR missing in $OUTPUT_DIR/"; exit 1; }
[ "$BUILD_LINUX"   = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME"     ] || { echo "ERROR: Linux launcher missing";   exit 1; }; }
[ "$BUILD_WINDOWS" = "1" ] && { [ -f "$OUTPUT_DIR/$APP_NAME.bat" ] || { echo "ERROR: Windows launcher missing"; exit 1; }; }
echo "[+] Artifacts written to $OUTPUT_DIR/"
