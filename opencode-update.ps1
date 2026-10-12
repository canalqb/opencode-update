# ============================================================
# opencode-update - updates opencode (Windows) via Scoop
# Repo: https://github.com/canalqb/opencode-update
#
# What it does:
#   1. Aborts safely if opencode is running (unless -KillRunning)
#   2. Backs up your opencode config/models
#   3. Updates Scoop itself, then opencode to the latest release
#   4. Verifies your models survived; auto-restores the backup if not
#   5. Logs everything to opencode_update.log
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\opencode-update.ps1
#   powershell -ExecutionPolicy Bypass -File .\opencode-update.ps1 -Check
#   powershell -ExecutionPolicy Bypass -File .\opencode-update.ps1 -KillRunning
# ============================================================
[CmdletBinding()]
param(
    [switch]$KillRunning,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$Script:ConfigDir   = Join-Path $env:USERPROFILE '.config\opencode'
$Script:ConfigFile  = Join-Path $Script:ConfigDir 'opencode.jsonc'
$Script:AuthFile    = Join-Path $env:USERPROFILE '.local\share\opencode\auth.json'
$Script:ScriptRoot  = if ($PSScriptRoot) { $PSScriptRoot } else { $env:TEMP }
$Script:BackupRoot  = Join-Path $Script:ScriptRoot 'opencode_backups'
$Script:LogFile     = Join-Path $Script:ScriptRoot 'opencode_update.log'

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

function Get-RecommendedCount {
    if (-not (Test-Path -LiteralPath $Script:ConfigFile)) { return 0 }
    $raw = [System.IO.File]::ReadAllText($Script:ConfigFile)
    return @($Script:RecommendedModels | Where-Object { $raw.Contains('"' + $_ + '"') }).Count
}

function Write-Log {
    param([string]$Message, [string]$Color = 'Gray')
    $line = ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
    Write-Host $line -ForegroundColor $Color
    try { Add-Content -LiteralPath $Script:LogFile -Value $line -Encoding UTF8 } catch { }
}

function Get-OpenCodeVersion {
    try {
        $out = & opencode --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $out) { return [string]($out | Select-Object -First 1) }
    } catch { }
    return $null
}

function Get-ModelCount {
    # Counts model entries in opencode.jsonc (every model block has a "limit" key).
    if (-not (Test-Path -LiteralPath $Script:ConfigFile)) { return -1 }
    $raw = Get-Content -LiteralPath $Script:ConfigFile -Raw
    return ([regex]::Matches($raw, '"limit"\s*:')).Count
}

function Get-ConfigHash {
    if (-not (Test-Path -LiteralPath $Script:ConfigFile)) { return $null }
    return (Get-FileHash -LiteralPath $Script:ConfigFile -Algorithm SHA256).Hash
}

function Restore-ConfigBackup {
    param([string]$BackupFile)
    if (Test-Path -LiteralPath $BackupFile) {
        Copy-Item -LiteralPath $BackupFile -Destination $Script:ConfigFile -Force
        Write-Log "Config RESTORED from backup: $BackupFile" 'Yellow'
        return $true
    }
    Write-Log "Restore failed: backup file not found ($BackupFile)" 'Red'
    return $false
}

function Backup-Config {
    param([string]$Destination)
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Item -LiteralPath $Script:ConfigFile -Destination $Destination -Force
    if (Test-Path -LiteralPath $Script:AuthFile) {
        Copy-Item -LiteralPath $Script:AuthFile -Destination $Destination -Force
    }
    $jsonVariant = Join-Path $Script:ConfigDir 'opencode.json'
    if (Test-Path -LiteralPath $jsonVariant) {
        Copy-Item -LiteralPath $jsonVariant -Destination $Destination -Force
    }
}

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '=== opencode-update (Scoop) ===' -ForegroundColor Cyan
Write-Log 'Session started' 'Cyan'

# --- Check mode: report only, no changes -----------------------------------
if ($Check) {
    Write-Log 'CHECK MODE - report only, nothing will be changed' 'Cyan'
    $haveScoop = [bool](Get-Command scoop -ErrorAction SilentlyContinue)
    $v = Get-OpenCodeVersion
    $m = Get-ModelCount
    $n = @(Get-Process -Name opencode -ErrorAction SilentlyContinue).Count
    Write-Log ("scoop available    : {0}" -f $(if ($haveScoop) { 'yes' } else { 'no' }))
    Write-Log ("opencode installed : {0}" -f $(if ($v) { $v } else { 'no / not on PATH' }))
    Write-Log ("models configured  : {0}" -f $(if ($m -ge 0) { $m } else { 'no config file' }))
    Write-Log ("recommended models : {0}/{1}" -f (Get-RecommendedCount), $Script:RecommendedModels.Count)
    Write-Log ("opencode running   : {0} process(es)" -f $n)
    if (-not $haveScoop) {
        Write-Log 'RESULT: FAILED - scoop not found (run install.ps1 first)' 'Red'
        exit 1
    }
    Write-Log 'RESULT: SUCCESS - ready to update (run again without -Check)' 'Green'
    exit 0
}

$exitCode = 1

try {
    # --- Pre-flight ---------------------------------------------------------
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        throw 'scoop not found on PATH. Run install.ps1 first (see the repo README) or install Scoop.'
    }
    if (-not (Test-Path -LiteralPath $Script:ConfigFile)) {
        Write-Log 'No opencode.jsonc found (fresh install). Backup step will be skipped.' 'Yellow'
    }

    $running = @(Get-Process -Name opencode -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        if ($KillRunning) {
            Write-Log ("Found {0} running opencode process(es)." -f $running.Count) 'Yellow'
            $answer = Read-Host 'This will CLOSE all opencode sessions. Type YES to continue'
            if ($answer -cne 'YES') { throw 'Aborted by user: opencode is still running.' }
            Stop-Process -Name opencode -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            if (@(Get-Process -Name opencode -ErrorAction SilentlyContinue).Count -gt 0) {
                throw 'Could not close all opencode processes. Aborting.'
            }
        } else {
            throw 'opencode is currently running. Close all opencode sessions and run again, or use -KillRunning.'
        }
    }

    # --- Step 1: record state and back up models/config ---------------------
    $versionBefore = Get-OpenCodeVersion
    $hashBefore    = Get-ConfigHash
    $modelsBefore  = Get-ModelCount
    Write-Log ("Current version: {0}" -f $(if ($versionBefore) { $versionBefore } else { 'unknown' })) 'Cyan'
    Write-Log ("Models configured before update: {0}" -f $modelsBefore) 'Cyan'

    $haveBackup = $false
    $backupConfigFile = $null
    if (Test-Path -LiteralPath $Script:ConfigFile) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $backupDir = Join-Path $Script:BackupRoot $stamp
        Backup-Config -Destination $backupDir
        $backupConfigFile = Join-Path $backupDir 'opencode.jsonc'
        if (-not (Test-Path -LiteralPath $backupConfigFile)) {
            throw "Backup failed: $backupConfigFile was not created."
        }
        $info = @(
            "backup_time    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "opencode_before: $versionBefore",
            "models_before  : $modelsBefore",
            "config_sha256  : $hashBefore"
        ) -join [Environment]::NewLine
        Set-Content -LiteralPath (Join-Path $backupDir 'backup_info.txt') -Value $info -Encoding UTF8
        $haveBackup = $true
        Write-Log "STEP 1 OK - Backup saved to: $backupDir" 'Green'
    } else {
        Write-Log 'STEP 1 SKIPPED - no config file to back up' 'Yellow'
    }

    # --- Step 2: update Scoop itself (core + buckets) ------------------------
    Write-Log 'STEP 2 - Updating Scoop (core + buckets)...' 'Cyan'
    try {
        $scoopSelfOut = (& scoop update 2>&1 | Out-String)
        Write-Log 'Scoop self-update done.' 'DarkGray'
    } catch {
        Write-Log "Scoop self-update failed (continuing): $($_.Exception.Message)" 'Yellow'
    }

    # --- Step 3: update opencode via Scoop -----------------------------------
    Write-Log 'STEP 3 - Updating opencode via Scoop...' 'Cyan'
    $scoopOutput = (& scoop update opencode 2>&1 | Out-String)
    if ($scoopOutput) {
        foreach ($l in ($scoopOutput -split "`r?`n")) {
            if ($l.Trim()) { Write-Log ("  scoop: {0}" -f $l.Trim()) 'DarkGray' }
        }
    }
    if ($LASTEXITCODE -ne 0) {
        throw "scoop update failed with exit code $LASTEXITCODE."
    }
    Write-Log 'STEP 3 OK - Scoop update finished' 'Green'

    # --- Step 4: verify and integrate models --------------------------------
    Write-Log 'STEP 4 - Verifying model integration...' 'Cyan'
    $versionAfter = Get-OpenCodeVersion
    $hashAfter    = Get-ConfigHash
    $modelsAfter  = Get-ModelCount
    Write-Log ("Version after update: {0}" -f $(if ($versionAfter) { $versionAfter } else { 'unknown' }))

    if ($versionBefore -eq $versionAfter) {
        Write-Log 'Version unchanged (already the latest release).' 'Yellow'
    } else {
        Write-Log ("Version updated: {0} -> {1}" -f $versionBefore, $versionAfter) 'Green'
    }

    if ($haveBackup) {
        $configOk = $true
        if ($hashAfter -ne $hashBefore) {
            Write-Log 'Config file changed during update. Checking model count...' 'Yellow'
            if ($modelsAfter -lt $modelsBefore) {
                Write-Log ("Model count dropped ({0} -> {1}). Restoring backup..." -f $modelsBefore, $modelsAfter) 'Red'
                $configOk = Restore-ConfigBackup -BackupFile $backupConfigFile
            } else {
                Write-Log 'Config changed but no models were lost.' 'Yellow'
            }
        }
        if ($configOk) {
            $modelsFinal = Get-ModelCount
            Write-Log ("Models preserved: {0}/{1}. Custom (old) models remain and new catalog models load automatically." -f $modelsFinal, $modelsBefore) 'Green'
        }
        $recPresent = Get-RecommendedCount
        if ($recPresent -lt $Script:RecommendedModels.Count) {
            Write-Log ("Recommended models coverage: {0}/{1} - run install.ps1 -ApplyModels to complete the set." -f $recPresent, $Script:RecommendedModels.Count) 'Yellow'
        } else {
            Write-Log ("Recommended models coverage: {0}/{1}" -f $recPresent, $Script:RecommendedModels.Count) 'Green'
        }
    }

    Write-Log 'RESULT: SUCCESS' 'Green'
    $exitCode = 0
}
catch {
    Write-Log ("RESULT: FAILED - {0}" -f $_.Exception.Message) 'Red'
    if ($haveBackup) {
        Write-Log 'Your config/models were not modified (backup is safe).' 'Yellow'
    }
    $exitCode = 1
}
finally {
    Write-Host ''
    Write-Host '=== Done. Log: opencode_update.log | Backups: opencode_backups\ ===' -ForegroundColor Cyan
}

exit $exitCode
