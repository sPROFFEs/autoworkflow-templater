#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Prepare a Windows self-hosted runner for all languages supported by plantilla-flow.

.DESCRIPTION
    Installs: Git, Go, MinGW-w64 (via MSYS2), Python 3, Rust, Node.js LTS,
    Java (Temurin 21), .NET SDK 8, Ruby+DevKit, PHP, CMake/Ninja.

    Idempotent — tools already on the system PATH are skipped.
    Requires Administrator privileges and winget (Windows 10 1709+ / Windows 11).

.EXAMPLE
    .\setup-windows.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Helpers ────────────────────────────────────────────────────────────────────
function Write-Ok   { param($msg) Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host " -  $msg already installed, skipping" -ForegroundColor DarkGray }
function Write-Step { param($msg) Write-Host "[>] $msg" -ForegroundColor Cyan }
function Write-Warn { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "[x] $msg" -ForegroundColor Red; exit 1 }

function Is-CommandAvailable {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-Winget {
    param(
        [string]$Id,
        [string]$Label
    )
    Write-Step "Installing $Label via winget…"
    winget install --id $Id -e --silent --accept-source-agreements --accept-package-agreements
    Write-Ok "$Label installed"
}

# ── Check prerequisites ────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==================================================" -ForegroundColor White
Write-Host "  plantilla-flow runner setup — Windows" -ForegroundColor White
Write-Host "==================================================" -ForegroundColor White
Write-Host ""

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Err "winget not found. Install App Installer from the Microsoft Store or update Windows."
}
Write-Ok "winget available"

# ── Git ───────────────────────────────────────────────────────────────────────
if (Is-CommandAvailable git) {
    Write-Skip "Git ($(git --version))"
} else {
    Install-Winget -Id 'Git.Git' -Label 'Git'
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

# ── Go ────────────────────────────────────────────────────────────────────────
if (Is-CommandAvailable go) {
    Write-Skip "Go ($(go version))"
} else {
    Install-Winget -Id 'GoLang.Go' -Label 'Go'
}

# ── MSYS2 + MinGW-w64 (required for Go CGO / C / C++) ────────────────────────
$MinGWBin = 'C:\msys64\mingw64\bin'
if (Test-Path "$MinGWBin\gcc.exe") {
    Write-Skip "MinGW-w64 gcc ($MinGWBin)"
} else {
    Write-Step "Installing MSYS2…"
    winget install --id MSYS2.MSYS2 -e --silent --accept-source-agreements --accept-package-agreements
    Write-Ok "MSYS2 installed"

    Write-Step "Installing MinGW-w64 toolchain inside MSYS2 (this may take a few minutes)…"
    $pacman = 'C:\msys64\usr\bin\bash.exe'
    if (Test-Path $pacman) {
        & $pacman -lc 'pacman -Sy --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja'
        Write-Ok "MinGW-w64 toolchain installed"
    } else {
        Write-Warn "MSYS2 bash not found at $pacman — run manually inside MSYS2:"
        Write-Warn "  pacman -S --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja"
    }

    # Add MinGW bin to the system PATH permanently.
    $syspath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    if ($syspath -notlike "*$MinGWBin*") {
        [System.Environment]::SetEnvironmentVariable('Path', "$MinGWBin;$syspath", 'Machine')
        Write-Ok "Added $MinGWBin to system PATH"
    }
}

# Also add to runner service .env file reminder (printed at the end).
$runnerEnvNote = $true

# ── Python ────────────────────────────────────────────────────────────────────
if (Is-CommandAvailable python) {
    Write-Skip "Python ($(python --version 2>&1))"
} else {
    Install-Winget -Id 'Python.Python.3.11' -Label 'Python 3.11'
}

# ── Rust ──────────────────────────────────────────────────────────────────────
if (Is-CommandAvailable rustc) {
    Write-Skip "Rust ($(rustc --version))"
} else {
    Install-Winget -Id 'Rustlang.Rustup' -Label 'Rustup'
    Write-Warn "Restart this terminal (or re-log) so rustup's PATH entry takes effect, then run:"
    Write-Warn "  rustup toolchain install stable"
}

# ── Node.js LTS ───────────────────────────────────────────────────────────────
if (Is-CommandAvailable node) {
    Write-Skip "Node.js ($(node --version))"
} else {
    Install-Winget -Id 'OpenJS.NodeJS.LTS' -Label 'Node.js LTS'
}

# ── Java (Temurin 21) ─────────────────────────────────────────────────────────
if (Is-CommandAvailable java) {
    Write-Skip "Java ($(java -version 2>&1 | Select-Object -First 1))"
} else {
    Install-Winget -Id 'EclipseAdoptium.Temurin.21.JDK' -Label 'Eclipse Temurin JDK 21'
}

# ── .NET SDK 8 ────────────────────────────────────────────────────────────────
if (Is-CommandAvailable dotnet) {
    Write-Skip ".NET ($(dotnet --version))"
} else {
    Install-Winget -Id 'Microsoft.DotNet.SDK.8' -Label '.NET SDK 8'
}

# ── Ruby + DevKit ─────────────────────────────────────────────────────────────
if (Is-CommandAvailable ruby) {
    Write-Skip "Ruby ($(ruby --version))"
} else {
    Install-Winget -Id 'RubyInstallerTeam.RubyWithDevKit.3.3' -Label 'Ruby 3.3 + DevKit'
    Write-Warn "After Ruby installs, open a new terminal and run:"
    Write-Warn "  ridk install 3"
}

# ── PHP ───────────────────────────────────────────────────────────────────────
if (Is-CommandAvailable php) {
    Write-Skip "PHP ($(php --version | Select-Object -First 1))"
} else {
    # winget doesn't have a stable PHP package; guide the user.
    Write-Warn "PHP: no reliable winget package. Download the Thread Safe ZIP from:"
    Write-Warn "  https://windows.php.net/download/"
    Write-Warn "Extract to C:\php and add C:\php to the system PATH."
    Write-Warn "Then add C:\php to the runner service .env file (see note below)."
}

# ── CMake ─────────────────────────────────────────────────────────────────────
if (Is-CommandAvailable cmake) {
    Write-Skip "CMake ($(cmake --version | Select-Object -First 1))"
} else {
    # CMake ships with MinGW-w64 via MSYS2; also install standalone for PATH ease.
    Install-Winget -Id 'Kitware.CMake' -Label 'CMake'
}

# ── Refresh current session PATH ──────────────────────────────────────────────
$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + `
            [System.Environment]::GetEnvironmentVariable('Path', 'User')

# ── Verification ──────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==================================================" -ForegroundColor White
Write-Host "  Verification (may show 'not found' for tools" -ForegroundColor White
Write-Host "  that need a new terminal to update PATH)" -ForegroundColor White
Write-Host "==================================================" -ForegroundColor White

function Check-Tool {
    param([string]$Label, [string]$Cmd, [string]$Args = '--version')
    try {
        $out = & $Cmd $Args 2>&1 | Select-Object -First 1
        Write-Host ("  {0,-12} {1}" -f $Label, $out) -ForegroundColor Green
    } catch {
        Write-Host ("  {0,-12} not found" -f $Label) -ForegroundColor Red
    }
}

Check-Tool 'git'    'git'    '--version'
Check-Tool 'go'     'go'     'version'
Check-Tool 'gcc'    'gcc'    '--version'
Check-Tool 'python' 'python' '--version'
Check-Tool 'rustc'  'rustc'  '--version'
Check-Tool 'node'   'node'   '--version'
Check-Tool 'java'   'java'   '-version'
Check-Tool 'dotnet' 'dotnet' '--version'
Check-Tool 'ruby'   'ruby'   '--version'
Check-Tool 'cmake'  'cmake'  '--version'

# ── Runner service .env note ──────────────────────────────────────────────────
if ($runnerEnvNote) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host "  IMPORTANT: Runner service PATH" -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  The runner service launches with a minimal PATH." -ForegroundColor Yellow
    Write-Host "  Open the runner's .env file (in the runner install directory)" -ForegroundColor Yellow
    Write-Host "  and add the following line so CGO/C++ builds work:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    PATH=C:\msys64\mingw64\bin;%PATH%" -ForegroundColor White
    Write-Host ""
    Write-Host "  If you installed PHP manually, also add C:\php to that line." -ForegroundColor Yellow
    Write-Host "  Then restart the runner service." -ForegroundColor Yellow
}

Write-Host ""
Write-Ok "Runner setup complete."
Write-Host ""
Write-Host "Register this runner (GitHub Actions example):"
Write-Host "  GitHub → Settings → Actions → Runners → New self-hosted runner"
Write-Host ""
Write-Host "Suggested runner labels:  self-hosted,windows-latest"
Write-Host ""
