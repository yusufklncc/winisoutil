[CmdletBinding()]
param(
    [string]$SettingsPath,
    [string]$ToolsPinPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'modules\Automation.Common.psm1') -Force

if ([string]::IsNullOrWhiteSpace($SettingsPath)) { $SettingsPath = Join-Path $PSScriptRoot 'settings.json' }
if ([string]::IsNullOrWhiteSpace($ToolsPinPath)) { $ToolsPinPath = Join-Path $PSScriptRoot 'tools.pin.json' }

function Remove-OwnedToolsDirectory {
    param([Parameter(Mandatory)][string]$Path)

    $markerPath = Join-Path $Path '.winisoutil-uup-tools.json'
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        throw "Refusing to replace an unowned tools directory: $Path"
    }
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
}

function Assert-ToolsChildPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ToolsRoot
    )

    $resolvedRoot = [System.IO.Path]::GetFullPath($ToolsRoot).TrimEnd('\') + '\'
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $resolvedPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside the configured tools directory: $resolvedPath"
    }
}

$settingsFile = [System.IO.Path]::GetFullPath($SettingsPath)
$pinFile = [System.IO.Path]::GetFullPath($ToolsPinPath)
if (-not (Test-Path -LiteralPath $settingsFile -PathType Leaf)) {
    throw "Settings file not found: $settingsFile"
}
if (-not (Test-Path -LiteralPath $pinFile -PathType Leaf)) {
    throw "Tools pin file not found: $pinFile. Copy tools.pin.example.json, review the converter archive, and set its SHA-256."
}

$settingsDirectory = Split-Path -Parent $settingsFile
$settings = Get-Content -LiteralPath $settingsFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
$paths = Get-RequiredProperty -Object $settings -Name 'Paths'
$toolsRoot = Resolve-AutomationPath -Path ([string](Get-RequiredProperty -Object $paths -Name 'Tools')) -BaseDirectory $settingsDirectory
$pin = Get-Content -LiteralPath $pinFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
if ([int](Get-RequiredProperty -Object $pin -Name 'SchemaVersion') -ne 1) {
    throw "Unsupported tools pin schema version."
}
$archiveUri = [uri][string](Get-RequiredProperty -Object $pin -Name 'ArchiveUri')
$expectedSha256 = [string](Get-RequiredProperty -Object $pin -Name 'ArchiveSha256')
$commandRelativePath = [string](Get-RequiredProperty -Object $pin -Name 'CommandRelativePath')
if ($archiveUri.Scheme -ne 'https') {
    throw "Converter archive must use HTTPS: $archiveUri"
}
if ($expectedSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
    throw "ArchiveSha256 must contain the reviewed converter archive SHA-256."
}
if ([System.IO.Path]::IsPathRooted($commandRelativePath) -or $commandRelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
    throw "CommandRelativePath must remain inside the installed tools directory."
}

New-Item -ItemType Directory -Path $toolsRoot -Force -ErrorAction Stop | Out-Null
$installDirectory = Join-Path $toolsRoot 'uup-converter'
$stagingDirectory = Join-Path $toolsRoot ("uup-converter-install-$([guid]::NewGuid().ToString('N'))")
$archivePath = Join-Path $toolsRoot ("uup-converter-$([guid]::NewGuid().ToString('N')).zip")
Assert-ToolsChildPath -Path $installDirectory -ToolsRoot $toolsRoot
Assert-ToolsChildPath -Path $stagingDirectory -ToolsRoot $toolsRoot
Assert-ToolsChildPath -Path $archivePath -ToolsRoot $toolsRoot
try {
    Write-Host "Downloading reviewed converter archive: $archiveUri"
    Invoke-WebRequest -Uri $archiveUri -OutFile $archivePath -UseBasicParsing -ErrorAction Stop
    $actualSha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    if ($actualSha256 -ine $expectedSha256) {
        throw "Converter archive SHA-256 mismatch. Expected $expectedSha256, got $actualSha256."
    }

    New-Item -ItemType Directory -Path $stagingDirectory -Force -ErrorAction Stop | Out-Null
    Expand-Archive -LiteralPath $archivePath -DestinationPath $stagingDirectory -Force -ErrorAction Stop
    $commandPath = Join-Path $stagingDirectory $commandRelativePath
    if (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) {
        throw "Converter command was not found after extraction: $commandRelativePath"
    }
    if (-not (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $commandPath) 'ConvertConfig.ini') -PathType Leaf)) {
        throw "ConvertConfig.ini must be next to the configured converter command."
    }
    @{
        Type                = 'WinISOUtilUupTools'
        ArchiveUri          = $archiveUri.AbsoluteUri
        ArchiveSha256       = $expectedSha256.ToUpperInvariant()
        CommandRelativePath = $commandRelativePath
        InstalledAt         = (Get-Date).ToString('o')
    } | ConvertTo-Json | Out-File -LiteralPath (Join-Path $stagingDirectory '.winisoutil-uup-tools.json') -Encoding utf8 -Force

    if (Test-Path -LiteralPath $installDirectory) {
        Remove-OwnedToolsDirectory -Path $installDirectory
    }
    Move-Item -LiteralPath $stagingDirectory -Destination $installDirectory -ErrorAction Stop
    Write-Host "UUP converter installed: $installDirectory" -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $stagingDirectory) {
        Remove-Item -LiteralPath $stagingDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}
