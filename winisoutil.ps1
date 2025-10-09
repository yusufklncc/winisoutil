param(
    # Optional parameter to specify the ISO path directly when running the script.
    [string]$IsoPath = ""
)

# This trap block runs if a terminating error occurs anywhere in the script.
# It ensures a safe cleanup to prevent leaving a mounted image behind.
trap {
    # If the language file hasn't been loaded yet, $langStrings will be null.
    if ($null -ne $langStrings) {
        Write-ColorText $langStrings.trapErrorUnexpected $Red
        Write-ColorText "$($langStrings.trapErrorMessage) $($_.Exception.Message)" $Yellow
    } else {
        # This block uses hardcoded English text for errors that occur before the language file is loaded.
        Write-ColorText "An unexpected error occurred! Exiting safely..." -ForegroundColor Red
        Write-ColorText "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Cleanup
    exit 1
}

# --- GLOBAL VARIABLES AND COLORS ---
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Cyan = "Cyan"
$White = "White"

# A global configuration object to store user selections throughout the session.
$global:ScriptConfig = @{
    RemovedApps            = @()
    RegistryTweaks         = @()
    EnabledFeatures        = @()
    ComponentServiceTweaks = @()
}

# A script-level variable to determine the execution mode ('MANUAL' or 'AUTOMATIC').
$script:runMode = 'MANUAL' # Default mode.

# --- ALL FUNCTION DEFINITIONS ---

# Helper function to write text to the console in a specified color.
function Write-ColorText {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

# Clears the screen and displays the script's banner.
function Show-Banner {
    Clear-Host
    Write-ColorText "================================================================" $Cyan
    Write-ColorText "                   $($langStrings.bannerTitle)                  " $Cyan
    Write-ColorText "================================================================" $Cyan
    Write-Host ""
}

# Pauses the script and waits for a key press.
function Suspend-Script {
    param([string]$Message)
    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        Write-Host -NoNewline $Message
    } else {
        Write-Host -NoNewline $langStrings.pressAnyKey
    }
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Write-Host "" # Add a new line for better formatting.
}

# Displays a spinner animation for long-running operations executed as a background job.
function Invoke-LongRunningOperation {
    param(
        [ScriptBlock]$ScriptBlock,
        [string]$Message
    )

    $job = Start-Job -ScriptBlock $ScriptBlock
    $spinner = @('|', '/', '-', '\')
    $spinnerIndex = 0
    
    while ($job.State -eq 'Running') {
        Write-Host -NoNewline "`r$Message $($spinner[$spinnerIndex])"
        $spinnerIndex = ($spinnerIndex + 1) % $spinner.Length
        Start-Sleep -Milliseconds 100
    }

    # Clear the spinner line.
    Write-Host "`r$(' ' * ($Message.Length + 5))`r"

    if ($job.State -eq 'Failed') {
        $errorMsg = $job.ChildJobs[0].Error
        throw ($langStrings.longOpFailed -f $errorMsg)
    }
}

# A generic function to display a menu and get user input (single or multiple choice).
function Get-UserChoice {
    param(
        [string]$Title,
        [string[]]$Options,
        [bool]$MultiSelect = $false,
        [string]$GoBackOption = $langStrings.goBack
    )
    
    Write-ColorText "`n$Title" $Yellow
    Write-ColorText ("=" * $Title.Length) $Yellow
    
    for ($i = 0; $i -lt $Options.Length; $i++) {
        Write-Host "[$($i + 1)] $($Options[$i])"
    }
    Write-ColorText "[g] $GoBackOption" $Red

    if ($MultiSelect) {
        Write-ColorText "`n$($langStrings.getUserChoiceMultiSelect)" $Green
        $selection = Read-Host $langStrings.promptChoice
        
        if ($selection -ieq 'g') { return 'go_back' }
        if ($selection -ieq "tumu" -or $selection -ieq "all") { return @(1..$Options.Length) }
        
        try {
            # Parse comma-separated numbers into an integer array.
            return $selection.Split(',').Trim() | ForEach-Object { [int]$_ }
        } catch {
            Write-ColorText $langStrings.invalidChoice $Red
            return @()
        }
    } else {
        $selection = Read-Host ($langStrings.getUserChoiceSingleSelect -f $Options.Length)
        if ($selection -ieq 'g') { return 'go_back' }
        try {
            return [int]$selection
        } catch {
            Write-ColorText $langStrings.invalidChoice $Red
            return 0
        }
    }
}

# Finds the required tool for creating an ISO (oscdimg.exe or mkisofs.exe).
# If not found, it attempts to download mkisofs.
function Get-IsoTool {
    $adkPaths = @(
        "C:\Program Files (x86)\Windows Kits\11\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg",
        "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
    )
    foreach ($path in $adkPaths) {
        $oscdimgPath = Join-Path $path "oscdimg.exe"
        if (Test-Path $oscdimgPath) {
            Write-ColorText $langStrings.isoToolOscdimgFound $Green
            return @{ Tool = 'oscdimg'; Path = $oscdimgPath }
        }
    }

    Write-ColorText $langStrings.isoToolMkisofsNotFound $Yellow
    $toolsDir = Join-Path $env:TEMP "WinIsoTools"
    $mkisofsPath = Join-Path $toolsDir "mkisofs.exe"

    if (Test-Path $mkisofsPath) {
        Write-ColorText $langStrings.isoToolMkisofsExists $Green
        return @{ Tool = 'mkisofs'; Path = $mkisofsPath }
    }

    try {
        New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
        $repoUrl = "https://raw.githubusercontent.com/yusufklncc/winisoutil/main/tools"
        
        Write-ColorText $langStrings.isoToolDownloadingMkisofs $Cyan
        Invoke-WebRequest -Uri "$repoUrl/mkisofs.exe" -OutFile $mkisofsPath
        
        Write-ColorText $langStrings.isoToolDownloadingCygwin $Cyan
        Invoke-WebRequest -Uri "$repoUrl/cygwin1.dll" -OutFile (Join-Path $toolsDir "cygwin1.dll")

        if (Test-Path $mkisofsPath) {
            Write-ColorText $langStrings.isoToolDownloadSuccess $Green
            return @{ Tool = 'mkisofs'; Path = $mkisofsPath }
        } else {
            throw $langStrings.isoToolDownloadFail
        }
    } catch {
        Write-ColorText ($langStrings.isoToolDownloadError -f $_) $Red
        Write-ColorText $langStrings.isoToolDownloadHelp $Yellow
        return $null
    }
}

# Asks the user if they want to import settings from a .json file to run in automatic mode.
function Import-Configuration {
    Show-Banner
    Write-ColorText $langStrings.importTitle $Yellow
    Write-ColorText $langStrings.importDesc $Cyan
    $choice = Read-Host $langStrings.importPrompt
    
    if ($choice -ieq 'E' -or $choice -ieq 'Y') {
        Add-Type -AssemblyName System.Windows.Forms
        $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $OpenFileDialog.Title = $langStrings.importFileSelectTitle
        $OpenFileDialog.Filter = "JSON files (*.json)|*.json"
        $OpenFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

        if ($OpenFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $configPath = $OpenFileDialog.FileName
            try {
                Write-ColorText ($langStrings.importReadingFile -f $configPath) $Green
                $configContent = Get-Content -Path $configPath -Raw | ConvertFrom-Json
                
                # Safely populate the global config from the JSON file.
                if ($configContent.PSObject.Properties.Name -contains 'RemovedApps') { $global:ScriptConfig.RemovedApps = $configContent.RemovedApps }
                if ($configContent.PSObject.Properties.Name -contains 'RegistryTweaks') { $global:ScriptConfig.RegistryTweaks = $configContent.RegistryTweaks }
                if ($configContent.PSObject.Properties.Name -contains 'EnabledFeatures') { $global:ScriptConfig.EnabledFeatures = $configContent.EnabledFeatures }
                if ($configContent.PSObject.Properties.Name -contains 'ComponentServiceTweaks') { $global:ScriptConfig.ComponentServiceTweaks = $configContent.ComponentServiceTweaks }

                Write-ColorText $langStrings.importSuccess $Green
                Start-Sleep -Seconds 2
                return $true # Return true to signal automatic mode.
            } catch {
                Write-ColorText ($langStrings.importReadError -f $_) $Red
                if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
                return $false
            }
        } else {
            Write-ColorText $langStrings.importFileNotSelected $Yellow
            if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
            return $false
        }
    } else {
        Write-ColorText $langStrings.importManualContinue $Yellow
        if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
        return $false
    }
}

# Exports the current user selections to a .json file.
function Export-Configuration {
    Show-Banner
    Write-ColorText $langStrings.exportTitle $Yellow

    Add-Type -AssemblyName System.Windows.Forms
    $SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $SaveFileDialog.Title = $langStrings.exportFileSaveTitle
    $SaveFileDialog.Filter = "JSON files (*.json)|*.json"
    $SaveFileDialog.DefaultExt = "json"
    $SaveFileDialog.FileName = $langStrings.exportFileName
    $SaveFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

    if ($SaveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $exportPath = $SaveFileDialog.FileName
        try {
            # Create an object with all current settings to be saved.
            $exportObject = @{
                Description            = $langStrings.exportConfigDesc
                DateCreated            = (Get-Date).ToString("yyyy-MM-dd")
                RemovedApps            = $global:ScriptConfig.RemovedApps
                RegistryTweaks         = $global:ScriptConfig.RegistryTweaks
                EnabledFeatures        = $global:ScriptConfig.EnabledFeatures
                ComponentServiceTweaks = $global:ScriptConfig.ComponentServiceTweaks
            }

            $exportObject | ConvertTo-Json -Depth 5 | Out-File -FilePath $exportPath -Encoding utf8
            Write-ColorText ($langStrings.exportSuccess -f $exportPath) $Green
        } catch {
            Write-ColorText ($langStrings.exportError -f $_) $Red
        }
    } else {
        Write-ColorText $langStrings.exportCanceled $Yellow
    }
    if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
}

# Creates a clean working environment by deleting and recreating temp folders.
function Initialize-Environment {
    Write-ColorText $langStrings.initEnvPreparing $Green
    try {
        if (Test-Path "C:\temp_iso") { Remove-Item "C:\temp_iso" -Recurse -Force }
        if (Test-Path "C:\mount") { Remove-Item "C:\mount" -Recurse -Force }
        New-Item -ItemType Directory -Path "C:\temp_iso" -Force | Out-Null
        New-Item -ItemType Directory -Path "C:\mount" -Force | Out-Null
        Write-ColorText $langStrings.initEnvSuccess $Green
    } catch {
        Write-ColorText ($langStrings.initEnvError -f $_) $Red
        throw $langStrings.initEnvFail
    }
}

# Mounts the source ISO and copies its contents to a temporary folder.
function Copy-IsoFiles {
    param([string]$IsoPath)
    Write-ColorText $langStrings.copyIsoCopying $Green
    $mountResult = $null
    try {
        $mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru
        $driveLetter = ($mountResult | Get-Volume).DriveLetter
        Copy-Item -Path "$($driveLetter):\*" -Destination "C:\temp_iso\" -Recurse -Force
        
        # The install.wim file must be writable.
        Write-ColorText $langStrings.copyIsoUnlockingWim $Yellow
        Set-ItemProperty -Path "C:\temp_iso\sources\install.wim" -Name IsReadOnly -Value $false
        Write-ColorText $langStrings.copyIsoSuccess $Green
    } catch {
        Write-ColorText ($langStrings.copyIsoError -f $_) $Red
        throw $langStrings.copyIsoFail
    } finally {
        # Always ensure the ISO is dismounted.
        if ($mountResult) { Dismount-DiskImage -ImagePath $IsoPath }
    }
}

# Finds the path to dism.exe, prioritizing the one from Windows ADK.
function Find-DismPath {
    $dismPaths = @(
        "C:\Program Files (x86)\Windows Kits\11\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe",
        "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe",
        "C:\Windows\System32\dism.exe",
        "C:\Windows\SysWOW64\dism.exe"
    )
    foreach ($path in $dismPaths) {
        if (Test-Path $path) {
            Write-ColorText ($langStrings.dismFound -f $path) $Green
            return $path
        }
    }
    try {
        # As a fallback, check if DISM is in the system's PATH.
        $dismInPath = Get-Command "dism.exe" -ErrorAction SilentlyContinue
        if ($dismInPath) {
            Write-ColorText ($langStrings.dismFoundInPath -f $dismInPath.Source) $Green
            return $dismInPath.Source
        }
    } catch {}
    Write-ColorText $langStrings.dismNotFoundWarning $Red
    return $null
}

# Allows the user to remove unwanted Windows editions from the install.wim file.
function Remove-WindowsEditions {
    $wimFile = "C:\temp_iso\sources\install.wim"
    do {
        Clear-Host
        Show-Banner
        Write-ColorText $langStrings.removeEditionsAnalyzing $Green
		
        $wimInfo = & $global:dismPath /Get-WimInfo /WimFile:$wimFile
        $editions = $wimInfo | Select-String "Index|Name"
        Write-ColorText $langStrings.removeEditionsCurrent $Yellow
        $editions | ForEach-Object { Write-Host $_.Line }
        $indexCount = ($editions | Where-Object { $_.Line -match "Name" }).Count
		
        # If only one edition is left, no more can be removed.
		if ($indexCount -le 1) {	
            Write-ColorText $langStrings.removeEditionsOnlyOne $Yellow
            Start-Sleep -Seconds 3
            break	
        }

        Write-ColorText "`n$($langStrings.removeEditionsGoBack)" $Cyan
        $choice = Read-Host $langStrings.removeEditionsPrompt

        if ($choice -ieq 'g') { break }

        try {
            # Sort descending to avoid index shifting issues during deletion.
            $indicesToDelete = $choice.Split(',') | ForEach-Object { [int]$_.Trim() } | Sort-Object -Descending
            
            $validInput = $true
            foreach($index in $indicesToDelete) {
                if ($index -lt 1 -or $index -gt $indexCount) {
                    Write-ColorText ($langStrings.removeEditionsInvalidIndex -f $index, $indexCount) $Red
                    $validInput = $false
                    break
                }
            }

            if (-not $validInput) {
                Start-Sleep -Seconds 3
                continue
            }

            foreach ($index in $indicesToDelete) {
                Write-ColorText ($langStrings.removeEditionsRemoving -f $index) $Yellow
                try {
                    & $global:dismPath /Delete-Image /ImageFile:$wimFile /Index:$index /CheckIntegrity
                    Write-ColorText ($langStrings.removeEditionsSuccess -f $index) $Green
                    Start-Sleep -Seconds 1
                } catch {
                    Write-ColorText ($langStrings.removeEditionsError -f $index, $_) $Red
                    Start-Sleep -Seconds 3
                }
            }
            Write-ColorText $langStrings.removeEditionsListUpdated $Green
            Start-Sleep -Seconds 2

        } catch {
            Write-ColorText $langStrings.removeEditionsInvalidInput $Red
            Start-Sleep -Seconds 3
        }
    } while ($true)
}

# Mounts the selected Windows image edition to the C:\mount directory.
function Mount-WindowsImage {
    Clear-Host
    Show-Banner

    $wimFile = "C:\temp_iso\sources\install.wim"
    Write-ColorText $langStrings.mountListingEditions $Green
    $wimInfo = & $global:dismPath /Get-WimInfo /WimFile:$wimFile
	$editions = $wimInfo | Select-String "Index|Name"
	Write-ColorText $langStrings.removeEditionsCurrent $Yellow
    $editions | ForEach-Object { Write-Host $_.Line }
    $indexCount = ($editions | Where-Object { $_.Line -match "Name" }).Count

    # If only one edition exists, mount it automatically.
	if ($indexCount -eq 1) {
		Write-ColorText "`n$($langStrings.mountMountingImage)" $Yellow
		try {
            & $global:dismPath /Mount-Image /ImageFile:$wimFile /Index:1 /MountDir:"C:\mount"
			if ($LASTEXITCODE -ne 0) { throw $langStrings.mountFail }
            Write-ColorText $langStrings.mountSuccess $Green
			Start-Sleep -Seconds 3
            return $true
        } catch {
            Write-ColorText ($langStrings.mountError -f $_) $Red
            throw $langStrings.mountFail
        }
	} else {
        # If multiple editions exist, prompt the user for a selection.
		$choice = Read-Host $langStrings.mountPromptIndex
		if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $indexCount) {
			Write-ColorText $langStrings.mountMountingImage $Yellow
			try {
				& $global:dismPath /Mount-Image /ImageFile:$wimFile /Index:$choice /MountDir:"C:\mount"
				if ($LASTEXITCODE -ne 0) { throw $langStrings.mountFail }
				Write-ColorText $langStrings.mountSuccess $Green
				Start-Sleep -Seconds 3
				return $true
			} catch {
				Write-ColorText ($langStrings.mountError -f $_) $Red
				throw $langStrings.mountFail
			}	
		} else {
			Write-ColorText $langStrings.mountInvalidIndex $Red
			return $false
		}
	}
}

# Adds Windows Update packages (.msu) from a user-selected folder.
function Add-WindowsUpdates {
    Clear-Host
    Show-Banner
    
    # Create and show a folder browser dialog.
    Add-Type -AssemblyName System.Windows.Forms
    $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowserDialog.Description = $langStrings.updatesPromptPath
    
    $updatesPath = ""
    if ($FolderBrowserDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $updatesPath = $FolderBrowserDialog.SelectedPath
    } else {
        # Return to the menu if the user cancels the dialog.
        return
    }

    if (Test-Path $updatesPath) {
        $updateFiles = Get-ChildItem -Path $updatesPath -Filter "*.msu" -ErrorAction Silentlycontinue
        if ($updateFiles) {
            Write-ColorText $langStrings.updatesAdding $Green
            foreach ($file in $updateFiles) {
                Write-ColorText ($langStrings.updatesAddingFile -f $file.Name) $Yellow
                try {
                    & $global:dismPath /Image:"C:\mount" /Add-Package /PackagePath:"$($file.FullName)" /LogPath=C:\mount\dism.log
                    Write-ColorText ($langStrings.updatesAddedFile -f $file.Name) $Green
                } catch {
                    Write-ColorText ($langStrings.updatesErrorFile -f $file.Name, $_) $Red
                }
            }
        } else {
            Write-ColorText $langStrings.updatesMsuNotFound $Red
        }
    } else {
        # This part should theoretically not be reached as the dialog ensures a valid path.
        Write-ColorText $langStrings.updatesInvalidPath $Red
    }
    if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
}

# Adds drivers (.inf) from a user-selected folder and its subdirectories.
function Add-Drivers {
	Clear-Host
	Show-Banner

    # Create and show a folder browser dialog.
    Add-Type -AssemblyName System.Windows.Forms
    $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowserDialog.Description = $langStrings.driversPromptPath
    
    $driversPath = ""
    if ($FolderBrowserDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $driversPath = $FolderBrowserDialog.SelectedPath
    } else {
        # Return to the menu if the user cancels the dialog.
        return
    }

    if (Test-Path $driversPath) {
        Write-ColorText $langStrings.driversAdding $Yellow
        try {
            # The /Recurse switch tells DISM to look for drivers in all subfolders.
            & $global:dismPath /Image:C:\mount /Add-Driver /Driver:"$driversPath" /Recurse
            Write-ColorText $langStrings.driversSuccess $Green
        } catch {
            Write-ColorText ($langStrings.driversError -f $_) $Red
        }
    } else {
        Write-ColorText $langStrings.updatesInvalidPath $Red
    }
    if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
}

# Allows removing Windows components and disabling services based on definitions in an external file.
function Set-ComponentsAndServices {
    # Load tweak definitions from the external file.
    try {
        . (Join-Path $PSScriptRoot "src/components.ps1")
    } catch {
        Write-ColorText $langStrings.compSvcTweakDefNotFound $Red
        Suspend-Script
        return
    }
    
    # Dynamically determine the description property based on the current language.
    $descProperty = "Description_" + $global:currentLanguage
    if ($allComponentTweaks -and -not ($allComponentTweaks[0].PSObject.Properties.Name -contains $descProperty)) {
        $descProperty = "Description_en" # Fallback to English if the language is not found.
    }

    $tweaksToApply = [System.Collections.Generic.List[object]]::new()
    $runInManualMode = $script:runMode -eq 'MANUAL'

    if (-not $runInManualMode) { # Automatic Mode
        if ($global:ScriptConfig.ComponentServiceTweaks.Count -gt 0) {
            Write-ColorText $langStrings.compSvcApplyingFromConfig $Cyan
            $selectedTweakIDs = $global:ScriptConfig.ComponentServiceTweaks
            $tweaksToApply.AddRange(($allComponentTweaks | Where-Object { $selectedTweakIDs -contains $_.ID }))
        }
    } 
    else { # Manual Mode
        Clear-Host
        Show-Banner

        $menuOptions = ($allComponentTweaks | ForEach-Object { $_.$descProperty }) + $langStrings.compSvcApplyAll
        $selection = Get-UserChoice -Title $langStrings.compSvcTitle -Options $menuOptions -MultiSelect $true
        
        if ($selection -eq 'go_back') { return }

        if ($selection -is [Array] -and $selection.Count -eq 0) {
            Write-ColorText $langStrings.compSvcNothingSelected $Yellow
            Start-Sleep -Seconds 2
            return
        }

        if ($selection -contains $menuOptions.Length) {
            $tweaksToApply.AddRange($allComponentTweaks)
        } else {
            $selection | ForEach-Object { $tweaksToApply.Add($allComponentTweaks[$_ - 1]) }
        }
        
        # CORRECTED: Save the IDs of the selected tweaks, not the whole objects.
        $global:ScriptConfig.ComponentServiceTweaks = $tweaksToApply.ID
    }

    if ($tweaksToApply.Count -eq 0) {
        # This point is only reached in Automatic Mode if there's nothing in the config, so we can exit quietly.
        return
    }

    $servicesToDisable = $tweaksToApply | Where-Object { $_.Type -eq 'Service' }
    if ($servicesToDisable) {
        try {
            Write-ColorText $langStrings.compSvcConfiguringServices $Yellow
            # Load the SYSTEM registry hive from the mounted image into a temporary location.
            REG LOAD HKLM\TEMPSYSTEM C:\mount\Windows\System32\config\SYSTEM
            foreach ($tweak in $servicesToDisable) {
                foreach ($serviceName in $tweak.ServiceNames) {
                    try {
                        $servicePath = "Registry::HKLM\TEMPSYSTEM\ControlSet001\Services\$serviceName"
                        if (Test-Path $servicePath) {
                            # Set Start type to 4, which means 'Disabled'.
                            Set-ItemProperty -Path $servicePath -Name "Start" -Value 4 -Type DWord -Force
                            Write-ColorText ($langStrings.compSvcServiceDisabled -f $serviceName) $Green
                        } else {
                            Write-ColorText ($langStrings.compSvcServiceNotFound -f $serviceName) $Yellow
                        }
                    } catch {
                        Write-ColorText ($langStrings.compSvcServiceError -f $serviceName, $_) $Red
                    }
                }
            }
        } finally {
            # Always unload the temporary hive, even if errors occur.
            [gc]::Collect(); [gc]::WaitForPendingFinalizers()
            REG UNLOAD HKLM\TEMPSYSTEM
        }
    }

    $componentsToRemove = $tweaksToApply | Where-Object { $_.Type -eq 'Component' }
    if ($componentsToRemove) {
        Write-ColorText $langStrings.compSvcRemovingComponents $Yellow
        foreach ($tweak in $componentsToRemove) {
            $componentName = ($tweak.$descProperty.Split('(')[0]).Trim()
            Write-ColorText ($langStrings.compSvcProcessing -f $componentName) $Yellow
            try {
                $featureInfo = & $global:dismPath /Image:C:\mount /Get-FeatureInfo /FeatureName:$($tweak.FeatureName)
                $featureStateLine = $featureInfo | Select-String "State"
                
                if ($featureStateLine) {
                    $featureState = $featureStateLine.Line.Split(':')[1].Trim()
                    if ($featureState -eq 'Enabled') {
                        Write-ColorText $langStrings.compSvcStateEnabled $Yellow
                        & $global:dismPath /Image:C:\mount /Disable-Feature /FeatureName:$($tweak.FeatureName) /Remove /NoRestart | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-ColorText $langStrings.compSvcRemoveSuccess $Green
                        } else {
                            Write-ColorText ($langStrings.compSvcRemoveError -f $LASTEXITCODE) $Red
                        }
                    } else {
                        Write-ColorText ($langStrings.compSvcStateNotEnabled -f $featureState) $Cyan
                    }
                } else {
                    Write-ColorText $langStrings.compSvcStateError $Cyan
                }
            } catch {
                Write-ColorText ($langStrings.compSvcCriticalError -f $_) $Red
            }
        }
    }

    if ($runInManualMode) { Suspend-Script }
}

# Allows applying various registry tweaks from an external definition file.
function Set-Registry {
    # Load tweak definitions from the external file.
    try {
        . (Join-Path $PSScriptRoot "src/tweaks.ps1")
    } catch {
        Write-ColorText $langStrings.regTweakDefNotFound $Red
        Suspend-Script
        return
    }

    # Dynamically determine the description property based on the current language.
    $descProperty = "Description_" + $global:currentLanguage
    if ($allTweaks -and -not ($allTweaks[0].PSObject.Properties.Name -contains $descProperty)) {
        $descProperty = "Description_en" # Fallback to English.
    }

    $finalSetupScript = "[System.Threading.Thread]::Sleep(5000); try { Remove-Item -Path 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount' -Recurse -Force; Stop-Process -Name explorer -Force } catch {}"
    
    $tweaksToApply = [System.Collections.Generic.List[object]]::new()

    if ($script:runMode -eq 'AUTOMATIC') {
        Write-ColorText $langStrings.regApplyingFromConfig $Cyan
        if ($global:ScriptConfig.RegistryTweaks.Count -gt 0) {
            $selectedTweakIDs = $global:ScriptConfig.RegistryTweaks # Config stores tweak IDs.
            $tweaksToApply.AddRange(($allTweaks | Where-Object { $selectedTweakIDs -contains $_.ID }))
        }
    }
    else { # Interactive manual mode with a selection loop.
        do {
            Clear-Host
            Show-Banner
            Write-ColorText $langStrings.regMenuTitle $Yellow
            Write-ColorText ("=" * $langStrings.regMenuTitle.Length) $Yellow

            if ($tweaksToApply.Count -gt 0) {
                Write-ColorText "`n$($langStrings.regCurrentSelections)" $Cyan
                $tweaksToApply | ForEach-Object { Write-ColorText "- $($_.$descProperty)" $Green }
            }

            $menuOptions = $allTweaks | ForEach-Object { $_.$descProperty }
            $allOptionIndex = $menuOptions.Count + 1
            
            for ($i = 0; $i -lt $menuOptions.Length; $i++) {
                Write-Host "[$($i + 1)] $($menuOptions[$i])"
            }
            Write-ColorText "--------------------------------" $Yellow
            Write-ColorText "[$allOptionIndex] $($langStrings.regSelectAll)" $Cyan
            Write-ColorText "--------------------------------" $Yellow
            Write-ColorText $langStrings.regGoBackAndApply $Red
            
            $selection = Read-Host "`n$($langStrings.regPrompt)"

            if ($selection -ieq 'g') { break }
            
            try {
                if ($selection -eq $allOptionIndex) { # Toggle all tweaks.
                    if ($tweaksToApply.Count -eq $allTweaks.Count) {
                        $tweaksToApply.Clear()
                        Write-ColorText $langStrings.regAllSelectionsRemoved $Red
                    } else {
                        $tweaksToApply.Clear()
                        $tweaksToApply.AddRange($allTweaks)
                        Write-ColorText $langStrings.regAllSelectionsAdded $Green
                    }
                    Start-Sleep -Seconds 1
                    continue
                }

                $selections = $selection.Split(',').Trim()
                foreach ($sel in $selections) {
                    if ($sel -match "^\d+$") {
                        $numSelection = [int]$sel
                        if ($numSelection -ge 1 -and $numSelection -le $allTweaks.Count) {
                            $selectedTweak = $allTweaks[$numSelection - 1]
                            # Toggle selection.
                            if ($tweaksToApply.Contains($selectedTweak)) {
                                Write-ColorText ($langStrings.regItemRemoved -f $selectedTweak.$descProperty) $Red
                                $tweaksToApply.Remove($selectedTweak)
                            } else {
                                Write-ColorText ($langStrings.regItemAdded -f $selectedTweak.$descProperty) $Green
                                $tweaksToApply.Add($selectedTweak)
                            }
                        } else {
                            Write-ColorText ($langStrings.regInvalidNumber -f $sel) $Red
                        }
                    } else {
                        Write-ColorText ($langStrings.regInvalidInput -f $sel) $Red
                        break 
                    }
                }
                Start-Sleep -Milliseconds 500
            } catch {
                Write-ColorText "$($langStrings.invalidChoice)! $($langStrings.regInvalidInput -f '')" $Red; Start-Sleep -Seconds 2
            }
        } while ($true)
    }
    
    # Handle mutually exclusive Windows Update options.
    $selectedUpdateOptions = $tweaksToApply | Where-Object { $_.ID -like "WU_*" }
    if ($selectedUpdateOptions.Count -gt 1) {
        Write-ColorText ($langStrings.regWarnMultiUpdate -f $selectedUpdateOptions[0].$descProperty) $Yellow
        Start-Sleep -Seconds 3
        $firstOption = $selectedUpdateOptions[0]
        $tweaksToApply.RemoveAll({ ($_.ID -like "WU_*") -and ($_.ID -ne $firstOption.ID) })
    }

    # Save the selected tweak IDs to the global config.
    $global:ScriptConfig.RegistryTweaks = $tweaksToApply.ID

    if ($tweaksToApply.Count -eq 0) {
        if ($script:runMode -eq 'MANUAL') {
            Write-ColorText $langStrings.regNothingSelected $Yellow
            Start-Sleep -Seconds 2
        }
        return
    }

    try {
        # Load the necessary registry hives from the mounted image.
        REG LOAD HKLM\TEMP C:\mount\Windows\System32\config\SOFTWARE
        REG LOAD HKU\TEMP C:\mount\Users\Default\NTUSER.DAT

        $setupScriptContent = [System.Text.StringBuilder]::new()
        
        foreach ($tweak in $tweaksToApply) {
            Write-ColorText ($langStrings.regApplying -f $tweak.$descProperty) $Yellow
            try {
                switch ($tweak.Action) {
                    "WU_Handler" {
                        $auPath = 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsUpdate\AU'
                        New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsUpdate' -Force -ErrorAction SilentlyContinue | Out-Null
                        New-Item -Path $auPath -Force -ErrorAction SilentlyContinue | Out-Null
                        
                        if ($tweak.ID -eq 'WU_NotifyDownload') {
                            Set-ItemProperty -Path $auPath -Name 'AUOptions' -Value 2 -Type DWord -Force
                            Set-ItemProperty -Path $auPath -Name 'NoAutoUpdate' -Value 1 -Type DWord -Force
                        } else { # WU_NotifyInstall
                            Set-ItemProperty -Path $auPath -Name 'AUOptions' -Value 3 -Type DWord -Force
                            Set-ItemProperty -Path $auPath -Name 'NoAutoUpdate' -Value 0 -Type DWord -Force
                        }
                        Write-ColorText $langStrings.regSuccess $Green
                        break
                    }
                    "Registry" {
                        $regPath = "Registry::$($tweak.Path)"
                        if ($tweak.Type -eq "Remove") {
                            if (Test-Path $regPath) { Remove-ItemProperty -Path $regPath -Name $tweak.Name -Force -ErrorAction SilentlyContinue }
                        } else {
                            if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
                            Set-ItemProperty -Path $regPath -Name $tweak.Name -Value $tweak.Value -Type $tweak.Type -Force
                        }
                        Write-ColorText $langStrings.regSuccess $Green
                        break
                    }
                    "InlineScript" {
                        Invoke-Command -ScriptBlock ([scriptblock]::Create($tweak.Code))
                        Write-ColorText $langStrings.regSuccess $Green
                        break
                    }
                    "SetupScript" {
                        # Queue tweaks that need to be run on the live system after installation.
                        $setupScriptContent.AppendLine($tweak.Code) | Out-Null
                        Write-ColorText $langStrings.regQueuedForPostSetup $Cyan
                        break
                    }
                }
            } catch {
                Write-ColorText ($langStrings.regFail -f $tweak.$descProperty, $_.Exception.Message) $Red
            }
        }

        # If there are any post-setup tweaks, create the necessary runner files.
        if ($setupScriptContent.Length -gt 0) {
            $setupScriptContent.AppendLine($finalSetupScript) | Out-Null
            $scriptsPath = "C:\mount\Windows\Setup\Scripts"
            if (-not (Test-Path $scriptsPath)) {
                New-Item -ItemType Directory -Path $scriptsPath -Force | Out-Null
            }
            $postSetupScriptPath = Join-Path $scriptsPath "post-setup.ps1"
            $setupScriptContent.ToString() | Out-File -FilePath $postSetupScriptPath -Encoding utf8
            Write-ColorText $langStrings.regPostSetupScriptCreated $Green
            
            # Create a .bat file on the default user's desktop to manually trigger the script.
            $desktopPath = "C:\mount\Users\Default\Desktop"
            if (-not (Test-Path $desktopPath)) {
                New-Item -ItemType Directory -Path $desktopPath -Force | Out-Null
            }
            $scriptPathInWindows = '%SystemRoot%\Setup\Scripts\post-setup.ps1'
            
            $batContent = $langStrings.regRunnerBatBody -f $scriptPathInWindows
            $batFileName = $langStrings.regRunnerBatTitle
            $batContent | Out-File -FilePath (Join-Path $desktopPath $batFileName) -Encoding OEM
            Write-ColorText ($langStrings.regManualRunnerCreated -f $batFileName) $Green
        }
        
    } catch {
        Write-ColorText ($langStrings.regErrorGeneral -f $_) $Red
    } finally {
        # Always unload the temporary hives.
        Write-ColorText $langStrings.regSaving $Yellow
        [gc]::Collect(); [gc]::WaitForPendingFinalizers()
        REG UNLOAD HKU\TEMP
        REG UNLOAD HKLM\TEMP
        Write-ColorText $langStrings.regComplete $Green
        if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script $langStrings.regReturnToMenu }
    }
}

# Gets a list of provisioned AppX packages and allows the user to remove them.
function Remove-WindowsApps {
    $mountPath = "C:\mount"
    $packagesToRemove = [System.Collections.Generic.List[string]]::new()

    if ($script:runMode -eq 'AUTOMATIC' -and $global:ScriptConfig.RemovedApps.Count -gt 0) {
        Write-ColorText $langStrings.appRemoveFromConfig $Cyan
        $packagesToRemove.AddRange([string[]]$global:ScriptConfig.RemovedApps)
    } else {
        # Load the app exclusion list from the external file.
        try {
            . (Join-Path $PSScriptRoot "src/app-exclusion-list.ps1")
        } catch {
            Write-ColorText $langStrings.appExclusionDefNotFound $Red
            Suspend-Script
            return
        }

        Write-ColorText $langStrings.appRemoveGettingList $Yellow
        $dismOutput = & $global:dismPath /Image:$mountPath /Get-ProvisionedAppxPackages
        if ($LASTEXITCODE -ne 0) {
            Write-ColorText ($langStrings.appRemoveGetListError -f $LASTEXITCODE) $Red
            if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
            return
        }

        # Parse the raw DISM output into structured objects.
        $allAppPackages = [System.Collections.Generic.List[object]]::new()
        $packageBlocks = ($dismOutput -join "`n") -split '(?:\r?\n){2,}'
        foreach ($block in $packageBlocks) {
            $displayNameMatch = [regex]::Match($block, "DisplayName\s*:\s*(.+)")
            $packageNameMatch = [regex]::Match($block, "PackageName\s*:\s*(.+)")
            if ($displayNameMatch.Success -and $packageNameMatch.Success) {
                $allAppPackages.Add([PSCustomObject]@{
                    DisplayName = $displayNameMatch.Groups[1].Value.Trim()
                    PackageName = $packageNameMatch.Groups[1].Value.Trim()
                })
            }
        }
        $allAppPackages = $allAppPackages | Sort-Object DisplayName
        
        Write-ColorText $langStrings.appRemoveExcludingCritical $Cyan
        $filteredAppPackages = $allAppPackages | Where-Object {
            $currentPackage = $_
            $isExcluded = $false
            foreach ($pattern in $appExclusionList) { # Use the variable from the loaded file.
                if ($currentPackage.PackageName -like $pattern) {
                    $isExcluded = $true
                    break
                }
            }
            -not $isExcluded
        }
        
        if (-not $filteredAppPackages) {
            Write-ColorText $langStrings.appRemoveNotFound $Cyan
            if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
            return
        }

        $menuOptions = $filteredAppPackages.DisplayName + $langStrings.appRemoveApplyAll
        $selection = Get-UserChoice -Title $langStrings.appRemoveTitle -Options $menuOptions -MultiSelect $true
        if ($selection -eq 'go_back' -or !$selection) { return }

        if ($selection -contains $menuOptions.Length) {
            $packagesToRemove.AddRange($filteredAppPackages.PackageName)
        } else {
            foreach ($selectedIndex in $selection) {
                $packagesToRemove.Add($filteredAppPackages[$selectedIndex - 1].PackageName)
            }
        }
        $global:ScriptConfig.RemovedApps = $packagesToRemove
    }

    if ($packagesToRemove.Count -eq 0) {
        if ($script:runMode -eq 'MANUAL') {
            Write-ColorText $langStrings.appRemoveNothingSelected $Yellow
            Start-Sleep -Seconds 2
        }
        return
    }

    Write-ColorText "`n$($langStrings.appRemoveStarting)" $Green
    foreach ($packageName in $packagesToRemove) {
        Write-ColorText ($langStrings.appRemoveRemoving -f $packageName) $Yellow
        try {
            & $global:dismPath /Image:$mountPath /Remove-ProvisionedAppxPackage /PackageName:$packageName | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-ColorText ($langStrings.appRemoveSuccess -f $packageName) $Green
            } else {
                Write-ColorText ($langStrings.appRemoveFail -f $packageName, $LASTEXITCODE) $Red
            }
        } catch {
            Write-ColorText ($langStrings.appRemoveError -f $packageName, $_) $Red
        }
    }
    
    Write-ColorText "`n$($langStrings.appRemoveComplete)" $Cyan
    if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
}

# Allows enabling optional Windows features based on definitions in an external file.
function Enable-Features {
    # Load feature definitions from the external file.
    try {
        . (Join-Path $PSScriptRoot "src/features.ps1")
    } catch {
        Write-ColorText $langStrings.featureDefNotFound $Red
        Suspend-Script
        return
    }
    
    # Dynamically determine the name property based on the current language.
    $nameProperty = "Name_" + $global:currentLanguage
    if ($allFeatures -and -not ($allFeatures[0].PSObject.Properties.Name -contains $nameProperty)) {
        $nameProperty = "Name_en" # Fallback to English.
    }

    $featuresToEnable = [System.Collections.Generic.List[object]]::new()

    if ($script:runMode -eq 'AUTOMATIC' -and $global:ScriptConfig.EnabledFeatures.Count -gt 0) {
        Write-ColorText $langStrings.featureEnableFromConfig $Cyan
        $selectedFeatureIDs = $global:ScriptConfig.EnabledFeatures
        $featuresToEnable.AddRange(($allFeatures | Where-Object { $selectedFeatureIDs -contains $_.FeatureName }))
    } else {
        $menuOptions = ($allFeatures | ForEach-Object { $_.$nameProperty }) + $langStrings.featureEnableApplyAll
        $selection = Get-UserChoice -Title $langStrings.featureEnableTitle -Options $menuOptions -MultiSelect $true
        if ($selection -eq 'go_back' -or !$selection) { return }

        if ($selection -contains $menuOptions.Length) {
            $featuresToEnable.AddRange($allFeatures)
        } else {
            $selection | ForEach-Object { $featuresToEnable.Add($allFeatures[$_ - 1]) }
        }
        $global:ScriptConfig.EnabledFeatures = $featuresToEnable.FeatureName
    }
    
    if ($featuresToEnable.Count -eq 0) {
        if ($script:runMode -eq 'MANUAL') {
            Write-ColorText $langStrings.featureEnableNothingSelect $Yellow
            Start-Sleep -Seconds 2
        }
        return
    }

    foreach ($feature in $featuresToEnable) {
        $featureNameDisplay = $feature.$nameProperty
        Write-ColorText ($langStrings.featureEnableEnabling -f $featureNameDisplay) $Green
        try {
            $dismParams = @("/Image:C:\mount", "/Enable-Feature", "/FeatureName:$($feature.FeatureName)", "/All")
            # Some features like .NET 3.5 require source files from the ISO.
            if ($feature.Source) {
                $dismParams += @("/LimitAccess", "/Source:$($feature.Source)")
            }
            & $global:dismPath $dismParams
            Write-ColorText ($langStrings.featureEnableSuccess -f $featureNameDisplay) $Green
        } catch {
            Write-ColorText ($langStrings.featureEnableError -f $featureNameDisplay, $_) $Red
        }
    }
    
	if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
}

# Commits all changes to the image and creates the final bootable ISO file.
function Complete-Image {
    Remove-Item -Path "C:\mount\dism.log" -Force -ErrorAction SilentlyContinue
	Start-Sleep -Seconds 3
	
    try {
        $commitScriptBlock = {
            & $using:global:dismPath /Unmount-Image /MountDir:"C:\mount" /Commit
            if ($LASTEXITCODE -ne 0) { throw ($using:langStrings.completeUnmountFail -f $LASTEXITCODE) }
        }
        Invoke-LongRunningOperation -ScriptBlock $commitScriptBlock -Message $langStrings.longOpSavingImage
        
    } catch {
        Write-ColorText ($langStrings.completeSaveError -f $_) $Red
        throw $langStrings.completeFinalizeFail
    }
    
    Write-ColorText $langStrings.completeCreatingIso $Green
    $isoTool = Get-IsoTool
    if (-not $isoTool) {
        Write-ColorText $langStrings.completeToolNotFound $Red
        Write-ColorText $langStrings.completeToolNotFoundHelp $Yellow
        return
    }

    Add-Type -AssemblyName System.Windows.Forms
	$SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
	$SaveFileDialog.Title = $langStrings.completeSaveFileTitle
	$SaveFileDialog.Filter = "ISO files (*.iso)|*.iso|All files (*.*)|*.*"
	$SaveFileDialog.DefaultExt = "iso"
	$SaveFileDialog.FileName = $langStrings.completeDefaultIsoName
	$SaveFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

	if ($SaveFileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-ColorText $langStrings.completeOutputCanceled $Red
        return
    }
    $outputIso = $SaveFileDialog.FileName
    Write-Host ($langStrings.completeOutputIsoPath -f $outputIso) -ForegroundColor Green

    try {
        if ($isoTool.Tool -eq 'oscdimg') {
            # oscdimg requires a specific bootdata string for dual boot (BIOS + UEFI).
            $bootData = '2#p0,e,bC:\temp_iso\boot\etfsboot.com#pEF,e,bC:\temp_iso\efi\microsoft\boot\efisys.bin'
            & $isoTool.Path -m -o -u2 -udfver102 -bootdata:$bootData C:\temp_iso $outputIso
        } else {
            # mkisofs uses different parameters for the same dual boot setup.
            & $isoTool.Path -iso-level 4 -l -r -J -joliet-long -no-emul-boot -boot-load-size 8 -b "boot/etfsboot.com" -c "boot/boot.catalog" -eltorito-alt-boot -no-emul-boot -eltorito-boot "efi/microsoft/boot/efisys.bin" -o $outputIso "C:\temp_iso"
        }
        Write-ColorText ($langStrings.completeIsoSuccess -f $outputIso) $Green
        Cleanup
    } catch {
        Write-ColorText ($langStrings.completeIsoError -f $_) $Red
        Write-ColorText $langStrings.completeFilesSaved $Yellow
    }
}

# Cleans up all temporary files, folders, and registry hives.
function Cleanup {
    # This function checks if $langStrings is loaded to run safely even within a trap that occurs early.
    $cleanupMsg = if ($null -ne $langStrings) { $langStrings.cleanupCleaning } else { "Cleaning up temporary files and folders..." }
    Write-ColorText $cleanupMsg $Green

    [gc]::Collect(); [gc]::WaitForPendingFinalizers()
    
    # Unload registry hives, suppressing errors if they are not loaded.
    try { REG UNLOAD HKU\TEMP 2>$null } catch {}
    try { REG UNLOAD HKLM\TEMP 2>$null } catch {}
    
    # If an image is still mounted, discard changes to prevent a "dirty" state.
    if (Test-Path "C:\mount\Windows") {
        $mountedMsg = if ($null -ne $langStrings) { $langStrings.cleanupImageMounted } else { "There is still a mounted image, discarding changes..." }
        Write-ColorText $mountedMsg $Yellow
        & $global:dismPath /Unmount-Image /MountDir:"C:\mount" /Discard
    }

    if (Test-Path "C:\temp_iso") { Remove-Item "C:\temp_iso" -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path "C:\mount") { Remove-Item "C:\mount" -Recurse -Force -ErrorAction SilentlyContinue }
    
    $completeMsg = if ($null -ne $langStrings) { $langStrings.cleanupComplete } else { "Cleanup complete!" }
    Write-ColorText $completeMsg $Green
}

# --- SCRIPT EXECUTION START ---

# 1. Language Selection (hardcoded prompt to avoid dependencies).
Clear-Host
Write-ColorText "================================================================" $Cyan
Write-ColorText "     Lütfen bir dil seçin / Please select a language     " $Cyan
Write-ColorText "================================================================" $Cyan
Write-Host ""
Write-ColorText "1. Türkçe" $White
Write-ColorText "2. English" $White
Write-Host ""
$langChoice = Read-Host "Seçiminiz / Your choice"

switch ($langChoice) {
    "1" { $global:currentLanguage = 'tr' }
    "2" { $global:currentLanguage = 'en' }
    default { 
        Write-Host "Invalid selection, defaulting to English." -ForegroundColor Yellow
        $global:currentLanguage = 'en' 
    }
}

# 2. Load the language file based on the selection.
try {
    . (Join-Path $PSScriptRoot "src/languages.ps1")
} catch {
    Write-ColorText "CRITICAL ERROR: languages.ps1 could not be found or loaded. The script cannot continue." $Red
    Write-ColorText "Please ensure languages.ps1 is in the same folder as the main script." $Yellow
    Read-Host "Press Enter to exit."
    exit 1
}

# 3. Start main operations now that the language is loaded.
$global:dismPath = Find-DismPath
if (-not $global:dismPath) {
    Write-ColorText $langStrings.dismNotFoundExit $Red
    exit 1
}

Show-Banner
	
# Check for Administrator privileges.
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-ColorText $langStrings.scriptNotAdmin $Red
    Start-Sleep -Seconds 5
    exit 1
}

# Main workflow logic.
if (Test-Path "C:\mount\Windows") {
    # If a previous session was interrupted, resume from the menu.
    Write-ColorText $langStrings.scriptExistingMount $Yellow
    Start-Sleep -Seconds 3
} else {
    # Start a new session.
	if ([string]::IsNullOrWhiteSpace($IsoPath)) {
        # If no ISO path was provided as a parameter, open a file dialog.
		Add-Type -AssemblyName System.Windows.Forms
		$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
		$OpenFileDialog.Title = $langStrings.scriptSelectIso
		$OpenFileDialog.Filter = "ISO files (*.iso)|*.iso|All files (*.*)|*.*"
		$OpenFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
		
		if ($OpenFileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            Write-Host $langStrings.scriptIsoNotSelected -ForegroundColor Red
			exit
        }
        $IsoPath = $OpenFileDialog.FileName
        Write-Host ($langStrings.scriptIsoSelected -f $IsoPath) -ForegroundColor Green
	}
	if (-not (Test-Path $IsoPath) -or $IsoPath -notlike "*.iso") {
		Write-ColorText ($langStrings.scriptIsoInvalid -f $IsoPath) $Red
		exit 1
	}
	Write-ColorText ($langStrings.scriptIsoFound -f $IsoPath) $Green
		
    # Prepare the environment and mount the image.
	Initialize-Environment
	Copy-IsoFiles -IsoPath $IsoPath
	Remove-WindowsEditions

	if (-not (Mount-WindowsImage)) {
		Write-ColorText $langStrings.scriptMountFail $Red
		Cleanup
		exit 1
	}

    # Optional initial prompts for common tasks.
    Show-Banner
    $updateChoice = Read-Host "$($langStrings.scriptPromptUpdate) "
    if ($updateChoice -ieq 'E' -or $updateChoice -ieq 'Y') { Add-WindowsUpdates }

    Show-Banner
    $driverChoice = Read-Host "$($langStrings.scriptPromptDriver) "
    if ($driverChoice -ieq 'E' -or $driverChoice -ieq 'Y') { Add-Drivers }

    # Check if the user wants to start in automatic mode.
    if (Import-Configuration) {
        $script:runMode = 'AUTOMATIC'
    }
}

# --- EXECUTION BLOCK ---

# If in automatic mode, run all configured tasks sequentially.
if ($script:runMode -eq 'AUTOMATIC') {
    Write-ColorText "`n$($langStrings.execAutoModeStarted)" $Cyan
    if ($global:ScriptConfig.ComponentServiceTweaks.Count -gt 0) { Set-ComponentsAndServices }
    if ($global:ScriptConfig.RegistryTweaks.Count -gt 0) { Set-Registry }
    if ($global:ScriptConfig.RemovedApps.Count -gt 0) { Remove-WindowsApps }
    if ($global:ScriptConfig.EnabledFeatures.Count -gt 0) { Enable-Features }
    Write-ColorText "`n$($langStrings.execAutoModeCompleted)" $Cyan

    # Ask the user if they want to switch to manual mode for further changes.
    $extraChoice = Read-Host "$($langStrings.execAutoPromptManual) "
    if ($extraChoice -ieq 'E' -or $extraChoice -ieq 'Y') {
        $script:runMode = 'MANUAL'
    } else {
        Write-ColorText $langStrings.execAutoCreateIso $Green
        Start-Sleep -Seconds 2
        Complete-Image
        $script:runMode = 'FINISHED' # Set mode to prevent manual menu from showing.
    }
}

# If in manual mode, display the main menu loop.
if ($script:runMode -eq 'MANUAL') {
    do {
        Clear-Host
        Show-Banner
        Write-ColorText $langStrings.mainMenu1 $White
        Write-ColorText $langStrings.mainMenu2 $White
        Write-ColorText $langStrings.mainMenu3 $White
        Write-ColorText $langStrings.mainMenu4 $White
        Write-ColorText $langStrings.mainMenu5 $White
        Write-ColorText $langStrings.mainMenu6 $White
        Write-ColorText $langStrings.mainMenu7 $Cyan
        Write-ColorText $langStrings.mainMenu8 $Green
        Write-ColorText $langStrings.mainMenu9 $Red
        Write-Host ""
        
        $choice = Read-Host $langStrings.promptChoice
        
        switch ($choice) {
            "1" { Add-WindowsUpdates }
            "2" { Add-Drivers }
            "3" { Set-ComponentsAndServices }
            "4" { Set-Registry }
            "5" { Remove-WindowsApps }
            "6" { Enable-Features }
            "7" { Export-Configuration }
            "8" { Complete-Image; $choice = "exit" }
            "9" { Cleanup; $choice = "exit" }
            default {	
                Write-Host $langStrings.invalidChoice -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    } while ($choice -ne "exit")
}

Write-ColorText $langStrings.finishMessage $Yellow
Read-Host