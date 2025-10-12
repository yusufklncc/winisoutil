# install.ps1 - Bootstrapper for the WinISOUtil project

# --- Self-Elevation ---
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    try {
        $scriptUrl = "https://raw.githubusercontent.com/yusufklncc/winisoutil/refs/heads/main/install.ps1"
        $powerShellCommand = "& {irm '$scriptUrl' | iex}"
        $arguments = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"$powerShellCommand`""
        
        Start-Process wt.exe -ArgumentList $arguments -Verb RunAs -ErrorAction Stop
        
        exit
    } catch {
        Write-Host "Elevation failed: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        exit 1
    }
}

# --- Configuration ---
$githubRepoUrl = "https://github.com/yusufklncc/winisoutil/archive/refs/heads/main.zip"
$tempDir = Join-Path $env:TEMP "winisoutil_setup"
$zipPath = Join-Path $tempDir "winisoutil.zip"

# --- Main Execution ---
try {
    Write-Host "Running with Administrator privileges." -ForegroundColor Green
    
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

    Write-Host "Downloading WinISOUtil from GitHub..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $githubRepoUrl -OutFile $zipPath

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
    Write-Host "Bootstrapper finished."
}

Read-Host "Press Enter to close this window..."

