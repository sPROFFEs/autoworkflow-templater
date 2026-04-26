#!/usr/bin/env bash
# =============================================================================
#  setup-linux.sh — Prepare a Debian/Ubuntu self-hosted runner
#  for all languages supported by plantilla-flow.
#
#  Usage:  sudo bash setup-linux.sh
#
#  Idempotent: already-installed tools are skipped.
#  Tested on: Debian 12, Ubuntu 22.04, Ubuntu 24.04
# =============================================================================
set -euo pipefail

# ── Helpers ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }
skip() { echo -e "    [–] $* already installed, skipping"; }

require_root() {
  [ "$(id -u)" -eq 0 ] || err "Run this script with sudo: sudo bash $0"
}

# ── Entry point ────────────────────────────────────────────────────────────────
require_root

echo "=================================================="
echo "  plantilla-flow runner setup — Linux"
echo "=================================================="
echo ""

# ── System base ────────────────────────────────────────────────────────────────
echo "[→] Updating package lists…"
apt-get update -qq

echo "[→] Installing base tools…"
apt-get install -y -qq \
  curl wget git build-essential pkg-config \
  zip unzip tar lsb-release ca-certificates \
  gnupg software-properties-common

ok "Base tools ready"

# ── Go ─────────────────────────────────────────────────────────────────────────
GO_VERSION="1.22.5"
if command -v go &>/dev/null; then
  skip "Go ($(go version | awk '{print $3}'))"
else
  echo "[→] Installing Go ${GO_VERSION}…"
  ARCH="$(dpkg --print-architecture)"
  case "$ARCH" in
    amd64) GO_ARCH="amd64" ;;
    arm64) GO_ARCH="arm64" ;;
    *) err "Unsupported architecture for Go: $ARCH" ;;
  esac
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" \
    | tar -C /usr/local -xz
  cat > /etc/profile.d/go.sh <<'EOF'
export PATH=$PATH:/usr/local/go/bin
EOF
  export PATH=$PATH:/usr/local/go/bin
  ok "Go ${GO_VERSION} installed"
fi

# Fyne system libraries (OpenGL + X11 — required for CGO GUI builds)
echo "[→] Installing Fyne/CGO system libraries…"
apt-get install -y -qq libgl1-mesa-dev xorg-dev
ok "Fyne system libraries ready"

# ── Python ────────────────────────────────────────────────────────────────────
if command -v python3 &>/dev/null; then
  skip "Python ($(python3 --version))"
else
  echo "[→] Installing Python 3…"
  apt-get install -y -qq python3 python3-pip python3-venv
  ok "Python 3 installed"
fi

# Ensure pip is available even when python3 was pre-installed
if ! command -v pip3 &>/dev/null; then
  apt-get install -y -qq python3-pip
fi

# ── Rust ──────────────────────────────────────────────────────────────────────
if command -v rustc &>/dev/null; then
  skip "Rust ($(rustc --version))"
else
  echo "[→] Installing Rust via rustup…"
  RUNNER_HOME="${SUDO_HOME:-/root}"
  # Install as the invoking user so cargo is in their home, then symlink globally.
  ACTUAL_USER="${SUDO_USER:-root}"
  su - "$ACTUAL_USER" -c 'curl https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path'
  CARGO_BIN="$(eval echo "~$ACTUAL_USER")/.cargo/bin"
  ln -sf "$CARGO_BIN/rustc"  /usr/local/bin/rustc
  ln -sf "$CARGO_BIN/cargo"  /usr/local/bin/cargo
  ln -sf "$CARGO_BIN/rustup" /usr/local/bin/rustup
  ok "Rust installed (symlinked to /usr/local/bin)"
fi

# ── Node.js LTS ───────────────────────────────────────────────────────────────
if command -v node &>/dev/null; then
  skip "Node.js ($(node --version))"
else
  echo "[→] Installing Node.js LTS via NodeSource…"
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
  apt-get install -y -qq nodejs
  ok "Node.js $(node --version) installed"
fi

# ── Java (Temurin 21) ─────────────────────────────────────────────────────────
if command -v java &>/dev/null; then
  skip "Java ($(java -version 2>&1 | head -1))"
else
  echo "[→] Installing Eclipse Temurin JDK 21…"
  CODENAME="$(lsb_release -cs)"
  wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
    | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg
  echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] \
https://packages.adoptium.net/artifactory/deb ${CODENAME} main" \
    > /etc/apt/sources.list.d/adoptium.list
  apt-get update -qq
  apt-get install -y -qq temurin-21-jdk
  ok "Java (Temurin 21) installed"
fi

# ── .NET SDK 8 ────────────────────────────────────────────────────────────────
if command -v dotnet &>/dev/null; then
  skip ".NET ($(dotnet --version))"
else
  echo "[→] Installing .NET SDK 8…"
  CODENAME="$(lsb_release -cs)"
  OS_ID="$(lsb_release -is | tr '[:upper:]' '[:lower:]')"
  # Microsoft packages feed
  PKG="packages-microsoft-prod.deb"
  wget -q "https://packages.microsoft.com/config/${OS_ID}/$(lsb_release -rs)/${PKG}"
  dpkg -i "$PKG" && rm "$PKG"
  apt-get update -qq
  apt-get install -y -qq dotnet-sdk-8.0
  ok ".NET SDK 8 installed"
fi

# ── Ruby + fpm ────────────────────────────────────────────────────────────────
if command -v ruby &>/dev/null; then
  skip "Ruby ($(ruby --version))"
else
  echo "[→] Installing Ruby…"
  apt-get install -y -qq ruby ruby-dev rubygems
  ok "Ruby installed"
fi

if gem list fpm -i &>/dev/null 2>&1; then
  skip "fpm (gem)"
else
  echo "[→] Installing fpm…"
  gem install --no-document fpm
  ok "fpm installed"
fi

# ── PHP ───────────────────────────────────────────────────────────────────────
if command -v php &>/dev/null; then
  skip "PHP ($(php --version | head -1))"
else
  echo "[→] Installing PHP 8…"
  apt-get install -y -qq php php-cli php-mbstring php-xml php-curl
  # Install Composer
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  ok "PHP installed"
fi

# ── C / C++ / CMake / Ninja ────────────────────────────────────────────────────
if command -v cmake &>/dev/null; then
  skip "CMake ($(cmake --version | head -1))"
else
  echo "[→] Installing CMake and Ninja…"
  apt-get install -y -qq cmake ninja-build
  ok "CMake + Ninja installed"
fi

# gcc/g++ are pulled in via build-essential above; confirm
if command -v gcc &>/dev/null; then
  skip "gcc ($(gcc --version | head -1))"
fi

# ── Verification summary ───────────────────────────────────────────────────────
echo ""
echo "=================================================="
echo "  Verification"
echo "=================================================="
check() {
  local label="$1"; shift
  if out=$("$@" 2>&1 | head -1); then
    printf "  ${GREEN}✓${NC}  %-12s %s\n" "$label" "$out"
  else
    printf "  ${RED}✗${NC}  %-12s not found\n" "$label"
  fi
}

check "go"     go version
check "gcc"    gcc --version
check "python" python3 --version
check "rustc"  rustc --version
check "node"   node --version
check "java"   java --version
check "dotnet" dotnet --version
check "ruby"   ruby --version
check "php"    php --version
check "cmake"  cmake --version
check "zip"    zip --version

echo ""
ok "Runner setup complete."
echo ""
echo "Register this runner, then start the service:"
echo "  sudo ./svc.sh install && sudo ./svc.sh start   # GitHub Actions"
echo "  ./act_runner daemon                             # Gitea Act Runner"
echo ""
echo "Suggested runner labels:  self-hosted,debian-12"
