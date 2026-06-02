[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

Import-Module (Join-Path $repoRoot 'automation\modules\Automation.Common.psm1') -Force
Import-Module (Join-Path $repoRoot 'automation\modules\UupDump.Provider.psm1')

$builds = [PSCustomObject]@{
    '0' = [PSCustomObject]@{
        title   = 'Windows 11, version 24H2 (26100.9999)'
        build   = '26100.9999'
        arch    = 'amd64'
        created = 700
        uuid    = 'dddddddd-0024-4453-a0ed-1e0b9f7793d3'
    }
    '1' = [PSCustomObject]@{
        title   = 'Windows 11, version 25H2 (26200.8524)'
        build   = '26200.8524'
        arch    = 'amd64'
        created = 300
        uuid    = 'b4d8466a-0024-4453-a0ed-1e0b9f7793d3'
    }
    '2' = [PSCustomObject]@{
        title   = 'Windows 11 Insider Preview 10.0.28000.1 (rs_prerelease)'
        build   = '28000.1'
        arch    = 'amd64'
        created = 400
        uuid    = 'aaaaaaaa-0024-4453-a0ed-1e0b9f7793d3'
    }
    '3' = [PSCustomObject]@{
        title   = '2026-05 Cumulative Update for Windows 11 Version 25H2'
        build   = '26200.9000'
        arch    = 'amd64'
        created = 500
        uuid    = 'bbbbbbbb-0024-4453-a0ed-1e0b9f7793d3'
    }
    '4' = [PSCustomObject]@{
        title   = 'Windows 11, version 25H2 (26200.8525)'
        build   = '26200.8525'
        arch    = 'arm64'
        created = 600
        uuid    = 'cccccccc-0024-4453-a0ed-1e0b9f7793d3'
    }
}
$candidates = @(Select-UupFeatureCandidates -Builds $builds -Architecture 'amd64')
Assert-True -Condition ($candidates.Count -eq 2) -Message 'UUP candidate filtering accepted a preview or KB record, or rejected a valid feature record.'
Assert-True -Condition ($candidates[0].Build -eq '26200.8524') -Message 'UUP candidate filtering selected the wrong Retail-shaped build.'

Assert-True -Condition (Test-AllowedPayloadUri -Uri ([uri]'http://tlu.dl.delivery.mp.microsoft.com/files/example')) -Message 'Expected Microsoft CDN host was rejected.'
Assert-True -Condition (Test-AllowedPayloadUri -Uri ([uri]'https://fe3cr.delivery.mp.microsoft.com/files/example')) -Message 'Expected Microsoft CDN HTTPS host was rejected.'
Assert-True -Condition (-not (Test-AllowedPayloadUri -Uri ([uri]'https://delivery.mp.microsoft.com.evil.example/files/example'))) -Message 'Payload allow-list accepted a suffix-confusion host.'
Assert-True -Condition (-not (Test-AllowedPayloadUri -Uri ([uri]'ftp://tlu.dl.delivery.mp.microsoft.com/files/example'))) -Message 'Payload allow-list accepted an unsupported scheme.'

$settings = Get-Content -LiteralPath (Join-Path $repoRoot 'automation\settings.example.json') -Raw | ConvertFrom-Json
Assert-True -Condition ([int]$settings.SchemaVersion -eq 2) -Message 'Automation settings example must use schema version 2.'
Assert-True -Condition (@($settings.Targets).Count -ge 2) -Message 'Automation settings example must demonstrate multiple locale targets.'
Assert-True -Condition ([string]$settings.Edition -ceq 'PROFESSIONAL') -Message 'Automation settings example must remain Professional-only.'
Assert-True -Condition ([string]$settings.Architecture -eq 'amd64') -Message 'Automation settings example must remain amd64-only.'
Assert-True -Condition ([string]$settings.InitialFeatureVersion -match '^\d{2}H[12]$') -Message 'Automation settings example must seed the initial feature hold state.'
Assert-True -Condition ([int]$settings.MinimumFreeSpaceGiB -ge 50) -Message 'Automation settings example must reserve enough free space for converter and WinISOUtil workspaces.'

$profile = Get-Content -LiteralPath (Join-Path $repoRoot 'automation\profile-v3.example.json') -Raw | ConvertFrom-Json
Assert-True -Condition ([int]$profile.SchemaVersion -eq 3) -Message 'Preferred profile example must use schema version 3.'
Assert-True -Condition ($profile.PSObject.Properties.Name -contains 'RemovedAppSelectors') -Message 'Profile example must contain stable app selectors.'
Assert-True -Condition ($profile.PSObject.Properties.Name -contains 'RemovedCapabilities') -Message 'Profile example must contain removable capabilities.'
Assert-True -Condition ($profile.PSObject.Properties.Name -contains 'DisabledFeatures') -Message 'Profile example must contain removable features.'
Assert-True -Condition ($profile.PSObject.Properties.Name -notcontains 'RemovedApps') -Message 'Profile example must not use version-specific app package names.'

$automationScript = Get-Content -LiteralPath (Join-Path $repoRoot 'automation\Invoke-AutomatedBuild.ps1') -Raw
Assert-True -Condition ($automationScript -notmatch 'Invoke-Expression|\biex\b') -Message 'Automation must not execute downloaded script text.'
Assert-True -Condition ($automationScript -match 'Global\\WinISOUtil-UUP-Automation') -Message 'Automation must use a global mutex.'
Assert-True -Condition ($automationScript -match 'FeatureReleaseHoldDays') -Message 'Automation must enforce the feature release hold policy.'
Assert-True -Condition ($automationScript -match 'Remove-OwnedTargetStaging') -Message 'Automation must use marker-protected staging cleanup.'
Assert-True -Condition ($automationScript -match 'Assert-FullBuildPrerequisites') -Message 'Automation must run full-build prerequisite checks before downloading payloads.'
Assert-True -Condition ($automationScript -match '\[AllowEmptyString\(\)\]\[string\]\$Message') -Message 'Automation logging must tolerate empty converter output lines.'
Assert-True -Condition ($automationScript -match "'W10UIuup'") -Message 'Automation must reject stale UUP converter temporary directories.'
Assert-True -Condition ($automationScript -match 'Invoke-LoggedProcess') -Message 'Automation must capture native process output without a direct native pipeline.'
Assert-True -Condition ($automationScript -match 'current-run\.json') -Message 'Automation must persist live run checkpoints.'
Assert-True -Condition ($automationScript -match 'Find-RecoverableStagedIso') -Message 'Automation must recover validated assembled source ISOs from preserved staging.'
Assert-True -Condition ($automationScript -match 'Get-CachedAssembledIso') -Message 'Automation must reuse a validated assembled source ISO after downstream failures.'
Assert-True -Condition ($automationScript -match 'Resolve-AutomationPath -Path \$ToolsPinPath') -Message 'Automation must resolve relative tools pin paths against the PowerShell working directory.'
Assert-True -Condition ($automationScript -match 'ServicePack Build') -Message 'Automation must validate the UUP revision using the DISM ServicePack Build field.'
Assert-True -Condition ($automationScript -match '\[string\[\]\]\$TargetId') -Message 'Automation must support target-scoped recovery and smoke runs.'
Assert-True -Condition ($automationScript -match 'exitcode\.log') -Message 'Automation must persist native process exit codes through a wrapper marker.'
Assert-True -Condition ($automationScript -match 'Windows11-Pro-\$\(\$target\.Locale\)-\$\(\$candidate\.FeatureVersion\)-\$\(\$candidate\.Build\)-by-WinISOUtil\.iso') -Message 'Automation outputs must use the by-WinISOUtil ISO name suffix.'
Assert-True -Condition ($automationScript -match 'Legacy output already exists') -Message 'Automation must avoid rebuilding when a legacy custom-suffixed ISO already exists.'
Assert-True -Condition ($automationScript -match 'ProfileSchemaVersion') -Message 'Automation manifest must include the profile schema version.'
Assert-True -Condition ($automationScript -match 'ValidationReportSha256') -Message 'Automation manifest must include the validation report SHA-256.'
Assert-True -Condition ($automationScript -match '\.validation\.json') -Message 'Automation must promote and retain validation report sidecars.'

$wrapper = Get-Content -LiteralPath (Join-Path $repoRoot 'automation\Invoke-MonthlyBuild.ps1') -Raw
Assert-True -Condition ($wrapper -match 'Invoke-AutomatedBuild\.ps1') -Message 'Deprecated monthly wrapper must delegate to the UUP automation entry point.'

Write-Host 'Automation fixture checks passed.' -ForegroundColor Green
