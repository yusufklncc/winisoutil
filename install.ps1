# install.ps1 - Bootstrapper for the WinISOUtil project

# --- Configuration ---
$githubRepoUrl = "https://github.com/yusufklncc/winisoutil/archive/refs/heads/main.zip"
$tempDir = Join-Path $env:TEMP "winisoutil_setup"
$zipPath = Join-Path $tempDir "winisoutil.zip"

# --- Main Execution ---
try {
    # 1. Check for Administrator privileges
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        Write-Host "Administrator privileges are required. Please run PowerShell as an Administrator and try again." -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        exit 1
    }

    # 2. Create a clean temporary directory
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

    # 3. Download the entire project as a ZIP file
    Write-Host "Downloading WinISOUtil from GitHub..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $githubRepoUrl -OutFile $zipPath

    # 4. Extract the ZIP file
    Write-Host "Extracting files..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

    # 5. Find the extracted folder (GitHub adds a '-main' suffix)
    $extractedFolder = Get-ChildItem -Path $tempDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    if (-not $extractedFolder) {
        throw "Could not find the extracted project folder."
    }
    
    $scriptPath = Join-Path $extractedFolder.FullName "winisoutil.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "Main script 'winisoutil.ps1' not found in the extracted folder."
    }

    # 6. Navigate to the script's directory and execute the main script
    Write-Host "Starting WinISOUtil..." -ForegroundColor Green
    Set-Location -Path $extractedFolder.FullName
    
    # Execute the main script, passing along any extra arguments
    & $scriptPath @args

} catch {
    # Display any errors that occur
    Write-Host "An error occurred during installation: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Optional: You can keep the files for inspection or remove them.
    # To clean up automatically, uncomment the line below.
    # Remove-Item -Path $tempDir -Recurse -Force
    Write-Host "Bootstrapper finished."
}

Read-Host "Press Enter to close this window..."