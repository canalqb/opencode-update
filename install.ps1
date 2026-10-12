# ============================================================
# opencode-update - installer
# Repo: https://github.com/canalqb/opencode-update
#
# One-liner (from any PowerShell window):
#   irm https://github.com/canalqb/opencode-update/releases/latest/download/install.ps1 | iex
#
# What it does:
#   1. Ensures Scoop is installed (installs it if missing)
#   2. Ensures opencode is installed (via Scoop, latest version)
#   3. Installs opencode-update to %LOCALAPPDATA%\Programs\opencode-update
#   4. Adds the folder to your user PATH (command: opencode-update)
#   5. With -Run, updates opencode right away
#
# Options (when saved to disk and run with -File):
#   -InstallDir <path>  custom install folder
#   -SkipScoop          do not install Scoop/opencode, only deploy the scripts
#   -NoPath             do not modify the user PATH
#   -Run                run the updater immediately after install
# ============================================================
[CmdletBinding()]
param(
    [string]$InstallDir = '',
    [switch]$SkipScoop,
    [switch]$NoPath,
    [switch]$Run
)

$ErrorActionPreference = 'Stop'

# GitHub release (latest) that hosts the script bundle
$ZipUrl = 'https://github.com/canalqb/opencode-update/releases/latest/download/opencode-update.zip'

function Write-Step {
    param([string]$Message)
    Write-Host ("==> {0}" -f $Message) -ForegroundColor Cyan
}

function Ensure-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) { return }
    if ($SkipScoop) { throw 'Scoop not found and -SkipScoop was used.' }
    Write-Step 'Installing Scoop (Windows package manager)...'
    Invoke-RestMethod -Uri 'https://get.scoop.dev' | Invoke-Expression
    # make sure the shims folder is usable in this same session
    $shims = Join-Path $env:USERPROFILE 'scoop\shims'
    if ((Test-Path $shims) -and ($env:Path -notlike ('*' + $shims + '*'))) {
        $env:Path = $env:Path + ';' + $shims
    }
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        throw 'Scoop installation did not finish. Open a NEW PowerShell window and run this installer again.'
    }
}

function Ensure-Git {
    # Scoop needs git to refresh buckets; install it silently if missing (best effort).
    if (Get-Command git -ErrorAction SilentlyContinue) { return }
    try {
        Write-Step 'Installing git (needed by Scoop to update buckets)...'
        & scoop install git | Out-Null
    } catch {
        Write-Host '    git install skipped or failed; Scoop bucket updates may be limited.' -ForegroundColor Yellow
    }
}

function Ensure-Opencode {
    if (Get-Command opencode -ErrorAction SilentlyContinue) {
        Write-Step 'opencode: already installed.'
        return
    }
    Write-Step 'Installing opencode (latest) via Scoop...'
    & scoop install opencode
    if ($LASTEXITCODE -ne 0) {
        Write-Host '    Retrying after adding the main bucket...' -ForegroundColor Yellow
        & scoop bucket add main 2>$null
        & scoop install opencode
        if ($LASTEXITCODE -ne 0) { throw 'Failed to install opencode via Scoop.' }
    }
}

function Deploy-Scripts {
    param([string]$Target)
    Write-Step 'Downloading the latest opencode-update bundle...'
    $zip = Join-Path $env:TEMP 'opencode-update.zip'
    Invoke-WebRequest -Uri $ZipUrl -OutFile $zip -UseBasicParsing
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    Expand-Archive -Path $zip -DestinationPath $Target -Force
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue

    # command shim so the user can call: opencode-update
    $shim = Join-Path $Target 'opencode-update.cmd'
    $lines = @(
        '@echo off',
        'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0opencode-update.ps1" %*'
    )
    Set-Content -LiteralPath $shim -Value $lines -Encoding ASCII
    Write-Step ("Deployed to: {0}" -f $Target)
}

function Add-UserPath {
    param([string]$Dir)
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { $userPath = '' }
    if ($userPath -notlike ('*' + $Dir + '*')) {
        [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $Dir), 'User')
    }
    if ($env:Path -notlike ('*' + $Dir + '*')) { $env:Path = $env:Path + ';' + $Dir }
}

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '=== opencode-update installer ===' -ForegroundColor Cyan
Write-Host 'Repo: https://github.com/canalqb/opencode-update' -ForegroundColor DarkGray
Write-Host ''

# Windows PowerShell 5.1 may need TLS 1.2 enabled for GitHub downloads
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

try {
    if (-not $InstallDir) {
        $InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\opencode-update'
    }

    if (-not $SkipScoop) {
        Ensure-Scoop
        Ensure-Git
        Ensure-Opencode
    } else {
        Write-Step 'Skipping Scoop/opencode setup (-SkipScoop).'
    }

    Deploy-Scripts -Target $InstallDir

    if (-not $NoPath) {
        Write-Step 'Adding the install folder to your user PATH...'
        Add-UserPath -Dir $InstallDir
    } else {
        Write-Step 'PATH not modified (-NoPath).'
    }

    Write-Host ''
    Write-Host '=== Installed successfully ===' -ForegroundColor Green
    Write-Host ''
    Write-Host 'How to update opencode from now on (open a NEW PowerShell window):'
    Write-Host '    opencode-update' -ForegroundColor White
    Write-Host ''
    Write-Host ('Or directly: powershell -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $InstallDir 'opencode-update.ps1'))
    Write-Host 'The updater backs up your models, updates opencode via Scoop and verifies everything.'
    Write-Host ''
    Write-Host 'Uninstall: powershell -File uninstall.ps1  (in the install folder)'
    Write-Host ''

    if ($Run) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallDir 'opencode-update.ps1')
    } else {
        Write-Host 'Next step: close opencode, open a new PowerShell window and run: opencode-update'
    }
}
catch {
    Write-Host ''
    Write-Host ("INSTALL FAILED: {0}" -f $_.Exception.Message) -ForegroundColor Red
    throw
}
