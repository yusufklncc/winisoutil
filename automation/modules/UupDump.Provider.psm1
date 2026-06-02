Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'Automation.Common.psm1')

$script:ApiBaseUri = 'https://api.uupdump.net'
$script:RetryDelaysSeconds = @(5, 15, 45, 120)

function Assert-UupApiUri {
    param([Parameter(Mandatory)][uri]$Uri)

    if ($Uri.Scheme -ne 'https' -or $Uri.Host -ne 'api.uupdump.net') {
        throw "UUP API URL is outside the allow-list: $Uri"
    }
}

function Invoke-UupApiRequest {
    param(
        [Parameter(Mandatory)][uri]$Uri,
        [Parameter(Mandatory)][string]$CacheDirectory,
        [int]$CacheMinutes = 5,
        [switch]$ForceRefresh
    )

    Assert-UupApiUri -Uri $Uri
    New-Item -ItemType Directory -Path $CacheDirectory -Force -ErrorAction Stop | Out-Null
    $cachePath = Join-Path $CacheDirectory ("$((Get-StringSha256 -Value $Uri.AbsoluteUri)).json")
    if (-not $ForceRefresh -and (Test-Path -LiteralPath $cachePath -PathType Leaf)) {
        $cacheItem = Get-Item -LiteralPath $cachePath
        if ($cacheItem.LastWriteTimeUtc -gt [datetime]::UtcNow.AddMinutes(-$CacheMinutes)) {
            return Get-Content -LiteralPath $cachePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        }
    }

    $lastError = $null
    for ($attempt = 0; $attempt -le $script:RetryDelaysSeconds.Count; $attempt++) {
        try {
            $response = Invoke-RestMethod -Uri $Uri -Method Get -ErrorAction Stop
            if ($response.PSObject.Properties.Name -contains 'response' -and
                $null -ne $response.response -and
                $response.response.PSObject.Properties.Name -contains 'error') {
                throw "UUP API returned: $($response.response.error)"
            }
            Write-JsonAtomic -Value $response -Path $cachePath
            return $response
        } catch {
            $lastError = $_
            if ($attempt -ge $script:RetryDelaysSeconds.Count) {
                break
            }
            Start-Sleep -Seconds $script:RetryDelaysSeconds[$attempt]
        }
    }
    throw "UUP API request failed after retries: $Uri`n$($lastError.Exception.Message)"
}

function Select-UupFeatureCandidates {
    param(
        [Parameter(Mandatory)]$Builds,
        [Parameter(Mandatory)][string]$Architecture
    )

    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($property in $Builds.PSObject.Properties) {
        $build = $property.Value
        if ([string]$build.arch -ne $Architecture) { continue }
        $match = [regex]::Match([string]$build.title, '^Windows 11, version (?<feature>\d{2}H[12]) \((?<build>\d+\.\d+)\)$')
        if (-not $match.Success) { continue }
        if ([string]$build.uuid -notmatch '^[A-Fa-f0-9-]{36}$') { continue }
        $featureOrdinal = ([int]$match.Groups['feature'].Value.Substring(0, 2) * 2) +
            [int]$match.Groups['feature'].Value.Substring(3, 1)
        $result.Add([PSCustomObject]@{
            Title          = [string]$build.title
            FeatureVersion = $match.Groups['feature'].Value
            FeatureOrdinal = $featureOrdinal
            Build          = $match.Groups['build'].Value
            Created        = [long]$build.created
            Uuid           = [string]$build.uuid
            Architecture   = [string]$build.arch
        })
    }
    return @($result | Sort-Object @{ Expression = 'FeatureOrdinal'; Descending = $true }, @{ Expression = 'Created'; Descending = $true })
}

function Get-UupLanguages {
    param(
        [Parameter(Mandatory)][string]$Uuid,
        [Parameter(Mandatory)][string]$CacheDirectory,
        [switch]$ForceRefresh
    )

    $uri = [uri]"$script:ApiBaseUri/listlangs.php?id=$([uri]::EscapeDataString($Uuid))"
    return (Invoke-UupApiRequest -Uri $uri -CacheDirectory $CacheDirectory -ForceRefresh:$ForceRefresh).response
}

function Get-UupEditions {
    param(
        [Parameter(Mandatory)][string]$Uuid,
        [Parameter(Mandatory)][string]$Locale,
        [Parameter(Mandatory)][string]$CacheDirectory,
        [switch]$ForceRefresh
    )

    $uri = [uri]"$script:ApiBaseUri/listeditions.php?id=$([uri]::EscapeDataString($Uuid))&lang=$([uri]::EscapeDataString($Locale))"
    return (Invoke-UupApiRequest -Uri $uri -CacheDirectory $CacheDirectory -ForceRefresh:$ForceRefresh).response
}

function Get-UupManifest {
    param(
        [Parameter(Mandatory)][string]$Uuid,
        [Parameter(Mandatory)][string]$Locale,
        [Parameter(Mandatory)][string]$Edition,
        [Parameter(Mandatory)][string]$CacheDirectory,
        [switch]$ForceRefresh
    )

    $uri = [uri]"$script:ApiBaseUri/get.php?id=$([uri]::EscapeDataString($Uuid))&lang=$([uri]::EscapeDataString($Locale))&edition=$([uri]::EscapeDataString($Edition))"
    return (Invoke-UupApiRequest -Uri $uri -CacheDirectory $CacheDirectory -ForceRefresh:$ForceRefresh).response
}

function Get-LatestUupRetailCandidate {
    param(
        [Parameter(Mandatory)][string]$Architecture,
        [Parameter(Mandatory)][string]$CacheDirectory,
        [string]$FeatureVersion
    )

    $search = [uri]::EscapeDataString('Windows 11, version')
    $uri = [uri]"$script:ApiBaseUri/listid.php?sortByDate=1&search=$search"
    $list = Invoke-UupApiRequest -Uri $uri -CacheDirectory $CacheDirectory
    $candidates = @(Select-UupFeatureCandidates -Builds $list.response.builds -Architecture $Architecture)
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($FeatureVersion) -and $candidate.FeatureVersion -ne $FeatureVersion) {
            continue
        }
        $languageInfo = Get-UupLanguages -Uuid $candidate.Uuid -CacheDirectory $CacheDirectory
        $updateInfo = $languageInfo.updateInfo
        if ([string]$updateInfo.ring -cne 'RETAIL' -or
            [string]$updateInfo.flight -cne 'Active' -or
            [bool]$updateInfo.sha256ready -ne $true) {
            continue
        }
        return [PSCustomObject]@{
            Title          = $candidate.Title
            FeatureVersion = $candidate.FeatureVersion
            Build          = $candidate.Build
            Created        = $candidate.Created
            Uuid           = $candidate.Uuid
            Architecture   = $candidate.Architecture
            Languages      = @($languageInfo.langList)
            Ring           = [string]$updateInfo.ring
            Flight         = [string]$updateInfo.flight
            Sha256Ready    = [bool]$updateInfo.sha256ready
        }
    }
    throw "No eligible Windows 11 Retail UUP candidate was found."
}

Export-ModuleMember -Function @(
    'Invoke-UupApiRequest',
    'Select-UupFeatureCandidates',
    'Get-UupLanguages',
    'Get-UupEditions',
    'Get-UupManifest',
    'Get-LatestUupRetailCandidate'
)
