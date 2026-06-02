[CmdletBinding()]
param(
    [string]$SettingsPath,
    [string]$ToolsPinPath,
    [switch]$DiscoverOnly
)

if ([string]::IsNullOrWhiteSpace($SettingsPath)) { $SettingsPath = Join-Path $PSScriptRoot 'settings.json' }
if ([string]::IsNullOrWhiteSpace($ToolsPinPath)) { $ToolsPinPath = Join-Path $PSScriptRoot 'tools.pin.json' }

Write-Warning 'Invoke-MonthlyBuild.ps1 is deprecated. Use Invoke-AutomatedBuild.ps1.'
& (Join-Path $PSScriptRoot 'Invoke-AutomatedBuild.ps1') `
    -SettingsPath $SettingsPath `
    -ToolsPinPath $ToolsPinPath `
    -DiscoverOnly:$DiscoverOnly
exit $LASTEXITCODE
