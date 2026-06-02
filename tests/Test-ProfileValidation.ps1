[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Throws {
    param([Parameter(Mandatory)][scriptblock]$ScriptBlock, [Parameter(Mandatory)][string]$Message)
    try {
        & $ScriptBlock
    } catch {
        return
    }
    throw $Message
}

Import-Module (Join-Path $repoRoot 'automation\modules\Profile.Validation.psm1') -Force
$definitions = Get-WinIsoUtilDefinitions $repoRoot

$blockMap = & (Get-Module Profile.Validation) {
    Get-WinIsoUtilDismBlockMap @('', 'Capability Identity : XPS.Viewer~~~~0.0.1.0', 'State : Installed', '') 'Capability Identity' 'State'
}
Assert-True ($blockMap['XPS.Viewer~~~~0.0.1.0'] -eq 'Installed') 'DISM block parser must tolerate empty output lines.'

$legacy = [PSCustomObject]@{
    SchemaVersion = 2
    RemovedAppSelectors = @()
    RegistryTweaks = @()
    EnabledFeatures = @()
    ComponentServiceTweaks = @('RemoveIE', 'RemoveWMP', 'DisableTelemetry')
}
$normalizedLegacy = ConvertTo-ValidatedWinIsoUtilConfiguration $legacy $repoRoot
Assert-True ($normalizedLegacy.DisabledFeatures -contains 'Internet-Explorer-Optional-amd64') 'Legacy RemoveIE must normalize to DisabledFeatures.'
Assert-True ($normalizedLegacy.DisabledFeatures -contains 'WindowsMediaPlayer') 'Legacy RemoveWMP must normalize to DisabledFeatures.'
Assert-True ($normalizedLegacy.ComponentServiceTweaks -contains 'DisableTelemetry') 'Service selections must survive legacy normalization.'
Assert-True ($normalizedLegacy.ComponentServiceTweaks -notcontains 'RemoveIE') 'Legacy feature IDs must not remain service tweaks.'

Assert-Throws {
    ConvertTo-ValidatedWinIsoUtilConfiguration ([PSCustomObject]@{ SchemaVersion = 3; RemovedCapabilities = @('Unknown~~~~0.0.1.0') }) $repoRoot
} 'Unknown capability must be rejected.'
Assert-Throws {
    ConvertTo-ValidatedWinIsoUtilConfiguration ([PSCustomObject]@{ SchemaVersion = 3; DisabledFeatures = @('UnknownFeature') }) $repoRoot
} 'Unknown removable feature must be rejected.'
Assert-Throws {
    ConvertTo-ValidatedWinIsoUtilConfiguration ([PSCustomObject]@{ SchemaVersion = 3; DisabledFeatures = @('NetFx3'); EnabledFeatures = @('NetFx3') }) $repoRoot
} 'Enable/disable conflict must be rejected.'

$configuration = ConvertTo-ValidatedWinIsoUtilConfiguration ([PSCustomObject]@{
    SchemaVersion = 3
    RemovedAppSelectors = @('Clipchamp.Clipchamp')
    RemovedCapabilities = @('XPS.Viewer~~~~0.0.1.0')
    DisabledFeatures = @('WorkFolders-Client')
    RegistryTweaks = @('WU_NotifyDownload', 'HideSearchIcon')
    EnabledFeatures = @('NetFx3')
    ComponentServiceTweaks = @('DisableTelemetry')
}) $repoRoot
$inventory = [PSCustomObject]@{
    ProvisionedApps = @()
    ProvisionedPackageNames = @()
    Capabilities = @{}
    Features = @{ NetFx3 = 'Enabled' }
    Services = @{ DiagTrack = [PSCustomObject]@{ Exists = $true; Start = 4 } }
    Registry = @{ 'SOFTWARE|Policies\Microsoft\Windows\WindowsUpdate\AU|AUOptions' = [PSCustomObject]@{ Exists = $true; Value = 2 } }
    Files = @('Windows\Setup\Scripts\post-setup.ps1', 'Users\Default\Desktop\Apply Custom Settings.bat')
}
$validation = Test-WinIsoUtilProfileState $configuration $definitions $inventory
Assert-True ($validation.OverallStatus -eq 'Passed') 'Expected fixture profile validation to pass.'
Assert-True (@($validation.NoOpChecks | Where-Object Type -eq 'Capability').Count -eq 1) 'Absent capability must be a no-op.'
Assert-True (@($validation.NoOpChecks | Where-Object Type -eq 'DisabledFeature').Count -eq 1) 'Absent removable feature must be a no-op.'
Assert-True (@($validation.NoOpChecks | Where-Object Type -eq 'Service').Count -eq 1) 'Absent service must be a no-op.'
Assert-True (@($validation.DeferredPostLoginChecks | Where-Object Id -eq 'HideSearchIcon').Count -eq 1) 'HideSearchIcon must be reported as deferred.'

$pendingInventory = $inventory.PSObject.Copy()
$pendingInventory.Features = @{ NetFx3 = 'Enable Pending' }
$pendingValidation = Test-WinIsoUtilProfileState $configuration $definitions $pendingInventory
Assert-True ($pendingValidation.OverallStatus -eq 'Passed') 'Offline Enable Pending feature state must satisfy the requested enabled desired state.'

$failedInventory = $inventory.PSObject.Copy()
$failedInventory.Features = @{ NetFx3 = 'Disabled' }
$failedValidation = Test-WinIsoUtilProfileState $configuration $definitions $failedInventory
Assert-True ($failedValidation.OverallStatus -eq 'Failed') 'Enabled feature mismatch must fail validation.'

$migrationDirectory = Join-Path $repoRoot 'tests\.tmp-profile-migration'
if (Test-Path -LiteralPath $migrationDirectory) { Remove-Item -LiteralPath $migrationDirectory -Recurse -Force }
try {
    New-Item -ItemType Directory -Path $migrationDirectory -Force | Out-Null
    $migrationPath = Join-Path $migrationDirectory 'desktop-v2.json'
    $legacy | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $migrationPath -Encoding UTF8
    & (Join-Path $repoRoot 'automation\Convert-WinIsoUtilProfile.ps1') -Path $migrationPath -InPlace
    $migrated = Get-Content -LiteralPath $migrationPath -Raw | ConvertFrom-Json
    Assert-True ([int]$migrated.SchemaVersion -eq 3) 'Migrated profile must use SchemaVersion 3.'
    Assert-True (@(Get-ChildItem -LiteralPath $migrationDirectory -Filter 'desktop-v2.backup-*.json').Count -eq 1) 'In-place migration must create one timestamped backup.'
} finally {
    if (Test-Path -LiteralPath $migrationDirectory) { Remove-Item -LiteralPath $migrationDirectory -Recurse -Force }
}

Write-Host 'Profile validation fixture checks passed.' -ForegroundColor Green
