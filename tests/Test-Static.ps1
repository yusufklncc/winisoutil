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

$powerShellFiles = @(Get-ChildItem -LiteralPath $repoRoot -Filter '*.ps1' -File -Recurse)
foreach ($file in $powerShellFiles) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    Assert-True -Condition ($errors.Count -eq 0) -Message "PowerShell parser errors found in $($file.FullName)."
}

. (Join-Path $repoRoot 'src\tweaks.ps1')
. (Join-Path $repoRoot 'src\components.ps1')
. (Join-Path $repoRoot 'src\features.ps1')
. (Join-Path $repoRoot 'src\capabilities.ps1')
. (Join-Path $repoRoot 'src\removable-features.ps1')

$expectedDescriptionKeys = @(
    $allTweaks | ForEach-Object { "tweak_$($_.ID)_desc" }
    $allComponentTweaks | ForEach-Object { "comp_$($_.ID)_desc" }
    $allFeatures | ForEach-Object { "feature_$($_.FeatureName)_desc" }
    $allRemovableCapabilities | ForEach-Object { "capability_$($_.ID)_desc" }
    $allRemovableFeatures | ForEach-Object { "disabledFeature_$($_.FeatureName)_desc" }
)

foreach ($language in @('tr', 'en')) {
    $global:currentLanguage = $language
    . (Join-Path $repoRoot 'src\languages.ps1')

    foreach ($key in $expectedDescriptionKeys) {
        Assert-True -Condition $global:langStrings.ContainsKey($key) -Message "Missing $language description key: $key"
    }

    $orphanDescriptionKeys = @($global:langStrings.Keys | Where-Object {
        $_ -match '^(tweak_|comp_Disable|feature_|capability_|disabledFeature_).+_desc$' -and $_ -notin $expectedDescriptionKeys
    })
    Assert-True -Condition ($orphanDescriptionKeys.Count -eq 0) -Message "Orphan $language description keys: $($orphanDescriptionKeys -join ', ')"

    $offlineRunner = $global:langStrings.regRunnerBatBody -f 'post-setup.ps1', ''
    $networkRunner = $global:langStrings.regRunnerBatBody -f 'post-setup.ps1', $global:langStrings.regRunnerNetworkCheck
    Assert-True -Condition ($offlineRunner -notmatch 'msftconnecttest|ping google') -Message "$language offline BAT runner must not contain an internet gate."
    Assert-True -Condition ($networkRunner -match 'https://www\.msftconnecttest\.com/connecttest\.txt') -Message "$language network BAT runner must use the HTTPS connectivity gate."
}

foreach ($definition in @($allTweaks + $allComponentTweaks + $allFeatures + $allRemovableCapabilities + $allRemovableFeatures)) {
    foreach ($metadataField in @('Category', 'RiskLevel', 'ExecutionPhase', 'RequiresNetwork', 'AllowAbsent', 'Verification')) {
        Assert-True -Condition ($definition.PSObject.Properties.Name -contains $metadataField) -Message "Missing $metadataField metadata on definition: $($definition | Out-String)"
    }
}

$mainScript = Get-Content -LiteralPath (Join-Path $repoRoot 'winisoutil.ps1') -Raw
Assert-True -Condition ($mainScript -notmatch 'C:\\temp_iso|C:\\mount') -Message 'Legacy fixed workspace paths remain in winisoutil.ps1.'
Assert-True -Condition ($mainScript -notmatch 'ControlSet001|\\CurrentControlSet\\') -Message 'Hard-coded offline registry control set paths remain in winisoutil.ps1.'
Assert-True -Condition ($mainScript -match 'SchemaVersion\s*=\s*3') -Message 'WinISOUtil exports must use configuration schema version 3.'
Assert-True -Condition ($mainScript -match 'RemovedAppSelectors') -Message 'WinISOUtil must support stable provisioned app selectors.'
Assert-True -Condition ('Microsoft.Xbox.TCUI' -cmatch '^[A-Za-z0-9._~\-]+$') -Message 'ASCII selector validation must remain culture-independent.'
Assert-True -Condition ($mainScript -match 'if \(\$script:runMode -eq ''AUTOMATIC''\) \{ throw \}') -Message 'Automatic feature enable failures must stop the build.'

$profileModule = Get-Content -LiteralPath (Join-Path $repoRoot 'automation\modules\Profile.Validation.psm1') -Raw
Assert-True -Condition ($profileModule -match '\$selector -cnotmatch') -Message 'Provisioned app selector validation must use a case-sensitive ASCII allow-list.'

Write-Host 'Static checks passed.' -ForegroundColor Green
