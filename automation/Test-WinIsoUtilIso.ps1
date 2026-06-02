[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$IsoPath,
    [Parameter(Mandatory = $true)][string]$ConfigurationPath,
    [string]$ValidationReportPath,
    [string]$LogPath,
    [string]$WorkingDirectory = (Join-Path $env:TEMP ('WinISOUtil-Verify-{0}' -f [guid]::NewGuid().ToString('N')))
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run verifier-only mode from an elevated PowerShell session.'
}

$iso = [System.IO.Path]::GetFullPath($IsoPath)
$configurationFile = [System.IO.Path]::GetFullPath($ConfigurationPath)
if ([string]::IsNullOrWhiteSpace($ValidationReportPath)) {
    $ValidationReportPath = "$iso.validation.json"
}
$report = [System.IO.Path]::GetFullPath($ValidationReportPath)
if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = "$report.log"
}
$log = [System.IO.Path]::GetFullPath($LogPath)
$work = [System.IO.Path]::GetFullPath($WorkingDirectory)
$imageMount = Join-Path $work 'image'
$workspaceMarker = Join-Path $work '.winisoutil-verifier-workspace.json'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

Import-Module (Join-Path $PSScriptRoot 'modules\Profile.Validation.psm1') -Force
$configuration = Get-Content -LiteralPath $configurationFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
$mountedIso = $null
$imageMounted = $false
$marker = $null
$transcriptStarted = $false
try {
    Start-Transcript -LiteralPath $log -Force -ErrorAction Stop | Out-Null
    $transcriptStarted = $true
    if (Test-Path -LiteralPath $work) {
        if (@(Get-ChildItem -LiteralPath $work -Force -ErrorAction Stop).Count -gt 0) {
            throw "Verifier working directory must be empty: $work"
        }
    }
    New-Item -ItemType Directory -Path $imageMount -Force -ErrorAction Stop | Out-Null
    @{ Type = 'WinISOUtilVerifierWorkspace'; Root = $work } | ConvertTo-Json | Set-Content -LiteralPath $workspaceMarker -Encoding UTF8
    $mountedIso = Mount-DiskImage -ImagePath $iso -PassThru -ErrorAction Stop
    $volume = $mountedIso | Get-Volume -ErrorAction Stop
    $root = "$($volume.DriveLetter):\"
    $installImage = @('sources\install.wim', 'sources\install.esd') |
        ForEach-Object { Join-Path $root $_ } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace([string]$installImage)) {
        throw 'ISO does not contain install.wim or install.esd.'
    }

    & dism.exe /English /Mount-Image "/ImageFile:$installImage" /Index:1 "/MountDir:$imageMount" /ReadOnly
    if ($LASTEXITCODE -ne 0) { throw "DISM could not mount install image: $LASTEXITCODE" }
    $imageMounted = $true
    $validation = Invoke-WinIsoUtilProfileValidation -MountPath $imageMount -Configuration $configuration -RepositoryRoot $repositoryRoot -DismPath 'dism.exe'
    Write-WinIsoUtilValidationReport -Validation $validation -ConfigurationPath $configurationFile -IsoPath $iso -OutputPath $report | Out-Null
    if ($validation.OverallStatus -ne 'Passed') {
        $failedMessages = @($validation.FailedChecks | ForEach-Object { "$($_.Type)/$($_.Id): $($_.Message)" })
        throw "Offline profile validation failed: $($failedMessages -join '; ')"
    }
    Write-Host "Verifier-only validation passed: $report"
} catch {
    Write-Error $_
    throw
} finally {
    if ($imageMounted) {
        & dism.exe /English /Unmount-Image "/MountDir:$imageMount" /Discard | Out-Null
    }
    if ($null -ne $mountedIso) {
        Dismount-DiskImage -ImagePath $iso -ErrorAction SilentlyContinue | Out-Null
    }
    if (Test-Path -LiteralPath $workspaceMarker -PathType Leaf) {
        $marker = Get-Content -LiteralPath $workspaceMarker -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
    }
    if ($null -ne $marker -and [string]$marker.Type -eq 'WinISOUtilVerifierWorkspace' -and [System.IO.Path]::GetFullPath([string]$marker.Root) -eq $work) {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
}
