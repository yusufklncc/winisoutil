[CmdletBinding()]
param(
    [string[]]$Locales = @('tr-tr', 'en-us', 'de-de'),
    [string]$CacheDirectory = (Join-Path $env:TEMP 'WinISOUtil-LiveApiTest')
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repoRoot 'automation\modules\UupDump.Provider.psm1') -Force

function Assert-Manifest {
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)][string]$Name
    )

    $files = @($Manifest.files.PSObject.Properties)
    if ($files.Count -eq 0) {
        throw "$Name manifest does not contain payload files."
    }
    foreach ($file in $files) {
        if ([string]$file.Value.sha256 -notmatch '^[A-Fa-f0-9]{64}$') {
            throw "$Name manifest contains a payload without SHA-256: $($file.Name)"
        }
    }
}

$candidate = Get-LatestUupRetailCandidate -Architecture 'amd64' -CacheDirectory $CacheDirectory
Write-Host "Candidate: $($candidate.Title) [$($candidate.Uuid)]"
foreach ($locale in $Locales) {
    if ($candidate.Languages -notcontains $locale) {
        throw "Locale is not available: $locale"
    }
    $editions = Get-UupEditions -Uuid $candidate.Uuid -Locale $locale -CacheDirectory $CacheDirectory
    if ($editions.editionList -notcontains 'PROFESSIONAL') {
        throw "PROFESSIONAL edition is not available for: $locale"
    }
    Assert-Manifest -Manifest (Get-UupManifest -Uuid $candidate.Uuid -Locale $locale -Edition 'PROFESSIONAL' -CacheDirectory $CacheDirectory) -Name "$locale PROFESSIONAL"
    Write-Host "Validated locale: $locale" -ForegroundColor Green
}
Assert-Manifest -Manifest (Get-UupManifest -Uuid $candidate.Uuid -Locale 'neutral' -Edition 'APP' -CacheDirectory $CacheDirectory) -Name 'neutral APP'
Write-Host 'Live UUP API smoke test passed.' -ForegroundColor Green
