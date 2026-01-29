# Moltbot Installer for Windows (Updated for C3)
# Usage: iwr -useb https://molt.bot/install.ps1 | iex
#        & ([scriptblock]::Create((iwr -useb https://molt.bot/install.ps1))) -Tag beta -NoOnboard -DryRun

param(
    [string]$Tag = "latest",
    [ValidateSet("npm", "git")]
    [string]$InstallMethod = "npm",
    [string]$GitDir,
    [switch]$NoOnboard,
    [switch]$NoGitUpdate,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  Moltbot Installer (C3 Edition)" -ForegroundColor Cyan
Write-Host ""

# Check if running in PowerShell
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "Error: PowerShell 5+ required" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Windows detected" -ForegroundColor Green

if (-not $PSBoundParameters.ContainsKey("InstallMethod")) {
    if (-not [string]::IsNullOrWhiteSpace($env:CLAWDBOT_INSTALL_METHOD)) {
        $InstallMethod = $env:CLAWDBOT_INSTALL_METHOD
    }
}
if (-not $PSBoundParameters.ContainsKey("GitDir")) {
    if (-not [string]::IsNullOrWhiteSpace($env:CLAWDBOT_GIT_DIR)) {
        $GitDir = $env:CLAWDBOT_GIT_DIR
    }
}
if (-not $PSBoundParameters.ContainsKey("NoOnboard")) {
    if ($env:CLAWDBOT_NO_ONBOARD -eq "1") {
        $NoOnboard = $true
    }
}
if (-not $PSBoundParameters.ContainsKey("NoGitUpdate")) {
    if ($env:CLAWDBOT_GIT_UPDATE -eq "0") {
        $NoGitUpdate = $true
    }
}
if (-not $PSBoundParameters.ContainsKey("DryRun")) {
    if ($env:CLAWDBOT_DRY_RUN -eq "1") {
        $DryRun = $true
    }
}

if ([string]::IsNullOrWhiteSpace($GitDir)) {
    $userHome = [Environment]::GetFolderPath("UserProfile")
    # Updated default directory name to c3
    $GitDir = (Join-Path $userHome "c3")
}

# Check for Node.js
function Check-Node {
    try {
        $nodeVersion = (node -v 2>$null)
        if ($nodeVersion) {
            $version = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
            if ($version -ge 22) {
                Write-Host "[OK] Node.js $nodeVersion found" -ForegroundColor Green
                return $true
            } else {
                Write-Host "[!] Node.js $nodeVersion found, but v22+ required" -ForegroundColor Yellow
                return $false
            }
        }
    } catch {
        Write-Host "[!] Node.js not found" -ForegroundColor Yellow
        return $false
    }
    return $false
}

# Install Node.js
function Install-Node {
    Write-Host "[*] Installing Node.js..." -ForegroundColor Yellow

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  Using winget..." -ForegroundColor Gray
        winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "[OK] Node.js installed via winget" -ForegroundColor Green
        return
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "  Using Chocolatey..." -ForegroundColor Gray
        choco install nodejs-lts -y
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "[OK] Node.js installed via Chocolatey" -ForegroundColor Green
        return
    }

    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "  Using Scoop..." -ForegroundColor Gray
        scoop install nodejs-lts
        Write-Host "[OK] Node.js installed via Scoop" -ForegroundColor Green
        return
    }

    Write-Host ""
    Write-Host "Error: Could not find a package manager (winget, choco, or scoop)" -ForegroundColor Red
    Write-Host "Please install Node.js 22+ manually: https://nodejs.org/en/download/" -ForegroundColor Cyan
    exit 1
}

function Check-ExistingMoltbot {
    try {
        $null = Get-Command clawdbot -ErrorAction Stop
        Write-Host "[*] Existing Moltbot installation detected" -ForegroundColor Yellow
        return $true
    } catch {
        return $false
    }
}

function Check-Git {
    try {
        $null = Get-Command git -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Require-Git {
    if (Check-Git) { return }
    Write-Host ""
    Write-Host "Error: Git is required for --InstallMethod git." -ForegroundColor Red
    Write-Host "Install Git for Windows: https://git-scm.com/download/win" -ForegroundColor Cyan
    exit 1
}

function Ensure-MoltbotOnPath {
    if (Get-Command clawdbot -ErrorAction SilentlyContinue) {
        return $true
    }

    $npmPrefix = $null
    try {
        $npmPrefix = (npm config get prefix 2>$null).Trim()
    } catch {
        $npmPrefix = $null
    }

    if (-not [string]::IsNullOrWhiteSpace($npmPrefix)) {
        $npmBin = Join-Path $npmPrefix "bin"
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if (-not ($userPath -split ";" | Where-Object { $_ -ieq $npmBin })) {
            [Environment]::SetEnvironmentVariable("Path", "$userPath;$npmBin", "User")
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-Host "[!] Added $npmBin to user PATH" -ForegroundColor Yellow
        }
        if (Test-Path (Join-Path $npmBin "clawdbot.cmd")) {
            return $true
        }
    }
    return $false
}

function Ensure-Pnpm {
    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        return
    }
    if (Get-Command corepack -ErrorAction SilentlyContinue) {
        try {
            corepack enable | Out-Null
            corepack prepare pnpm@latest --activate | Out-Null
            if (Get-Command pnpm -ErrorAction SilentlyContinue) {
                Write-Host "[OK] pnpm installed via corepack" -ForegroundColor Green
                return
            }
        } catch { }
    }
    Write-Host "[*] Installing pnpm..." -ForegroundColor Yellow
    npm install -g pnpm
    Write-Host "[OK] pnpm installed" -ForegroundColor Green
}

function Install-Moltbot {
    if ([string]::IsNullOrWhiteSpace($Tag)) {
        $Tag = "latest"
    }
    Write-Host "[*] Installing Moltbot@$Tag..." -ForegroundColor Yellow
    # Note: If 'clawdbot' package name changes on NPM, update this string:
    $npmOutput = npm install -g "clawdbot@$Tag" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] npm install failed" -ForegroundColor Red
        $npmOutput | ForEach-Object { Write-Host $_ }
        exit 1
    }
    Write-Host "[OK] Moltbot installed" -ForegroundColor Green
}

# Install Moltbot from the NEW GitHub Repo
function Install-MoltbotFromGit {
    param(
        [string]$RepoDir,
        [switch]$SkipUpdate
    )
    Require-Git
    Ensure-Pnpm

    # NEW REPO URL APPLIED HERE
    $repoUrl = "https://github.com/its3li/C3.git"
    Write-Host "[*] Installing Moltbot from GitHub ($repoUrl)..." -ForegroundColor Yellow

    if (-not (Test-Path $RepoDir)) {
        git clone $repoUrl $RepoDir
    }

    if (-not $SkipUpdate) {
        if (-not (git -C $RepoDir status --porcelain 2>$null)) {
            git -C $RepoDir pull --rebase 2>$null
        } else {
            Write-Host "[!] Repo is dirty; skipping git pull" -ForegroundColor Yellow
        }
    }

    Remove-LegacySubmodule -RepoDir $RepoDir

    pnpm -C $RepoDir install
    pnpm -C $RepoDir build

    $binDir = Join-Path $env:USERPROFILE ".local\bin"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    }
    $cmdPath = Join-Path $binDir "clawdbot.cmd"
    $cmdContents = "@echo off`r`nnode ""$RepoDir\dist\entry.js"" %*`r`n"
    Set-Content -Path $cmdPath -Value $cmdContents -NoNewline

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not ($userPath -split ";" | Where-Object { $_ -ieq $binDir })) {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "[!] Added $binDir to user PATH" -ForegroundColor Yellow
    }

    Write-Host "[OK] Moltbot wrapper installed to $cmdPath" -ForegroundColor Green
}

function Run-Doctor {
    Write-Host "[*] Running doctor to migrate settings..." -ForegroundColor Yellow
    try {
        clawdbot doctor --non-interactive
    } catch { }
    Write-Host "[OK] Migration complete" -ForegroundColor Green
}

function Remove-LegacySubmodule {
    param([string]$RepoDir)
    $legacyDir = Join-Path $RepoDir "Peekaboo"
    if (Test-Path $legacyDir) {
        Write-Host "[!] Removing legacy submodule checkout: $legacyDir" -ForegroundColor Yellow
        Remove-Item -Recurse -Force $legacyDir
    }
}

function Main {
    if ($InstallMethod -ne "npm" -and $InstallMethod -ne "git") {
        Write-Host "Error: invalid -InstallMethod (use npm or git)." -ForegroundColor Red
        exit 2
    }

    if ($DryRun) {
        Write-Host "[OK] Dry run - Install method: $InstallMethod" -ForegroundColor Green
        return
    }

    $isUpgrade = Check-ExistingMoltbot

    if (-not (Check-Node)) {
        Install-Node
        if (-not (Check-Node)) {
            Write-Host "Error: Restart terminal and run again." -ForegroundColor Red
            exit 1
        }
    }

    if ($InstallMethod -eq "git") {
        Install-MoltbotFromGit -RepoDir $GitDir -SkipUpdate:$NoGitUpdate
    } else {
        Install-Moltbot
    }

    if (-not (Ensure-MoltbotOnPath)) {
        Write-Host "Install completed. Open a new terminal and run: clawdbot doctor" -ForegroundColor Cyan
        return
    }

    if ($isUpgrade -or $InstallMethod -eq "git") {
        Run-Doctor
    }

    Write-Host ""
    Write-Host "Moltbot (C3) installed successfully!" -ForegroundColor Green
    Write-Host ""

    if ($NoOnboard) {
        Write-Host "Run 'clawdbot onboard' later." -ForegroundColor Cyan
    } else {
        Write-Host "Starting setup..." -ForegroundColor Cyan
        clawdbot onboard
    }
}

Main
