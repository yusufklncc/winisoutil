# install.ps1 - Bootstrapper for the WinISOUtil project

# --- Self-Elevation ---
# 1. Check for Administrator privileges.
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    # If not running as an admin, re-launch the script with admin rights.
    # This will trigger a UAC (User Account Control) prompt.
    try {
        $scriptUrl = "https://raw.githubusercontent.com/yusufklncc/winisoutil/refs/heads/main/install.ps1"
        $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& {irm '$scriptUrl' | iex}`""
        
        # Start the new process as Administrator ("RunAs").
        Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs -ErrorAction Stop
        
        # Exit the current, non-elevated script.
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
# The rest of the script runs in the new, elevated window.
try {
    Write-Host "Running with Administrator privileges." -ForegroundColor Green
    
    # 2. Create a clean temporary directory.
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

    # 3. Download the project as a ZIP file.
    Write-Host "Downloading WinISOUtil from GitHub..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $githubRepoUrl -OutFile $zipPath

    # 4. Extract the ZIP file.
    Write-Host "Extracting files..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

    # 5. Find the extracted folder (GitHub adds a '-main' suffix).
    $extractedFolder = Get-ChildItem -Path $tempDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    if (-not $extractedFolder) {
        throw "Could not find the extracted project folder."
    }
    
    $scriptPath = Join-Path $extractedFolder.FullName "winisoutil.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "Main script 'winisoutil.ps1' not found in the extracted folder."
    }

    # 6. Navigate to the script's directory and execute the main script.
    Write-Host "Starting WinISOUtil..." -ForegroundColor Green
    Set-Location -Path $extractedFolder.FullName
    
    # Execute the main script, passing along any extra arguments.
    & $scriptPath @args

} catch {
    # Display any errors that occur.
    Write-Host "An error occurred during installation: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Optional: Keep files for inspection or remove them.
    # To clean up automatically, uncomment the line below.
    # Remove-Item -Path $tempDir -Recurse -Force
    Write-Host "Bootstrapper finished."
}

Read-Host "Press Enter to close this window..."

