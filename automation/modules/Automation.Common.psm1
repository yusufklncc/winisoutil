Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Net.Http

function Resolve-AutomationPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$BaseDirectory
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BaseDirectory $Path))
}

function Get-RequiredProperty {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    if ($Object.PSObject.Properties.Name -notcontains $Name -or $null -eq $Object.$Name) {
        throw "Required setting is missing: $Name"
    }
    return $Object.$Name
}

function Write-JsonAtomic {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Path,
        [int]$Depth = 12
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
    }
    $temporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        $Value | ConvertTo-Json -Depth $Depth | Out-File -LiteralPath $temporaryPath -Encoding utf8 -Force
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force -ErrorAction Stop
    } finally {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-StringSha256 {
    param([Parameter(Mandatory)][string]$Value)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return (($algorithm.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally {
        $algorithm.Dispose()
    }
}

function Assert-SafeIdentifier {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][string]$Name
    )

    if ($Value -notmatch '^[a-z0-9][a-z0-9._-]{0,63}$') {
        throw "$Name contains unsupported characters: $Value"
    }
}

function Test-AllowedPayloadUri {
    param([Parameter(Mandatory)][uri]$Uri)

    if ($Uri.Scheme -notin @('http', 'https')) {
        return $false
    }
    return $Uri.Host -match '(?i)(^|\.)delivery\.mp\.microsoft\.com$'
}

function Invoke-ResumablePayloadDownload {
    param(
        [Parameter(Mandatory)][uri]$Uri,
        [Parameter(Mandatory)][string]$DestinationPath,
        [Parameter(Mandatory)][long]$ExpectedSize,
        [Parameter(Mandatory)][string]$ExpectedSha256
    )

    if (-not (Test-AllowedPayloadUri -Uri $Uri)) {
        throw "Payload URL is outside the Microsoft CDN allow-list: $Uri"
    }
    if ($ExpectedSize -le 0 -or $ExpectedSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        throw "Payload metadata is incomplete for: $Uri"
    }

    $directory = Split-Path -Parent $DestinationPath
    New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
    $partialPath = "$DestinationPath.partial"
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [System.Net.Http.HttpClient]::new($handler)
    try {
        $currentUri = $Uri
        for ($redirectCount = 0; $redirectCount -le 5; $redirectCount++) {
            $existingLength = if (Test-Path -LiteralPath $partialPath -PathType Leaf) {
                (Get-Item -LiteralPath $partialPath).Length
            } else {
                0L
            }
            if ($existingLength -gt $ExpectedSize) {
                Remove-Item -LiteralPath $partialPath -Force -ErrorAction Stop
                $existingLength = 0L
            }

            $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $currentUri)
            if ($existingLength -gt 0) {
                $request.Headers.Range = [System.Net.Http.Headers.RangeHeaderValue]::new($existingLength, $null)
            }
            try {
                $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
            } finally {
                $request.Dispose()
            }

            try {
                if ([int]$response.StatusCode -in @(301, 302, 303, 307, 308)) {
                    if ($null -eq $response.Headers.Location) {
                        throw "Payload redirect does not include a Location header."
                    }
                    $currentUri = [uri]::new($currentUri, $response.Headers.Location)
                    if (-not (Test-AllowedPayloadUri -Uri $currentUri)) {
                        throw "Payload redirect is outside the Microsoft CDN allow-list: $currentUri"
                    }
                    continue
                }
                if (-not $response.IsSuccessStatusCode) {
                    throw "Payload download failed with HTTP $([int]$response.StatusCode): $currentUri"
                }

                $append = $existingLength -gt 0 -and [int]$response.StatusCode -eq 206
                if ($existingLength -gt 0 -and -not $append) {
                    Remove-Item -LiteralPath $partialPath -Force -ErrorAction Stop
                }
                $mode = if ($append) { [System.IO.FileMode]::Append } else { [System.IO.FileMode]::Create }
                $fileStream = [System.IO.File]::Open($partialPath, $mode, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                try {
                    $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                    try {
                        $stream.CopyTo($fileStream)
                    } finally {
                        $stream.Dispose()
                    }
                } finally {
                    $fileStream.Dispose()
                }
                break
            } finally {
                $response.Dispose()
            }
        }
    } finally {
        $client.Dispose()
        $handler.Dispose()
    }

    if (-not (Test-Path -LiteralPath $partialPath -PathType Leaf)) {
        throw "Payload download did not produce a file: $Uri"
    }
    $actualSize = (Get-Item -LiteralPath $partialPath).Length
    if ($actualSize -ne $ExpectedSize) {
        throw "Payload size mismatch. Expected $ExpectedSize, got $actualSize."
    }
    $actualSha256 = (Get-FileHash -LiteralPath $partialPath -Algorithm SHA256).Hash
    if ($actualSha256 -ine $ExpectedSha256) {
        throw "Payload SHA-256 mismatch. Expected $ExpectedSha256, got $actualSha256."
    }
    Move-Item -LiteralPath $partialPath -Destination $DestinationPath -Force -ErrorAction Stop
}

function Copy-OrLinkFile {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    $directory = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction Stop
    }
    try {
        New-Item -ItemType HardLink -Path $Destination -Target $Source -ErrorAction Stop | Out-Null
    } catch {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop
    }
}

Export-ModuleMember -Function @(
    'Resolve-AutomationPath',
    'Get-RequiredProperty',
    'Write-JsonAtomic',
    'Get-StringSha256',
    'Assert-SafeIdentifier',
    'Test-AllowedPayloadUri',
    'Invoke-ResumablePayloadDownload',
    'Copy-OrLinkFile'
)
