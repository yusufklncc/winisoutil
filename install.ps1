# install.ps1 - Bootstrapper for the WinISOUtil project

[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9._/-]+$')]
    [string]$Ref = 'main',
    [ValidatePattern('^[A-Fa-f0-9]{64}$')]
    [string]$ExpectedArchiveSha256
)

# --- Self-Elevation ---
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    try {
        $scriptPath = $MyInvocation.MyCommand.Path
        if ([string]::IsNullOrWhiteSpace($scriptPath)) {
            throw "Run install.ps1 from a local file before requesting elevation."
        }

        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"", '-Ref', "`"$Ref`"")
        if (-not [string]::IsNullOrWhiteSpace($ExpectedArchiveSha256)) {
            $arguments += @('-ExpectedArchiveSha256', $ExpectedArchiveSha256)
        }
        Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs -ErrorAction Stop
        
        exit
    } catch {
        Write-Host "Elevation failed: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        exit 1
    }
}

# --- Configuration ---
$githubRepoUrl = "https://github.com/yusufklncc/winisoutil/archive/$Ref.zip"
$tempDir = Join-Path $env:TEMP ("winisoutil_setup_{0}" -f [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $tempDir "winisoutil.zip"
$tempRoot = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
$resolvedTempDir = [System.IO.Path]::GetFullPath($tempDir)
if (-not $resolvedTempDir.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a bootstrap directory outside the system temp directory: $resolvedTempDir"
}

# --- Main Execution ---
try {
    Write-Host "Running with Administrator privileges." -ForegroundColor Green
    
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

    Write-Host "Downloading WinISOUtil from GitHub..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $githubRepoUrl -OutFile $zipPath

    if (-not [string]::IsNullOrWhiteSpace($ExpectedArchiveSha256)) {
        $actualArchiveSha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
        if ($actualArchiveSha256 -ine $ExpectedArchiveSha256) {
            throw "Downloaded archive SHA-256 does not match the expected value."
        }
        Write-Host "Archive SHA-256 verified." -ForegroundColor Green
    } else {
        Write-Host "WARNING: Archive SHA-256 was not provided. Use -ExpectedArchiveSha256 for reproducible installs." -ForegroundColor Yellow
    }

    Write-Host "Extracting files..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

    $extractedFolder = Get-ChildItem -Path $tempDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    if (-not $extractedFolder) {
        throw "Could not find the extracted project folder."
    }
    
    $scriptPath = Join-Path $extractedFolder.FullName "winisoutil.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "Main script 'winisoutil.ps1' not found in the extracted folder."
    }

    Write-Host "Starting WinISOUtil..." -ForegroundColor Green
    Set-Location -Path $extractedFolder.FullName
    
    & $scriptPath @args

} catch {
    Write-Host "An error occurred during installation: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if (Test-Path -LiteralPath $resolvedTempDir) {
        Remove-Item -LiteralPath $resolvedTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Bootstrapper finished."
}

Read-Host "Press Enter to close this window..."

