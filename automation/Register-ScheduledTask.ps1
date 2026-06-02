[CmdletBinding()]
param(
    [string]$SettingsPath,
    [string]$ToolsPinPath,
    [string]$TaskName = 'WinISOUtil Daily UUP Build',
    [ValidatePattern('^(?:[01]\d|2[0-3]):[0-5]\d$')]
    [string]$At = '04:00',
    [switch]$RunNow
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($SettingsPath)) { $SettingsPath = Join-Path $PSScriptRoot 'settings.json' }
if ([string]::IsNullOrWhiteSpace($ToolsPinPath)) { $ToolsPinPath = Join-Path $PSScriptRoot 'tools.pin.json' }

$isAdministrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
    IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdministrator) {
    throw 'Run this script from an elevated PowerShell window.'
}

$settingsFile = [System.IO.Path]::GetFullPath($SettingsPath)
$pinFile = [System.IO.Path]::GetFullPath($ToolsPinPath)
foreach ($file in @($settingsFile, $pinFile)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Required file not found: $file"
    }
}

$automationScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Invoke-AutomatedBuild.ps1'))
$powerShellPath = Join-Path $PSHOME 'powershell.exe'
$taskCommand = "`"$powerShellPath`" -NoProfile -ExecutionPolicy Bypass -File `"$automationScript`" -SettingsPath `"$settingsFile`" -ToolsPinPath `"$pinFile`""
$arguments = @(
    '/Create',
    '/TN', $TaskName,
    '/TR', $taskCommand,
    '/SC', 'DAILY',
    '/MO', '1',
    '/ST', $At,
    '/RU', 'SYSTEM',
    '/RL', 'HIGHEST',
    '/F'
)

& schtasks.exe @arguments
if ($LASTEXITCODE -ne 0) {
    throw "schtasks.exe failed with exit code $LASTEXITCODE."
}

Write-Host "Scheduled task registered: $TaskName" -ForegroundColor Green
Write-Host "Schedule: every day at $At local time" -ForegroundColor Green
Write-Host "Settings: $settingsFile" -ForegroundColor Green
Write-Host "Tools pin: $pinFile" -ForegroundColor Green

if ($RunNow) {
    & schtasks.exe /Run /TN $TaskName
    if ($LASTEXITCODE -ne 0) {
        throw "Could not start scheduled task. schtasks.exe exit code: $LASTEXITCODE"
    }
    Write-Host "Scheduled task started: $TaskName" -ForegroundColor Green
}
