# Runner Setup Guide

This folder contains everything needed to prepare a self-hosted GitHub Actions / Gitea runner
for all languages supported by this template:
**Go · Python · Rust · Node.js · Java · .NET · Ruby · PHP · C · C++ · Script (no-compile)**

---

## Quick start

| Runner OS | Script |
|-----------|--------|
| Linux (Debian/Ubuntu) | `sudo bash setup-linux.sh` |
| Windows 10/11 | `.\setup-windows.ps1` (Admin PowerShell) |

The scripts are idempotent — they skip tools already installed.

---

## What each script installs

| Tool | Linux | Windows | Required for |
|------|-------|---------|--------------|
| Git | ✓ | ✓ | All |
| Go | ✓ | ✓ | `go` |
| gcc / MinGW-w64 | ✓ | ✓ | `go` (CGO/Fyne), `c`, `cpp` |
| Fyne system libs (GL/X11) | ✓ | — | `go` with Fyne |
| Python 3 + pip | ✓ | ✓ | `python` |
| Rust (rustup) | ✓ | ✓ | `rust` |
| Node.js (LTS) | ✓ | ✓ | `node` |
| Java (Temurin JDK 21) | ✓ | ✓ | `java` |
| .NET SDK 8 | ✓ | ✓ | `dotnet` |
| Ruby + DevKit | ✓ | ✓ | `ruby` |
| fpm (gem) | ✓ | — | `.deb` packaging |
| PHP 8 | ✓ | ✓ | `php` |
| CMake + Ninja | ✓ | ✓ | `c`, `cpp` |
| zip | ✓ | ✓ | `script` (archive mode) |

---

## Runner labels

The workflow matches runners by label. Make sure your runner is registered with the
labels that appear in the `runs-on:` fields of your workflow.

Default labels used by this template:

```
Linux:   self-hosted, debian-12
Windows: self-hosted, windows-latest   (or: self-hosted, windows)
```

You can customise these per-project from the launcher dashboard.

---

## Registering the runner

### GitHub Actions

```bash
# 1. Create a runner in your repo:
#    GitHub → Settings → Actions → Runners → New self-hosted runner

# 2. Follow GitHub's download + configure steps, then:
sudo ./svc.sh install
sudo ./svc.sh start
```

### Gitea Act Runner

```bash
# Download act_runner from https://gitea.com/gitea/act_runner/releases
chmod +x act_runner
./act_runner register --instance https://<your-gitea> --token <token> --name my-runner --labels "self-hosted,debian-12"
./act_runner daemon &
# Or install as a systemd service (see below)
```

<details>
<summary>Gitea systemd service</summary>

```ini
# /etc/systemd/system/act_runner.service
[Unit]
Description=Gitea Act Runner
After=network.target

[Service]
ExecStart=/usr/local/bin/act_runner daemon
WorkingDirectory=/opt/act_runner
Restart=always
User=runner

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable --now act_runner
```
</details>

---

## Manual installation (step by step)

<details>
<summary>Linux — Debian/Ubuntu</summary>

```bash
# System base
sudo apt-get update
sudo apt-get install -y curl wget git build-essential pkg-config zip unzip

# ── Go ──────────────────────────────────────────────────────────────────────
GO_VERSION="1.22.5"
curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" | sudo tar -C /usr/local -xz
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
source /etc/profile.d/go.sh

# Fyne system libraries (OpenGL + X11 — needed for CGO GUI builds)
sudo apt-get install -y libgl1-mesa-dev xorg-dev

# ── Python ───────────────────────────────────────────────────────────────────
sudo apt-get install -y python3 python3-pip python3-venv

# ── Rust ─────────────────────────────────────────────────────────────────────
curl https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path
source "$HOME/.cargo/env"
# Symlink so the runner service finds cargo without user PATH
sudo ln -sf "$HOME/.cargo/bin/rustc"  /usr/local/bin/rustc
sudo ln -sf "$HOME/.cargo/bin/cargo"  /usr/local/bin/cargo
sudo ln -sf "$HOME/.cargo/bin/rustup" /usr/local/bin/rustup

# ── Node.js (LTS via NodeSource) ─────────────────────────────────────────────
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# ── Java (Temurin 21) ────────────────────────────────────────────────────────
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo apt-key add -
echo "deb https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/adoptium.list
sudo apt-get update && sudo apt-get install -y temurin-21-jdk

# ── .NET SDK 8 ───────────────────────────────────────────────────────────────
wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb
sudo apt-get update && sudo apt-get install -y dotnet-sdk-8.0

# ── Ruby + fpm ───────────────────────────────────────────────────────────────
sudo apt-get install -y ruby ruby-dev rubygems
sudo gem install --no-document fpm

# ── PHP ──────────────────────────────────────────────────────────────────────
sudo apt-get install -y php php-cli php-mbstring php-xml php-curl composer

# ── C / C++ ──────────────────────────────────────────────────────────────────
sudo apt-get install -y gcc g++ cmake ninja-build
```
</details>

<details>
<summary>Windows — PowerShell (Admin)</summary>

```powershell
# Requires winget (Windows 10 1709+ / Windows 11)

# ── Git ──────────────────────────────────────────────────────────────────────
winget install --id Git.Git -e --silent

# ── Go ───────────────────────────────────────────────────────────────────────
winget install --id GoLang.Go -e --silent

# ── MinGW-w64 via MSYS2 (required for Go CGO and C/C++) ─────────────────────
winget install --id MSYS2.MSYS2 -e --silent
# After MSYS2 installs, open MSYS2 terminal and run:
#   pacman -S --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja
# Then add to system PATH: C:\msys64\mingw64\bin

# ── Python ───────────────────────────────────────────────────────────────────
winget install --id Python.Python.3.11 -e --silent

# ── Rust ─────────────────────────────────────────────────────────────────────
winget install --id Rustlang.Rustup -e --silent

# ── Node.js ──────────────────────────────────────────────────────────────────
winget install --id OpenJS.NodeJS.LTS -e --silent

# ── Java (Temurin 21) ────────────────────────────────────────────────────────
winget install --id EclipseAdoptium.Temurin.21.JDK -e --silent

# ── .NET SDK 8 ───────────────────────────────────────────────────────────────
winget install --id Microsoft.DotNet.SDK.8 -e --silent

# ── Ruby + DevKit ────────────────────────────────────────────────────────────
winget install --id RubyInstallerTeam.RubyWithDevKit.3.3 -e --silent

# ── PHP ──────────────────────────────────────────────────────────────────────
# Download from https://windows.php.net/download/ and add to PATH

# ── CMake ────────────────────────────────────────────────────────────────────
winget install --id Kitware.CMake -e --silent
```
</details>

---

## Verifying the setup

Run these from the terminal where the runner service executes (not your interactive shell):

```bash
go version
gcc --version
python3 --version   # Linux  |  py --version  (Windows)
rustc --version
node --version
java --version
dotnet --version
ruby --version
php --version
cmake --version
zip --help | head -1
```

---

## Troubleshooting

### `gcc not found` on Windows runner
The runner service launches before MSYS2 is on the PATH. Fix: open the runner's `.env`
file (in the runner install directory) and add:
```
PATH=C:\msys64\mingw64\bin;%PATH%
```
Then restart the runner service.

### `cargo not found` on Linux runner
The runner service uses a minimal environment. Fix: add the cargo bin to the runner `.env`:
```
PATH=/home/<runner-user>/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

### `could not resolve host` during workflow
The runner has no internet access. Check firewall rules and proxy settings. GitHub-hosted runners
have internet by default; self-hosted runners need outbound HTTPS (443) to `github.com` and
`*.ghcr.io` (or your Gitea server).

### Fyne build fails with `libGL.so.1: cannot open shared object file`
Install the Fyne system dependencies:
```bash
sudo apt-get install -y libgl1-mesa-dev xorg-dev
```
