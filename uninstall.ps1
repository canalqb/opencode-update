# ============================================================
# opencode-update - uninstaller
# Removes the opencode-update tool only.
# Does NOT uninstall opencode or Scoop.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
#   powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -InstallDir "C:\custom\path"
# ============================================================
[CmdletBinding()]
param(
    [string]$InstallDir = ''
)

$ErrorActionPreference = 'Stop'

if (-not $InstallDir) {
    $InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\opencode-update'
}

Write-Host ''
Write-Host '=== opencode-update uninstaller ===' -ForegroundColor Cyan

if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force
    Write-Host ("Removed: {0}" -f $InstallDir) -ForegroundColor Green
} else {
    Write-Host 'Install folder not found (already removed?).' -ForegroundColor Yellow
}

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath) {
    $parts = $userPath -split ';' | Where-Object { $_ -and ($_.TrimEnd('\') -ne $InstallDir.TrimEnd('\')) }
    [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
    Write-Host 'PATH entry removed.' -ForegroundColor Green
}

Write-Host 'Done. opencode and Scoop were NOT uninstalled.' -ForegroundColor Cyan
