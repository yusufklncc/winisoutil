[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$DestinationPath,
    [switch]$InPlace
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($InPlace -and -not [string]::IsNullOrWhiteSpace($DestinationPath)) {
    throw 'Use either -InPlace or -DestinationPath, not both.'
}

$sourcePath = [System.IO.Path]::GetFullPath($Path)
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Profile not found: $sourcePath"
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $PSScriptRoot 'modules\Profile.Validation.psm1') -Force
$configuration = Get-Content -LiteralPath $sourcePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
$profile = ConvertTo-WinIsoUtilV3Profile -Configuration $configuration -RepositoryRoot $repositoryRoot

if ($InPlace) {
    $timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $backupPath = '{0}.backup-{1}{2}' -f [System.IO.Path]::Combine((Split-Path -Parent $sourcePath), [System.IO.Path]::GetFileNameWithoutExtension($sourcePath)), $timestamp, [System.IO.Path]::GetExtension($sourcePath)
    Copy-Item -LiteralPath $sourcePath -Destination $backupPath -ErrorAction Stop
    $outputPath = $sourcePath
} elseif (-not [string]::IsNullOrWhiteSpace($DestinationPath)) {
    $outputPath = [System.IO.Path]::GetFullPath($DestinationPath)
} else {
    $outputPath = Join-Path (Split-Path -Parent $sourcePath) ('{0}-v3{1}' -f [System.IO.Path]::GetFileNameWithoutExtension($sourcePath), [System.IO.Path]::GetExtension($sourcePath))
}

$parent = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    throw "Destination directory does not exist: $parent"
}
$temporaryPath = "$outputPath.tmp"
$profile | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
Move-Item -LiteralPath $temporaryPath -Destination $outputPath -Force

Write-Host "SchemaVersion 3 profile written: $outputPath"
if ($InPlace) {
    Write-Host "Backup written: $backupPath"
}
