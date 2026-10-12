# ============================================================
# opencode-update - installer
# Repo: https://github.com/canalqb/opencode-update
#
# One-liner (from any PowerShell window):
#   irm https://github.com/canalqb/opencode-update/releases/latest/download/install.ps1 | iex
#
# What it does:
#   1. Ensures Scoop is installed AND refreshed (scoop update: core + buckets)
#   2. Ensures opencode is installed AND on the latest version via Scoop
#   3. Installs opencode-update to %LOCALAPPDATA%\Programs\opencode-update
#   4. Configures opencode with the 26 recommended free NVIDIA models
#      (new config from template, or -ApplyModels to complete an existing one)
#   5. Adds the folder to your user PATH (command: opencode-update)
#
# Options (when saved to disk and run with -File):
#   -InstallDir <path>     custom install folder
#   -SkipScoop             skip Scoop/opencode setup, only deploy + models
#   -NoPath                do not modify the user PATH
#   -NvidiaApiKey <key>    API key for the NVIDIA integrate API
#                         (alternative: set the NVIDIA_API_KEY env var;
#                          on a fresh config the installer also prompts)
#   -ApplyModels           add the recommended models missing from an
#                          existing opencode.jsonc (backup is created first)
#   -Run                   run the updater immediately after install
#
# PRIVACY: no API key is stored in this repository. The key you provide
# is written only to your local opencode.jsonc. Get a free key at:
#   https://build.nvidia.com  (Sign in -> "Get API Key")
# ============================================================
[CmdletBinding()]
param(
    [string]$InstallDir = '',
    [string]$NvidiaApiKey = '',
    [switch]$SkipScoop,
    [switch]$NoPath,
    [switch]$ApplyModels,
    [switch]$Run
)

$ErrorActionPreference = 'Stop'

# GitHub release (latest) that hosts the script bundle
$ZipUrl = 'https://github.com/canalqb/opencode-update/releases/latest/download/opencode-update.zip'
$KeyPlaceholder = 'PASTE-YOUR-NVIDIA-API-KEY-HERE'

# The 26 recommended free models (NVIDIA integrate API) - keep in sync
# with models-template.jsonc (CI validates the consistency).
$Script:RecommendedModels = @(
    'z-ai/glm-5.3',
    'z-ai/glm5.1',
    'nvidia/llama-3.3-nemotron-super-49b-v1.5',
    'nvidia/llama-3.1-nemotron-ultra-253b-v1',
    'nvidia/nemotron-3-super-120b-a12b',
    'meta/llama-3.3-70b-instruct',
    'meta/llama-3.1-405b-instruct',
    'meta/llama-3.1-8b-instruct',
    'deepseek-ai/deepseek-v4-pro',
    'deepseek-ai/deepseek-v4-flash',
    'deepseek-ai/deepseek-r1',
    'moonshotai/kimi-k2-instruct',
    'moonshotai/kimi-k2-thinking',
    'moonshotai/kimi-k3',
    'qwen/qwen3-coder-480b-a35b-instruct',
    'qwen/qwen3-next-80b-a3b-instruct',
    'qwen/qwen3-next-80b-a3b-thinking',
    'qwen/qwen3-32b',
    'qwen/qwq-32b',
    'qwen/qwen2.5-coder-32b-instruct',
    'mistralai/mistral-large-3-675b-instruct-2512',
    'mistralai/codestral-22b-instruct-v0.1',
    'bytedance/seed-oss-36b-instruct',
    'nvidia/llama-3.1-nemotron-nano-8b-v1',
    'nvidia/nemotron-3-nano-30b-a3b',
    'nvidia/nemotron-3.5-lightning-30b-a3b'
)

function Write-Step {
    param([string]$Message)
    Write-Host ("==> {0}" -f $Message) -ForegroundColor Cyan
}

function Write-ConfigNoBom {
    param([string]$Path, [string]$Content)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function Resolve-ApiKey {
    param([string]$ProvidedKey)
    if ($ProvidedKey) { return $ProvidedKey }
    $envKey = [Environment]::GetEnvironmentVariable('NVIDIA_API_KEY')
    if ($envKey) { return $envKey }
    # prompt only makes sense for an interactive, fresh install
    try {
        $k = Read-Host 'Enter your NVIDIA API key (empty to configure later - get a free one at build.nvidia.com)'
        return $k
    } catch {
        return ''
    }
}

function Ensure-Scoop {
    $hadScoop = [bool](Get-Command scoop -ErrorAction SilentlyContinue)
    if (-not $hadScoop) {
        if ($SkipScoop) { throw 'Scoop not found and -SkipScoop was used.' }
        Write-Step 'Installing Scoop (Windows package manager)...'
        Invoke-RestMethod -Uri 'https://get.scoop.dev' | Invoke-Expression
        $shims = Join-Path $env:USERPROFILE 'scoop\shims'
        if ((Test-Path $shims) -and ($env:Path -notlike ('*' + $shims + '*'))) {
            $env:Path = $env:Path + ';' + $shims
        }
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
            throw 'Scoop installation did not finish. Open a NEW PowerShell window and run this installer again.'
        }
    } else {
        Write-Step 'Scoop: found.'
    }
    # always refresh Scoop itself and the buckets ("updated Scoop")
    Write-Step 'Scoop: refreshing core and buckets (scoop update)...'
    try {
        $out = (& scoop update 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0) {
            Write-Host '    Scoop self-update returned a warning; continuing.' -ForegroundColor Yellow
        } else {
            Write-Step 'Scoop: refreshed.'
        }
    } catch {
        Write-Host '    Scoop self-update failed; continuing.' -ForegroundColor Yellow
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
    if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
        Write-Step 'opencode: installing the latest version via Scoop...'
        & scoop install opencode
        if ($LASTEXITCODE -ne 0) {
            Write-Host '    Retrying after adding the main bucket...' -ForegroundColor Yellow
            & scoop bucket add main 2>$null
            & scoop install opencode
            if ($LASTEXITCODE -ne 0) { throw 'Failed to install opencode via Scoop.' }
        }
        return
    }
    # installed: make sure it is on the latest version
    if (@(Get-Process -Name opencode -ErrorAction SilentlyContinue).Count -gt 0) {
        Write-Step 'opencode: installed (running right now) - in-place refresh skipped.'
        Write-Host '    Close your opencode sessions and run "opencode-update" to refresh the version.' -ForegroundColor Yellow
        return
    }
    Write-Step 'opencode: installed - checking for a newer version...'
    $out = (& scoop update opencode 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        Write-Host '    Could not refresh opencode right now; the updater command handles it later.' -ForegroundColor Yellow
    } else {
        Write-Step 'opencode: latest version ensured.'
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

function Get-ModelBlockFromTemplate {
    # extracts the '"model-id": { ... }' block (brace-matched) from the template
    param([string]$TemplateText, [string]$ModelId)
    $marker = '"' + $ModelId + '"'
    $start = $TemplateText.IndexOf($marker)
    if ($start -lt 0) { return $null }
    $open = $TemplateText.IndexOf('{', $start)
    if ($open -lt 0) { return $null }
    $depth = 0
    $inStr = $false
    $i = $open
    while ($i -lt $TemplateText.Length) {
        $c = $TemplateText[$i]
        if ($c -eq '"') { $inStr = -not $inStr }
        if (-not $inStr) {
            if ($c -eq '{') { $depth++ }
            elseif ($c -eq '}') {
                $depth--
                if ($depth -eq 0) { break }
            }
        }
        $i++
    }
    return $TemplateText.Substring($start, $i - $start + 1)
}

function Convert-JsoncToObject {
    param([string]$Text)
    $noComments = ($Text -split "`r?`n") | Where-Object { $_ -notmatch '^\s*//' }
    (($noComments -join "`n").TrimStart([char]0xFEFF) | ConvertFrom-Json)
}

function Ensure-Models {
    param([string]$TemplatePath, [string]$ApiKey)

    $configDir  = Join-Path $env:USERPROFILE '.config\opencode'
    $configFile = Join-Path $configDir 'opencode.jsonc'
    $total = $Script:RecommendedModels.Count

    if (-not (Test-Path -LiteralPath $TemplatePath)) {
        Write-Host ("    Models template not found ({0}) - skipping models setup." -f $TemplatePath) -ForegroundColor Yellow
        return
    }
    $templateText = [System.IO.File]::ReadAllText($TemplatePath)
    $templateText = $templateText.TrimStart([char]0xFEFF)

    # --- fresh install: create the config from the template ------------------
    if (-not (Test-Path -LiteralPath $configFile)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        $content = $templateText
        $key = Resolve-ApiKey -ProvidedKey $ApiKey
        if ($key) {
            $content = $content.Replace($Script:KeyPlaceholder, $key)
            Write-Step ("opencode.jsonc: created with all {0} recommended models (key configured)." -f $total)
        } else {
            Write-Step ("opencode.jsonc: created with all {0} recommended models (API key placeholder kept)." -f $total)
            Write-Host '    Get a free key at https://build.nvidia.com and replace PASTE-YOUR-NVIDIA-API-KEY-HERE.' -ForegroundColor Yellow
        }
        Write-ConfigNoBom -Path $configFile -Content $content
        return
    }

    # --- existing config: verify / complete ----------------------------------
    $raw = [System.IO.File]::ReadAllText($configFile)
    $present = @($Script:RecommendedModels | Where-Object { $raw.Contains('"' + $_ + '"') })
    if ($present.Count -eq $total) {
        Write-Step ("Models: all {0} recommended models already configured." -f $total)
        return
    }

    $missing = @($Script:RecommendedModels | Where-Object { -not $raw.Contains('"' + $_ + '"') })
    Write-Step ("Models: {0}/{1} recommended present, {2} missing." -f $present.Count, $total, $missing.Count)
    Write-Host ("    Missing: {0}" -f ($missing -join ', ')) -ForegroundColor Yellow

    if (-not $ApplyModels) {
        Write-Host '    Run again with -ApplyModels to add them (a timestamped backup is created first).' -ForegroundColor Yellow
        return
    }

    # backup before touching anything
    $bak = '{0}.bak-{1}' -f $configFile, (Get-Date -Format 'yyyyMMdd_HHmmss')
    Copy-Item -LiteralPath $configFile -Destination $bak -Force
    Write-Host ("    Backup: {0}" -f $bak) -ForegroundColor Gray

    $nvIdx = $raw.IndexOf('"nvidia"')
    $canTextMerge = $false
    if ($nvIdx -ge 0) {
        $modelsIdx = $raw.IndexOf('"models"', $nvIdx)
        if ($modelsIdx -gt $nvIdx) { $canTextMerge = $true }
    }

    if ($canTextMerge) {
        # textual insert right after the "models": { opening brace - keeps all
        # existing comments and formatting untouched
        $openIdx = $raw.IndexOf('{', $modelsIdx)
        $blocks = @()
        foreach ($m in $missing) {
            $block = (Get-ModelBlockFromTemplate -TemplateText $templateText -ModelId $m) -replace "`r`n", "`n"
            if ($block) { $blocks += $block }
        }
        if ($blocks.Count -gt 0) {
            $insert = "`n" + ($blocks -join ",`n") + ","
            $new = $raw.Insert($openIdx + 1, $insert)
            Write-ConfigNoBom -Path $configFile -Content $new
            Write-Step ("Models: added {0} models (text merge, comments preserved)." -f $blocks.Count)
        }
        return
    }

    # fallback: no nvidia provider found - JSON round-trip merge
    Write-Host '    No "nvidia" provider block found - doing a full JSON merge (comments are reformatted).' -ForegroundColor Yellow
    $user = Convert-JsoncToObject -Text $raw
    $tpl  = Convert-JsoncToObject -Text $templateText
    if (-not $user.provider) {
        $user | Add-Member -MemberType NoteProperty -Name provider -Value ([pscustomobject]@{})
    }
    if (-not $user.provider.nvidia) {
        $user.provider | Add-Member -MemberType NoteProperty -Name nvidia -Value $tpl.provider.nvidia
    } else {
        foreach ($m in $missing) {
            $block = Get-ModelBlockFromTemplate -TemplateText $templateText -ModelId $m
            if ($block) {
                $obj = Convert-JsoncToObject -Text ('{' + $block + '}')
                $user.provider.nvidia.models | Add-Member -MemberType NoteProperty -Name $m -Value $obj.($m)
            }
        }
    }
    $merged = $user | ConvertTo-Json -Depth 32
    if ($ApiKey) { $merged = $merged.Replace($Script:KeyPlaceholder, $ApiKey) }
    Write-ConfigNoBom -Path $configFile -Content $merged
    Write-Step ("Models: merge complete ({0} added)." -f $missing.Count)
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

    # models template: prefer the one deployed next to this script
    $templateLocal = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'models-template.jsonc' } else { $null }
    $templateDeployed = Join-Path $InstallDir 'models-template.jsonc'
    $templatePath = $null
    if ($templateLocal -and (Test-Path -LiteralPath $templateLocal)) { $templatePath = $templateLocal }
    elseif (Test-Path -LiteralPath $templateDeployed) { $templatePath = $templateDeployed }
    Ensure-Models -TemplatePath $templatePath -ApiKey $NvidiaApiKey

    if (-not $NoPath) {
        Write-Step 'Adding the install folder to your user PATH...'
        Add-UserPath -Dir $InstallDir
    } else {
        Write-Step 'PATH not modified (-NoPath).'
    }

    Write-Host ''
    Write-Host '=== Installed successfully ===' -ForegroundColor Green
    Write-Host ''
    $ver = try { (& opencode --version 2>$null | Select-Object -First 1) } catch { 'unknown' }
    Write-Host ("opencode version : {0}" -f $ver)
    Write-Host ("Install folder   : {0}" -f $InstallDir)
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
