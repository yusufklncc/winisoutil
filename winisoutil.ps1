# WinIsoUtil - A PowerShell script to customize Windows installation ISOs.
# This script provides a user-friendly interface for modifying Windows ISO files.
# It supports various customization options, including feature selection, component tweaks, and application exclusions.
# The script is designed to be modular and extensible, allowing for future enhancements and additional features.
# Author: Yusuf İhsan KILINÇ
# GitHub: https://github.com/yusufklncc/winisoutil
# License: MIT License
# Note: This script requires administrative privileges to run.
# Usage of this script is at your own risk. Always back up important data before making system modifications.

[CmdletBinding()]
param(
    [string]$IsoPath,
    [string]$ConfigurationPath,
    [string]$OutputIsoPath,
    [string]$ValidationReportPath,
    [ValidateSet('tr', 'en')]
    [string]$Language,
    [ValidateRange(1, 999)]
    [int]$EditionIndex,
    [string]$UpdatesPath,
    [string]$DriversPath,
    [string]$WorkingDirectory = (Join-Path $env:TEMP 'WinISOUtil'),
    [switch]$Unattended,
    [switch]$SkipWimOptimization
)

# This trap block runs if a terminating error occurs anywhere in the script.
# It ensures a safe cleanup to prevent leaving a mounted image behind.
trap {
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
    SchemaVersion          = 3
    RemovedApps            = @()
    RemovedAppSelectors    = @()
    RemovedCapabilities    = @()
    DisabledFeatures       = @()
    RegistryTweaks         = @()
    EnabledFeatures        = @()
    ComponentServiceTweaks = @()
}

# A script-level variable to determine the execution mode ('MANUAL' or 'AUTOMATIC').
$script:runMode = 'MANUAL' # Default mode.

$script:WorkspaceMarkerName = '.winisoutil-workspace.json'
$script:WorkspaceMarkerType = 'WinISOUtilWorkspace'
$script:SessionId = [guid]::NewGuid().ToString()
$script:WorkingDirectory = [System.IO.Path]::GetFullPath($WorkingDirectory)
$script:IsoContentPath = Join-Path $script:WorkingDirectory 'iso'
$script:MountPath = Join-Path $script:WorkingDirectory 'mount'
$script:WorkspaceMarkerPath = Join-Path $script:WorkingDirectory $script:WorkspaceMarkerName
$script:InstallImagePath = $null
$script:ImportedConfigurationPath = $null

Import-Module (Join-Path $PSScriptRoot 'automation\modules\Profile.Validation.psm1') -Force -ErrorAction Stop

# --- ALL FUNCTION DEFINITIONS ---

# Helper function to write text to the console in a specified color.
function Write-ColorText {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

# Ensures recursive cleanup can only target a child of the configured workspace.
function Assert-SafeWorkspacePath {
    param([Parameter(Mandatory)][string]$Path)

    $workspaceRoot = [System.IO.Path]::GetFullPath($script:WorkingDirectory).TrimEnd('\') + '\'
    $candidate = [System.IO.Path]::GetFullPath($Path)
    if (-not $candidate.StartsWith($workspaceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside the WinISOUtil workspace: $candidate"
    }
}

function Test-OwnedWorkspace {
    if (-not (Test-Path -LiteralPath $script:WorkspaceMarkerPath -PathType Leaf)) {
        return $false
    }

    try {
        $marker = Get-Content -LiteralPath $script:WorkspaceMarkerPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        return $marker.Type -eq $script:WorkspaceMarkerType -and
            [System.IO.Path]::GetFullPath([string]$marker.Root) -eq $script:WorkingDirectory
    } catch {
        return $false
    }
}

function New-WorkspaceMarker {
    if (-not (Test-Path -LiteralPath $script:WorkingDirectory)) {
        New-Item -ItemType Directory -Path $script:WorkingDirectory -Force -ErrorAction Stop | Out-Null
    }

    @{
        Type      = $script:WorkspaceMarkerType
        Root      = $script:WorkingDirectory
        SessionId = $script:SessionId
        CreatedAt = (Get-Date).ToString('o')
    } | ConvertTo-Json | Out-File -LiteralPath $script:WorkspaceMarkerPath -Encoding utf8 -Force
}

function Remove-OwnedWorkspaceItem {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-OwnedWorkspace)) {
        throw "Refusing to clean an unowned workspace: $($script:WorkingDirectory)"
    }

    Assert-SafeWorkspacePath -Path $Path
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    }
}

function Invoke-Dism {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$PassThru,
        [switch]$Quiet
    )

    $dismArguments = @('/English') + $Arguments
    $output = & $global:dismPath @dismArguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "DISM failed with exit code $exitCode.`n$($output -join "`n")"
    }

    if (-not $Quiet -and -not $PassThru) {
        $output | ForEach-Object { Write-Host $_ }
    }
    if ($PassThru) {
        return $output
    }
}

function Invoke-Reg {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $output = & reg.exe @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "REG.EXE failed: reg.exe $($Arguments -join ' ')`n$($output -join "`n")"
    }
    return $output
}

function Get-OfflineCurrentControlSet {
    $current = Get-ItemPropertyValue -Path 'Registry::HKLM\TEMPSYSTEM\Select' -Name 'Current' -ErrorAction Stop
    return ('ControlSet{0:d3}' -f [int]$current)
}

# Clears the screen and displays the script's main banner.
function Show-Banner {
    Clear-Host
    Write-ColorText "================================================================" $Cyan
    Write-ColorText "                   $($langStrings.bannerTitle)                  " $Cyan
    Write-ColorText "================================================================" $Cyan
    Write-Host ""
}

# Pauses the script and waits for a key press from the user.
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
    Write-Host "`r$(' ' * ($Message.Length + 5))`r" # Clear the spinner line.
    try {
        $jobOutput = Receive-Job -Job $job -ErrorAction Stop
        if ($job.State -eq 'Failed') {
            $errorMsg = $job.ChildJobs[0].Error | Out-String
            throw ($langStrings.longOpFailed -f $errorMsg.Trim())
        }
        return $jobOutput
    } finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
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
            $indices = @($selection.Split(',').Trim() | ForEach-Object { [int]$_ })
            if ($indices.Count -eq 0 -or ($indices | Where-Object { $_ -lt 1 -or $_ -gt $Options.Length })) {
                throw "Selection is outside the available option range."
            }
            return $indices
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

# Finds the required oscdimg.exe tool from the Windows ADK.
function Find-Oscdimg {
    $adkPaths = @(
        "C:\Program Files (x86)\Windows Kits\11\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg",
        "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
    )
    foreach ($path in $adkPaths) {
        $oscdimgPath = Join-Path $path "oscdimg.exe"
        if (Test-Path $oscdimgPath) {
            Write-ColorText ($langStrings.oscdimgFound -f $oscdimgPath) $Green
            return $oscdimgPath
        }
    }
    return $null
}

function ConvertTo-StringArray {
    param(
        $Value,
        [Parameter(Mandatory)][string]$PropertyName
    )

    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($Value)) {
        if ($null -eq $item) { continue }
        if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) {
            throw "Configuration property '$PropertyName' must contain non-empty strings only."
        }
        $result.Add($item.Trim())
    }
    return [string[]]$result.ToArray()
}

function ConvertTo-ValidatedConfiguration {
    param([Parameter(Mandatory)]$Configuration)

    return ConvertTo-ValidatedWinIsoUtilConfiguration -Configuration $Configuration -RepositoryRoot $PSScriptRoot
}

# Asks the user if they want to import settings from a .json file to run in automatic mode.
function Import-Configuration {
    param([string]$Path)

    Show-Banner
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-ColorText $langStrings.importTitle $Yellow
        Write-ColorText $langStrings.importDesc $Cyan
        $choice = Read-Host $langStrings.importPrompt
    } else {
        $choice = 'Y'
    }

    if ($choice -ieq 'E' -or $choice -ieq 'Y') {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            Add-Type -AssemblyName System.Windows.Forms
            $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $OpenFileDialog.Title = $langStrings.importFileSelectTitle
            $OpenFileDialog.Filter = "JSON files (*.json)|*.json"
            $OpenFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            if ($OpenFileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
                Write-ColorText $langStrings.importFileNotSelected $Yellow
                if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
                return $false
            }
            $Path = $OpenFileDialog.FileName
        }

        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            try {
                if ((Get-Item -LiteralPath $Path -ErrorAction Stop).Length -gt 1MB) {
                    throw "Configuration files larger than 1 MB are not accepted."
                }
                Write-ColorText ($langStrings.importReadingFile -f $Path) $Green
                $configContent = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                $validatedConfiguration = ConvertTo-ValidatedConfiguration -Configuration $configContent
                $global:ScriptConfig.SchemaVersion = $validatedConfiguration.SchemaVersion
                $global:ScriptConfig.RemovedApps = $validatedConfiguration.RemovedApps
                $global:ScriptConfig.RemovedAppSelectors = $validatedConfiguration.RemovedAppSelectors
                $global:ScriptConfig.RemovedCapabilities = $validatedConfiguration.RemovedCapabilities
                $global:ScriptConfig.DisabledFeatures = $validatedConfiguration.DisabledFeatures
                $global:ScriptConfig.RegistryTweaks = $validatedConfiguration.RegistryTweaks
                $global:ScriptConfig.EnabledFeatures = $validatedConfiguration.EnabledFeatures
                $global:ScriptConfig.ComponentServiceTweaks = $validatedConfiguration.ComponentServiceTweaks
                $script:ImportedConfigurationPath = [System.IO.Path]::GetFullPath($Path)
                if ($validatedConfiguration.SchemaVersion -eq 2) {
                    Write-ColorText $langStrings.importSchemaV2MigrationWarning $Yellow
                }
                if ($validatedConfiguration.LegacyMappings.Count -gt 0) {
                    Write-ColorText ($langStrings.importLegacyMappings -f ($validatedConfiguration.LegacyMappings -join ', ')) $Yellow
                }
                Write-ColorText $langStrings.importSuccess $Green
                Start-Sleep -Seconds 2
                return $true # Return true to signal automatic mode.
            } catch {
                Write-ColorText ($langStrings.importReadError -f $_) $Red
                if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
                return $false
            }
        } else {
            Write-ColorText ($langStrings.importReadError -f "File not found: $Path") $Red
            if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
            return $false
        }
    } else {
        Write-ColorText $langStrings.importManualContinue $Yellow
        if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
        return $false
    }
}

# Exports the current user selections to a .json configuration file.
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
            $exportObject = @{
                SchemaVersion          = 3
                Description            = $langStrings.exportConfigDesc
                DateCreated            = (Get-Date).ToString("yyyy-MM-dd")
                RemovedAppSelectors    = $global:ScriptConfig.RemovedAppSelectors
                RemovedCapabilities    = $global:ScriptConfig.RemovedCapabilities
                DisabledFeatures       = $global:ScriptConfig.DisabledFeatures
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
        if (Test-Path -LiteralPath $script:WorkingDirectory) {
            if (-not (Test-OwnedWorkspace)) {
                $existingItems = @(Get-ChildItem -LiteralPath $script:WorkingDirectory -Force -ErrorAction Stop)
                if ($existingItems.Count -gt 0) {
                    throw "The configured workspace exists but is not owned by WinISOUtil: $($script:WorkingDirectory)"
                }
                New-WorkspaceMarker
            }
            if (Test-Path -LiteralPath (Join-Path $script:MountPath 'Windows')) {
                throw "An existing mounted image was found in the WinISOUtil workspace. Resolve it before starting a new run: $($script:MountPath)"
            }
            Remove-OwnedWorkspaceItem -Path $script:IsoContentPath
            Remove-OwnedWorkspaceItem -Path $script:MountPath
        } else {
            New-WorkspaceMarker
        }
        New-Item -ItemType Directory -Path $script:IsoContentPath -Force -ErrorAction Stop | Out-Null
        New-Item -ItemType Directory -Path $script:MountPath -Force -ErrorAction Stop | Out-Null
        Write-ColorText $langStrings.initEnvSuccess $Green
    } catch {
        Write-ColorText ($langStrings.initEnvError -f $_) $Red
        throw $langStrings.initEnvFail
    }
}

function Convert-EsdToWim {
    param([Parameter(Mandatory)][string]$EsdPath)

    $wimPath = Join-Path $script:IsoContentPath 'sources\install.wim'
    Write-ColorText $langStrings.copyIsoConvertingEsd $Yellow
    $imageInfo = Invoke-Dism -Arguments @('/Get-WimInfo', "/WimFile:$EsdPath") -PassThru -Quiet
    $indexes = @($imageInfo | ForEach-Object {
        if ($_ -match '^\s*Index\s*:\s*(\d+)\s*$') { $Matches[1] }
    })
    if ($indexes.Count -eq 0) {
        throw "No image indexes were found in install.esd."
    }

    foreach ($index in $indexes) {
        Invoke-Dism -Arguments @(
            '/Export-Image',
            "/SourceImageFile:$EsdPath",
            "/SourceIndex:$index",
            "/DestinationImageFile:$wimPath",
            '/Compress:max',
            '/CheckIntegrity'
        )
    }
    Remove-Item -LiteralPath $EsdPath -Force -ErrorAction Stop
    return $wimPath
}

function Resolve-InstallImagePath {
    $wimPath = Join-Path $script:IsoContentPath 'sources\install.wim'
    $esdPath = Join-Path $script:IsoContentPath 'sources\install.esd'
    if (Test-Path -LiteralPath $wimPath -PathType Leaf) {
        Set-ItemProperty -LiteralPath $wimPath -Name IsReadOnly -Value $false -ErrorAction Stop
        return $wimPath
    }
    if (Test-Path -LiteralPath $esdPath -PathType Leaf) {
        Set-ItemProperty -LiteralPath $esdPath -Name IsReadOnly -Value $false -ErrorAction Stop
        return Convert-EsdToWim -EsdPath $esdPath
    }
    throw "The selected ISO does not contain sources\install.wim or sources\install.esd."
}

# Mounts the source ISO and copies its contents to a temporary folder.
function Copy-IsoFiles {
    param([string]$IsoPath)
    Write-ColorText $langStrings.copyIsoCopying $Green
    $mountResult = $null
    try {
        $mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru
        $driveLetter = ($mountResult | Get-Volume).DriveLetter
        if ([string]::IsNullOrWhiteSpace($driveLetter)) {
            throw "The mounted ISO did not expose a drive letter."
        }
        Copy-Item -Path "$($driveLetter):\*" -Destination $script:IsoContentPath -Recurse -Force -ErrorAction Stop
        # The install.wim file must be writable for modifications.
        Write-ColorText $langStrings.copyIsoUnlockingWim $Yellow
        $script:InstallImagePath = Resolve-InstallImagePath
        Write-ColorText $langStrings.copyIsoSuccess $Green
    } catch {
        Write-ColorText ($langStrings.copyIsoError -f $_) $Red
        throw $langStrings.copyIsoFail
    } finally {
        # Always ensure the ISO is dismounted, even if errors occur.
        if ($mountResult) { Dismount-DiskImage -ImagePath $IsoPath }
    }
}

# Finds the path to dism.exe, prioritizing the one from Windows ADK for better compatibility.
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
        # As a fallback, check if DISM is in the system's PATH variable.
        $dismInPath = Get-Command "dism.exe" -ErrorAction SilentlyContinue
        if ($dismInPath) {
            Write-ColorText ($langStrings.dismFoundInPath -f $dismInPath.Source) $Green
            return $dismInPath.Source
        }
    } catch {}
    Write-ColorText $langStrings.dismNotFoundWarning $Red
    return $null
}

# Allows the user to remove unwanted Windows editions from the install.wim file to save space.
function Remove-WindowsEditions {
    $wimFile = $script:InstallImagePath
    do {
        Clear-Host
        Show-Banner
        Write-ColorText $langStrings.removeEditionsAnalyzing $Green
        $wimInfo = Invoke-Dism -Arguments @('/Get-WimInfo', "/WimFile:$wimFile") -PassThru -Quiet
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
            $indicesToDelete = @($choice.Split(',') | ForEach-Object { [int]$_.Trim() } | Sort-Object -Unique -Descending)
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
            if ($indicesToDelete.Count -ge $indexCount) {
                Write-ColorText $langStrings.removeEditionsKeepOne $Red
                Start-Sleep -Seconds 3
                continue
            }
            foreach ($index in $indicesToDelete) {
                Write-ColorText ($langStrings.removeEditionsRemoving -f $index) $Yellow
                try {
                    Invoke-Dism -Arguments @('/Delete-Image', "/ImageFile:$wimFile", "/Index:$index", '/CheckIntegrity')
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

# Mounts the selected Windows image edition for modification.
function Mount-WindowsImage {
    param([int]$Index)

    Clear-Host
    Show-Banner
    $wimFile = $script:InstallImagePath
    Write-ColorText $langStrings.mountListingEditions $Green
    $wimInfo = Invoke-Dism -Arguments @('/Get-WimInfo', "/WimFile:$wimFile") -PassThru -Quiet
    $editions = $wimInfo | Select-String "Index|Name"
    Write-ColorText $langStrings.removeEditionsCurrent $Yellow
    $editions | ForEach-Object { Write-Host $_.Line }
    $indexCount = ($editions | Where-Object { $_.Line -match "Name" }).Count
    if ($indexCount -eq 0) {
        throw "No Windows image indexes were found in $wimFile."
    }

    if ($Index -eq 0 -and $indexCount -eq 1) {
        $Index = 1
    } elseif ($Index -eq 0 -and $Unattended) {
        throw "The ISO contains multiple Windows editions. Specify -EditionIndex for unattended mode."
    } elseif ($Index -eq 0) {
        $choice = Read-Host $langStrings.mountPromptIndex
        if ($choice -notmatch '^\d+$') {
            Write-ColorText $langStrings.mountInvalidIndex $Red
            return $false
        }
        $Index = [int]$choice
    }

    if ($Index -lt 1 -or $Index -gt $indexCount) {
        Write-ColorText $langStrings.mountInvalidIndex $Red
        return $false
    }

    Write-ColorText "`n$($langStrings.mountMountingImage)" $Yellow
    try {
        Invoke-Dism -Arguments @('/Mount-Image', "/ImageFile:$wimFile", "/Index:$Index", "/MountDir:$($script:MountPath)")
        Write-ColorText $langStrings.mountSuccess $Green
        Start-Sleep -Seconds 3
        return $true
    } catch {
        Write-ColorText ($langStrings.mountError -f $_) $Red
        throw $langStrings.mountFail
    }
}

# Integrates Windows Update packages (.msu) from a user-selected folder into the image.
function Add-WindowsUpdates {
    param([string]$Path)

    Clear-Host
    Show-Banner
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Add-Type -AssemblyName System.Windows.Forms
        $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $FolderBrowserDialog.Description = $langStrings.updatesPromptPath
        if ($FolderBrowserDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $Path = $FolderBrowserDialog.SelectedPath
        } else {
            return # Return to the menu if the user cancels the dialog.
        }
    }
    if (Test-Path -LiteralPath $Path -PathType Container) {
        $updateFiles = Get-ChildItem -LiteralPath $Path -Filter "*.msu" -File -ErrorAction SilentlyContinue
        if ($updateFiles) {
            Write-ColorText $langStrings.updatesAdding $Green
            foreach ($file in $updateFiles) {
                Write-ColorText ($langStrings.updatesAddingFile -f $file.Name) $Yellow
                try {
                    Invoke-Dism -Arguments @(
                        "/Image:$($script:MountPath)",
                        '/Add-Package',
                        "/PackagePath:$($file.FullName)",
                        "/LogPath:$(Join-Path $script:MountPath 'dism.log')"
                    )
                    Write-ColorText ($langStrings.updatesAddedFile -f $file.Name) $Green
                } catch {
                    Write-ColorText ($langStrings.updatesErrorFile -f $file.Name, $_) $Red
                }
            }
        } else {
            Write-ColorText $langStrings.updatesMsuNotFound $Red
        }
    } else {
        Write-ColorText $langStrings.updatesInvalidPath $Red
    }
    if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
}

# Integrates drivers (.inf) from a user-selected folder and its subdirectories into the image.
function Add-Drivers {
    param([string]$Path)

    Clear-Host
    Show-Banner
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Add-Type -AssemblyName System.Windows.Forms
        $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $FolderBrowserDialog.Description = $langStrings.driversPromptPath
        if ($FolderBrowserDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $Path = $FolderBrowserDialog.SelectedPath
        } else {
            return # Return to the menu if the user cancels the dialog.
        }
    }
    if (Test-Path -LiteralPath $Path -PathType Container) {
        Write-ColorText $langStrings.driversAdding $Yellow
        try {
            # The /Recurse switch tells DISM to look for drivers in all subfolders.
            Invoke-Dism -Arguments @("/Image:$($script:MountPath)", '/Add-Driver', "/Driver:$Path", '/Recurse')
            Write-ColorText $langStrings.driversSuccess $Green
        } catch {
            Write-ColorText ($langStrings.driversError -f $_) $Red
        }
    } else {
        Write-ColorText $langStrings.updatesInvalidPath $Red
    }
    if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
}

# Allows disabling services based on definitions in an external file.
function Set-ComponentsAndServices {
    try {
        . (Join-Path $PSScriptRoot "src/components.ps1")
    } catch {
        Write-ColorText $langStrings.compSvcTweakDefNotFound $Red
        Suspend-Script
        return
    }

    $tweaksToApply = [System.Collections.Generic.List[object]]::new()
    $runInManualMode = $script:runMode -eq 'MANUAL'

    if (-not $runInManualMode) { # Automatic Mode
        if ($global:ScriptConfig.ComponentServiceTweaks.Count -gt 0) {
            Write-ColorText $langStrings.compSvcApplyingFromConfig $Cyan
            $selectedTweakIDs = $global:ScriptConfig.ComponentServiceTweaks
            $tweaksToApply.AddRange([object[]]@($allComponentTweaks | Where-Object { $selectedTweakIDs -contains $_.ID }))
        }
    }
    else { # Manual Mode
        Clear-Host
        Show-Banner
        $menuOptions = ($allComponentTweaks | ForEach-Object { $global:langStrings["comp_$($_.ID)_desc"] }) + $langStrings.compSvcApplyAll
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
        $global:ScriptConfig.ComponentServiceTweaks = $tweaksToApply.ID
    }

    if ($tweaksToApply.Count -eq 0) {
        return
    }

    $servicesToDisable = $tweaksToApply | Where-Object { $_.Type -eq 'Service' }
    if ($servicesToDisable) {
        $systemHiveLoaded = $false
        try {
            Write-ColorText $langStrings.compSvcConfiguringServices $Yellow
            Invoke-Reg -Arguments @('LOAD', 'HKLM\TEMPSYSTEM', (Join-Path $script:MountPath 'Windows\System32\config\SYSTEM')) | Out-Null
            $systemHiveLoaded = $true
            $offlineControlSet = Get-OfflineCurrentControlSet
            foreach ($tweak in $servicesToDisable) {
                foreach ($serviceName in $tweak.ServiceNames) {
                    try {
                        $servicePath = "Registry::HKLM\TEMPSYSTEM\$offlineControlSet\Services\$serviceName"
                        if (Test-Path $servicePath) {
                            Set-ItemProperty -Path $servicePath -Name "Start" -Value 4 -Type DWord -Force
                            Write-ColorText ($langStrings.compSvcServiceDisabled -f $serviceName) $Green
                        } else {
                            Write-ColorText ($langStrings.compSvcServiceNotFound -f $serviceName) $Yellow
                        }
                    } catch {
                        Write-ColorText ($langStrings.compSvcServiceError -f $serviceName, $_) $Red
                        if (-not $runInManualMode) { throw }
                    }
                }
            }
        } finally {
            [gc]::Collect(); [gc]::WaitForPendingFinalizers()
            if ($systemHiveLoaded) {
                Invoke-Reg -Arguments @('UNLOAD', 'HKLM\TEMPSYSTEM') | Out-Null
            }
        }
    }

    if ($runInManualMode) { Suspend-Script }
}

# Applies various registry tweaks from an external definition file.
function Set-Registry {
    $registryFailure = $null
    try {
        . (Join-Path $PSScriptRoot "src/tweaks.ps1")
    } catch {
        Write-ColorText $langStrings.regTweakDefNotFound $Red
        Suspend-Script
        return
    }

    $finalSetupScript = "[System.Threading.Thread]::Sleep(5000); try { Stop-Process -Name explorer -Force } catch {}"
    $tweaksToApply = [System.Collections.Generic.List[object]]::new()

    if ($script:runMode -eq 'AUTOMATIC') {
        Write-ColorText $langStrings.regApplyingFromConfig $Cyan
        if ($global:ScriptConfig.RegistryTweaks.Count -gt 0) {
            $selectedTweakIDs = $global:ScriptConfig.RegistryTweaks
            $tweaksToApply.AddRange([object[]]@($allTweaks | Where-Object { $selectedTweakIDs -contains $_.ID }))
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
                $tweaksToApply | ForEach-Object {
                    $langKey = "tweak_$($_.ID)_desc"
                    Write-ColorText "- $($global:langStrings[$langKey])" $Green
                }
            }
            $menuOptions = $allTweaks | ForEach-Object { $global:langStrings["tweak_$($_.ID)_desc"] }
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
                            $langKey = "tweak_$($selectedTweak.ID)_desc"
                            $description = $global:langStrings[$langKey]
                            if ($tweaksToApply.Contains($selectedTweak)) {
                                Write-ColorText ($langStrings.regItemRemoved -f $description) $Red
                                $tweaksToApply.Remove($selectedTweak)
                            } else {
                                Write-ColorText ($langStrings.regItemAdded -f $description) $Green
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

    $selectedUpdateOptions = $tweaksToApply | Where-Object { $_.ID -like "WU_*" }
    if ($selectedUpdateOptions.Count -gt 1) {
        $firstUpdateOption = $selectedUpdateOptions[0]
        $langKey = "tweak_$($firstUpdateOption.ID)_desc"
        Write-ColorText ($langStrings.regWarnMultiUpdate -f $global:langStrings[$langKey]) $Yellow
        Start-Sleep -Seconds 3

        $otherTweaks = $tweaksToApply | Where-Object { $_.ID -notlike "WU_*" }
        $tweaksToApply.Clear()
        $tweaksToApply.AddRange($otherTweaks)
        $tweaksToApply.Add($firstUpdateOption)
    }

    $global:ScriptConfig.RegistryTweaks = $tweaksToApply.ID
    if ($tweaksToApply.Count -eq 0) {
        if ($script:runMode -eq 'MANUAL') {
            Write-ColorText $langStrings.regNothingSelected $Yellow
            Start-Sleep -Seconds 2
        }
        return
    }

    $softwareHiveLoaded = $false
    $userHiveLoaded = $false
    $systemHiveLoaded = $false
    try {
        Invoke-Reg -Arguments @('LOAD', 'HKLM\TEMP', (Join-Path $script:MountPath 'Windows\System32\config\SOFTWARE')) | Out-Null
        $softwareHiveLoaded = $true
        Invoke-Reg -Arguments @('LOAD', 'HKU\TEMP', (Join-Path $script:MountPath 'Users\Default\NTUSER.DAT')) | Out-Null
        $userHiveLoaded = $true
        Invoke-Reg -Arguments @('LOAD', 'HKLM\TEMPSYSTEM', (Join-Path $script:MountPath 'Windows\System32\config\SYSTEM')) | Out-Null
        $systemHiveLoaded = $true
        $script:OfflineControlSet = Get-OfflineCurrentControlSet
        $setupScriptContent = [System.Text.StringBuilder]::new()
        foreach ($tweak in $tweaksToApply) {
            $langKey = "tweak_$($tweak.ID)_desc"
            $description = $global:langStrings[$langKey]
            Write-ColorText ($langStrings.regApplying -f $description) $Yellow
            try {
                switch ($tweak.Action) {
                    "WU_Handler" {
                        $auPath = 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsUpdate\AU'
                        if (-not (Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }
                        if ($tweak.ID -eq 'WU_NotifyDownload') {
                            Set-ItemProperty -Path $auPath -Name 'AUOptions' -Value 2 -Type DWord -Force -ErrorAction Stop
                            Set-ItemProperty -Path $auPath -Name 'NoAutoUpdate' -Value 1 -Type DWord -Force -ErrorAction Stop
                        } else { # WU_NotifyInstall
                            Set-ItemProperty -Path $auPath -Name 'AUOptions' -Value 3 -Type DWord -Force -ErrorAction Stop
                            Set-ItemProperty -Path $auPath -Name 'NoAutoUpdate' -Value 0 -Type DWord -Force -ErrorAction Stop
                        }
                        Write-ColorText $langStrings.regSuccess $Green
                        break
                    }
                    "InlineScript" {
                        $previousErrorActionPreference = $ErrorActionPreference
                        try {
                            $ErrorActionPreference = 'Stop'
                            . $tweak.Code
                        } finally {
                            $ErrorActionPreference = $previousErrorActionPreference
                        }
                        Write-ColorText $langStrings.regSuccess $Green
                        break
                    }
                    "SetupScript" {
                        $setupScriptContent.AppendLine($tweak.Code) | Out-Null
                        Write-ColorText $langStrings.regQueuedForPostSetup $Cyan
                        break
                    }
                }
            } catch {
                $errorDetails = $_.Exception.Message
                if (-not [string]::IsNullOrWhiteSpace($_.InvocationInfo.PositionMessage)) {
                    $errorDetails += "`n$($_.InvocationInfo.PositionMessage)"
                }
                Write-ColorText ($langStrings.regFail -f $description, $errorDetails) $Red
                if ($script:runMode -eq 'AUTOMATIC') { throw }
            }
        }
        if ($setupScriptContent.Length -gt 0) {
            $setupScriptContent.AppendLine($finalSetupScript) | Out-Null
            $scriptsPath = Join-Path $script:MountPath 'Windows\Setup\Scripts'
            if (-not (Test-Path $scriptsPath)) {
                New-Item -ItemType Directory -Path $scriptsPath -Force | Out-Null
            }
            $postSetupScriptPath = Join-Path $scriptsPath "post-setup.ps1"
            $setupScriptContent.ToString() | Out-File -FilePath $postSetupScriptPath -Encoding utf8
            Write-ColorText $langStrings.regPostSetupScriptCreated $Green

            $desktopPath = Join-Path $script:MountPath 'Users\Default\Desktop'
            if (-not (Test-Path $desktopPath)) {
                New-Item -ItemType Directory -Path $desktopPath -Force | Out-Null
            }
            $scriptPathInWindows = '%SystemRoot%\Setup\Scripts\post-setup.ps1'
            $requiresNetwork = @($tweaksToApply | Where-Object { $_.Action -eq 'SetupScript' -and $_.RequiresNetwork }).Count -gt 0
            $networkCheck = if ($requiresNetwork) { $langStrings.regRunnerNetworkCheck } else { '' }
            $batContent = $langStrings.regRunnerBatBody -f $scriptPathInWindows, $networkCheck
            $batFileName = $langStrings.regRunnerBatTitle
            $batContent | Out-File -FilePath (Join-Path $desktopPath $batFileName) -Encoding OEM
            Write-ColorText ($langStrings.regManualRunnerCreated -f $batFileName) $Green
        }
    } catch {
        Write-ColorText ($langStrings.regErrorGeneral -f $_) $Red
        $registryFailure = $_
    } finally {
        Write-ColorText $langStrings.regSaving $Yellow
        [gc]::Collect(); [gc]::WaitForPendingFinalizers()
        if ($systemHiveLoaded) {
            try { Invoke-Reg -Arguments @('UNLOAD', 'HKLM\TEMPSYSTEM') | Out-Null } catch { Write-ColorText $_ $Red }
        }
        if ($userHiveLoaded) {
            try { Invoke-Reg -Arguments @('UNLOAD', 'HKU\TEMP') | Out-Null } catch { Write-ColorText $_ $Red }
        }
        if ($softwareHiveLoaded) {
            try { Invoke-Reg -Arguments @('UNLOAD', 'HKLM\TEMP') | Out-Null } catch { Write-ColorText $_ $Red }
        }
        Write-ColorText $langStrings.regComplete $Green
        if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script $langStrings.regReturnToMenu }
    }
    if ($null -ne $registryFailure -and $script:runMode -eq 'AUTOMATIC') {
        throw $registryFailure
    }
}

# Gets provisioned AppX package identities from the mounted image.
function Get-ProvisionedAppPackages {
    param([Parameter(Mandatory)][string]$MountPath)

    $dismOutput = Invoke-Dism -Arguments @("/Image:$MountPath", '/Get-ProvisionedAppxPackages') -PassThru -Quiet
    $packages = [System.Collections.Generic.List[object]]::new()
    $packageBlocks = ($dismOutput -join "`n") -split '(?:\r?\n){2,}'
    foreach ($block in $packageBlocks) {
        $displayNameMatch = [regex]::Match($block, "DisplayName\s*:\s*(.+)")
        $packageNameMatch = [regex]::Match($block, "PackageName\s*:\s*(.+)")
        if ($displayNameMatch.Success -and $packageNameMatch.Success) {
            $packages.Add([PSCustomObject]@{
                DisplayName = $displayNameMatch.Groups[1].Value.Trim()
                PackageName = $packageNameMatch.Groups[1].Value.Trim()
            })
        }
    }
    return @($packages | Sort-Object DisplayName)
}

# Gets a list of provisioned AppX packages and allows the user to remove them.
function Remove-WindowsApps {
    $mountPath = $script:MountPath
    $packagesToRemove = [System.Collections.Generic.List[string]]::new()
    $selectorsToRemove = [System.Collections.Generic.List[string]]::new()
    try {
        . (Join-Path $PSScriptRoot "src/app-exclusion-list.ps1")
    } catch {
        Write-ColorText $langStrings.appExclusionDefNotFound $Red
        if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
        return
    }

    if ($script:runMode -eq 'AUTOMATIC' -and $global:ScriptConfig.RemovedAppSelectors.Count -gt 0) {
        Write-ColorText $langStrings.appRemoveFromConfig $Cyan
        $allAppPackages = @(Get-ProvisionedAppPackages -MountPath $mountPath)
        foreach ($selector in [string[]]$global:ScriptConfig.RemovedAppSelectors) {
            $matches = @($allAppPackages | Where-Object { $_.DisplayName -ieq $selector })
            if ($matches.Count -ne 1) {
                throw "Provisioned app selector '$selector' resolved to $($matches.Count) packages. Expected exactly one."
            }
            foreach ($pattern in $appExclusionList) {
                if ($matches[0].PackageName -like $pattern) {
                    throw "Refusing to remove protected provisioned app selector: $selector"
                }
            }
            $selectorsToRemove.Add($selector)
            $packagesToRemove.Add($matches[0].PackageName)
        }
    } elseif ($script:runMode -eq 'AUTOMATIC' -and $global:ScriptConfig.RemovedApps.Count -gt 0) {
        Write-ColorText $langStrings.appRemoveFromConfig $Cyan
        foreach ($packageName in [string[]]$global:ScriptConfig.RemovedApps) {
            $isExcluded = $false
            foreach ($pattern in $appExclusionList) {
                if ($packageName -like $pattern) {
                    $isExcluded = $true
                    break
                }
            }
            if (-not $isExcluded) {
                $packagesToRemove.Add($packageName)
            }
        }
    } else {
        Write-ColorText $langStrings.appRemoveGettingList $Yellow
        try {
            $allAppPackages = @(Get-ProvisionedAppPackages -MountPath $mountPath)
        } catch {
            Write-ColorText ($langStrings.appRemoveGetListError -f $_) $Red
            if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
            return
        }
        Write-ColorText $langStrings.appRemoveExcludingCritical $Cyan
        $filteredAppPackages = $allAppPackages | Where-Object {
            $currentPackage = $_
            $isExcluded = $false
            foreach ($pattern in $appExclusionList) {
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
            $selectorsToRemove.AddRange([string[]]$filteredAppPackages.DisplayName)
        } else {
            foreach ($selectedIndex in $selection) {
                $packagesToRemove.Add($filteredAppPackages[$selectedIndex - 1].PackageName)
                $selectorsToRemove.Add($filteredAppPackages[$selectedIndex - 1].DisplayName)
            }
        }
        $global:ScriptConfig.RemovedApps = $packagesToRemove
        $global:ScriptConfig.RemovedAppSelectors = $selectorsToRemove
    }
    if ($packagesToRemove.Count -eq 0) {
        if ($script:runMode -eq 'MANUAL') {
            Write-ColorText $langStrings.appRemoveNothingSelected $Yellow
            Start-Sleep -Seconds 2
        }
        return
    }
    $removalErrors = [System.Collections.Generic.List[string]]::new()
    Write-ColorText "`n$($langStrings.appRemoveStarting)" $Green
    foreach ($packageName in $packagesToRemove) {
        Write-ColorText ($langStrings.appRemoveRemoving -f $packageName) $Yellow
        try {
            Invoke-Dism -Arguments @("/Image:$mountPath", '/Remove-ProvisionedAppxPackage', "/PackageName:$packageName") -Quiet
            Write-ColorText ($langStrings.appRemoveSuccess -f $packageName) $Green
        } catch {
            Write-ColorText ($langStrings.appRemoveError -f $packageName, $_) $Red
            $removalErrors.Add("$packageName`: $($_.Exception.Message)")
        }
    }
    if ($script:runMode -eq 'AUTOMATIC' -and $selectorsToRemove.Count -gt 0) {
        $remainingPackages = @(Get-ProvisionedAppPackages -MountPath $mountPath)
        $remainingSelectors = @($selectorsToRemove | Where-Object {
            $selector = $_
            $remainingPackages.DisplayName -icontains $selector
        })
        if ($remainingSelectors.Count -gt 0) {
            $removalErrors.Add("Selectors still present after removal: $($remainingSelectors -join ', ')")
        }
    }
    if ($script:runMode -eq 'AUTOMATIC' -and $removalErrors.Count -gt 0) {
        throw "Provisioned app removal validation failed: $($removalErrors -join '; ')"
    }
    Write-ColorText "`n$($langStrings.appRemoveComplete)" $Cyan
    if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
}

function Remove-WindowsCapabilities {
    . (Join-Path $PSScriptRoot 'src/capabilities.ps1')
    $capabilitiesToRemove = [System.Collections.Generic.List[object]]::new()

    if ($script:runMode -eq 'AUTOMATIC') {
        $selected = $global:ScriptConfig.RemovedCapabilities
        $capabilitiesToRemove.AddRange([object[]]@($allRemovableCapabilities | Where-Object { $selected -contains $_.Name }))
    } else {
        $menuOptions = @($allRemovableCapabilities | ForEach-Object { $global:langStrings["capability_$($_.ID)_desc"] })
        $selection = Get-UserChoice -Title $langStrings.capabilityRemoveTitle -Options $menuOptions -MultiSelect $true
        if ($selection -eq 'go_back' -or !$selection) { return }
        $selection | ForEach-Object { $capabilitiesToRemove.Add($allRemovableCapabilities[$_ - 1]) }
        $global:ScriptConfig.RemovedCapabilities = @($capabilitiesToRemove.Name)
    }

    foreach ($capability in $capabilitiesToRemove) {
        try {
            $info = Invoke-Dism -Arguments @("/Image:$($script:MountPath)", '/Get-CapabilityInfo', "/CapabilityName:$($capability.Name)") -PassThru -Quiet
            $state = (($info | Select-String '^\s*State\s*:').Line -split ':', 2)[1].Trim()
            if ($state -eq 'Installed') {
                Invoke-Dism -Arguments @("/Image:$($script:MountPath)", '/Remove-Capability', "/CapabilityName:$($capability.Name)") -Quiet
                Write-ColorText ($langStrings.capabilityRemoveSuccess -f $capability.Name) $Green
            } else {
                Write-ColorText ($langStrings.capabilityRemoveNoOp -f $capability.Name, $state) $Cyan
            }
        } catch {
            if ($capability.AllowAbsent -and $_.Exception.Message -match '0x800f080c|not found|unknown') {
                Write-ColorText ($langStrings.capabilityRemoveAbsent -f $capability.Name) $Cyan
            } else {
                Write-ColorText ($langStrings.capabilityRemoveError -f $capability.Name, $_.Exception.Message) $Red
                if ($script:runMode -eq 'AUTOMATIC') { throw }
            }
        }
    }
    if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
}

function Disable-WindowsFeatures {
    . (Join-Path $PSScriptRoot 'src/removable-features.ps1')
    $featuresToDisable = [System.Collections.Generic.List[object]]::new()

    if ($script:runMode -eq 'AUTOMATIC') {
        $selected = $global:ScriptConfig.DisabledFeatures
        $featuresToDisable.AddRange([object[]]@($allRemovableFeatures | Where-Object { $selected -contains $_.FeatureName }))
    } else {
        $menuOptions = @($allRemovableFeatures | ForEach-Object { $global:langStrings["disabledFeature_$($_.FeatureName)_desc"] })
        $selection = Get-UserChoice -Title $langStrings.disabledFeatureTitle -Options $menuOptions -MultiSelect $true
        if ($selection -eq 'go_back' -or !$selection) { return }
        $selection | ForEach-Object { $featuresToDisable.Add($allRemovableFeatures[$_ - 1]) }
        $global:ScriptConfig.DisabledFeatures = @($featuresToDisable.FeatureName)
    }

    foreach ($feature in $featuresToDisable) {
        try {
            $info = Invoke-Dism -Arguments @("/Image:$($script:MountPath)", '/Get-FeatureInfo', "/FeatureName:$($feature.FeatureName)") -PassThru -Quiet
            $state = (($info | Select-String '^\s*State\s*:').Line -split ':', 2)[1].Trim()
            if ($state -in @('Disabled with Payload Removed', 'Removed')) {
                Write-ColorText ($langStrings.disabledFeatureNoOp -f $feature.FeatureName, $state) $Cyan
            } else {
                Invoke-Dism -Arguments @("/Image:$($script:MountPath)", '/Disable-Feature', "/FeatureName:$($feature.FeatureName)", '/Remove', '/NoRestart') -Quiet
                Write-ColorText ($langStrings.disabledFeatureSuccess -f $feature.FeatureName) $Green
            }
        } catch {
            if ($feature.AllowAbsent -and $_.Exception.Message -match '0x800f080c|not found|unknown') {
                Write-ColorText ($langStrings.disabledFeatureAbsent -f $feature.FeatureName) $Cyan
            } else {
                Write-ColorText ($langStrings.disabledFeatureError -f $feature.FeatureName, $_.Exception.Message) $Red
                if ($script:runMode -eq 'AUTOMATIC') { throw }
            }
        }
    }
    if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
}

# Allows enabling optional Windows features based on definitions in an external file.
function Enable-Features {
    try {
        . (Join-Path $PSScriptRoot "src/features.ps1")
    } catch {
        Write-ColorText $langStrings.featureDefNotFound $Red
        Suspend-Script
        return
    }

    $featuresToEnable = [System.Collections.Generic.List[object]]::new()

    # Decide whether to run in automatic or manual mode
    if ($script:runMode -eq 'AUTOMATIC' -and $global:ScriptConfig.EnabledFeatures.Count -gt 0) {
        Write-ColorText $langStrings.featureEnableFromConfig $Cyan
        $selectedFeatureIDs = $global:ScriptConfig.EnabledFeatures
        $featuresToEnable.AddRange([object[]]@($allFeatures | Where-Object { $selectedFeatureIDs -contains $_.FeatureName }))
    } else { # Manual mode
        # Build menu options by fetching descriptions from the language file
        $menuOptions = ($allFeatures | ForEach-Object { $global:langStrings["feature_$($_.FeatureName)_desc"] }) + $langStrings.featureEnableApplyAll
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
        # Get the localized display name for the feature from the language file
        $featureNameDisplay = $global:langStrings["feature_$($feature.FeatureName)_desc"]
        Write-ColorText ($langStrings.featureEnableEnabling -f $featureNameDisplay) $Green

        try {
            $dismParams = @("/Image:$($script:MountPath)", "/Enable-Feature", "/FeatureName:$($feature.FeatureName)", "/All")
            if ($feature.Source) {
                $sourcePath = Join-Path $script:IsoContentPath $feature.Source
                $dismParams += @("/LimitAccess", "/Source:$sourcePath")
            }

            Invoke-Dism -Arguments $dismParams -Quiet
            Write-ColorText ($langStrings.featureEnableSuccess -f $featureNameDisplay) $Green
        } catch {
            Write-ColorText ($langStrings.featureEnableError -f $featureNameDisplay, $_.Exception.Message) $Red
            if ($script:runMode -eq 'AUTOMATIC') { throw }
        }
    }

    if ($script:runMode -ne 'AUTOMATIC') { Suspend-Script }
}

# Commits all changes, optimizes ALL WIM indexes, and creates the final bootable ISO file.
function Complete-Image {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        if ($Unattended) {
            throw "Specify -OutputIsoPath when using unattended mode."
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
            return $false
        }
        $Path = $SaveFileDialog.FileName
    }

    $outputIso = [System.IO.Path]::GetFullPath($Path)
    $workspaceRoot = $script:WorkingDirectory.TrimEnd('\') + '\'
    if ($outputIso.StartsWith($workspaceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "The output ISO path must be outside the WinISOUtil workspace: $outputIso"
    }
    $outputDirectory = Split-Path -Parent $outputIso
    if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
        throw "The output ISO directory does not exist: $outputDirectory"
    }
    Write-Host ($langStrings.completeOutputIsoPath -f $outputIso) -ForegroundColor Green
    Remove-Item -LiteralPath (Join-Path $script:MountPath 'dism.log') -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    $profileValidation = $null
    if ($Unattended) {
        Write-ColorText $langStrings.completeValidatingProfile $Yellow
        $profileValidation = Invoke-WinIsoUtilProfileValidation -MountPath $script:MountPath -Configuration $global:ScriptConfig -RepositoryRoot $PSScriptRoot -DismPath $global:dismPath
        if ($profileValidation.OverallStatus -ne 'Passed') {
            $failedMessages = @($profileValidation.FailedChecks | ForEach-Object { "$($_.Type)/$($_.Id): $($_.Message)" })
            throw "Offline profile validation failed: $($failedMessages -join '; ')"
        }
    }
    try {
        $dismPath = $global:dismPath
        $mountPath = $script:MountPath
        $completeUnmountFail = $langStrings.completeUnmountFail
        $commitScriptBlock = {
            & $using:dismPath /English /Unmount-Image "/MountDir:$using:mountPath" /Commit
            if ($LASTEXITCODE -ne 0) { throw ($using:completeUnmountFail -f $LASTEXITCODE) }
        }
        Invoke-LongRunningOperation -ScriptBlock $commitScriptBlock -Message $langStrings.longOpSavingImage
    } catch {
        Write-ColorText ($langStrings.completeSaveError -f $_) $Red
        throw $langStrings.completeFinalizeFail
    }

    try {
        $sourceWim = Join-Path $script:IsoContentPath 'sources\install.wim'
        $optimizedWim = Join-Path $script:IsoContentPath 'sources\install_optimized.wim'
        $imageInfo = Invoke-Dism -Arguments @('/Get-ImageInfo', "/ImageFile:$sourceWim") -PassThru -Quiet
        $indexes = $imageInfo | Where-Object { $_ -match "^\s*Index : \d+\s*$" } | ForEach-Object { ($_ -split ":")[1].Trim() }
        if ($indexes.Count -eq 0) { throw "No image indexes found." }

        if (-not $SkipWimOptimization) {
            $exportScriptBlock = {
                foreach ($index in $using:indexes) {
                    & $using:dismPath /English /Export-Image "/SourceImageFile:$using:sourceWim" "/SourceIndex:$index" "/DestinationImageFile:$using:optimizedWim" /Compress:maximum
                    if ($LASTEXITCODE -ne 0) { throw ("WIM optimization failed on index $index") }
                }
            }
            Invoke-LongRunningOperation -ScriptBlock $exportScriptBlock -Message $langStrings.longOpOptimizingWim

            Remove-Item -LiteralPath $sourceWim -Force -ErrorAction Stop
            Rename-Item -LiteralPath $optimizedWim -NewName "install.wim" -ErrorAction Stop
        }
    } catch {
        Write-ColorText ("WIM optimization failed: $_. Will use unoptimized file.") $Red
        if (Test-Path -LiteralPath $optimizedWim) { Remove-Item -LiteralPath $optimizedWim -Force }
    }

    Write-ColorText $langStrings.completeCreatingIso $Green
    try {
        $bootData = "2#p0,e,b$(Join-Path $script:IsoContentPath 'boot\etfsboot.com')#pEF,e,b$(Join-Path $script:IsoContentPath 'efi\microsoft\boot\efisys.bin')"
        & $global:oscdimgPath -m -o -u2 -udfver102 "-bootdata:$bootData" $script:IsoContentPath $outputIso

        if ($LASTEXITCODE -ne 0) { throw ("oscdimg Exit Code: $LASTEXITCODE") }

        if ($Unattended) {
            $reportPath = if ([string]::IsNullOrWhiteSpace($ValidationReportPath)) { "$outputIso.validation.json" } else { [System.IO.Path]::GetFullPath($ValidationReportPath) }
            Write-WinIsoUtilValidationReport -Validation $profileValidation -ConfigurationPath $script:ImportedConfigurationPath -IsoPath $outputIso -OutputPath $reportPath | Out-Null
            Write-ColorText ($langStrings.completeValidationReport -f $reportPath) $Green
        }
        Write-ColorText ($langStrings.completeIsoSuccess -f $outputIso) $Green
        Cleanup
        return $true
    } catch {
        Write-ColorText ($langStrings.completeIsoError -f $_) $Red
        Write-ColorText ($langStrings.completeFilesSaved -f $script:IsoContentPath) $Yellow
        return $false
    }
}

# Cleans up all temporary files, folders, and registry hives.
function Cleanup {
    $cleanupMsg = if ($null -ne $langStrings) { $langStrings.cleanupCleaning } else { "Cleaning up..." }
    Write-ColorText $cleanupMsg $Green
    [gc]::Collect(); [gc]::WaitForPendingFinalizers()
    try { & reg.exe UNLOAD HKU\TEMP 2>$null | Out-Null } catch {}
    try { & reg.exe UNLOAD HKLM\TEMP 2>$null | Out-Null } catch {}
    try { & reg.exe UNLOAD HKLM\TEMPSYSTEM 2>$null | Out-Null } catch {}
    if (-not (Test-OwnedWorkspace)) {
        Write-ColorText "Skipping filesystem cleanup because the workspace is not owned by WinISOUtil." $Yellow
        return
    }
    if (Test-Path -LiteralPath (Join-Path $script:MountPath 'Windows')) {
        $mountedMsg = if ($null -ne $langStrings) { $langStrings.cleanupImageMounted } else { "Discarding mounted image..." }
        Write-ColorText $mountedMsg $Yellow
        try {
            Invoke-Dism -Arguments @('/Unmount-Image', "/MountDir:$($script:MountPath)", '/Discard') -Quiet
        } catch {
            Write-ColorText "Mounted image could not be discarded. Workspace files were preserved: $_" $Red
            return
        }
    }
    try { Remove-OwnedWorkspaceItem -Path $script:IsoContentPath } catch { Write-ColorText $_ $Red }
    try { Remove-OwnedWorkspaceItem -Path $script:MountPath } catch { Write-ColorText $_ $Red }
    Remove-Item -LiteralPath $script:WorkspaceMarkerPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $script:WorkingDirectory -Force -ErrorAction SilentlyContinue
    $completeMsg = if ($null -ne $langStrings) { $langStrings.cleanupComplete } else { "Cleanup complete." }
    Write-ColorText $completeMsg $Green
}

# --- SCRIPT EXECUTION START ---

if (-not [string]::IsNullOrWhiteSpace($Language)) {
    $global:currentLanguage = $Language
} elseif ($Unattended) {
    $global:currentLanguage = 'en'
} else {
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
}

if ($Unattended) {
    if ([string]::IsNullOrWhiteSpace($IsoPath)) {
        throw "Specify -IsoPath when using unattended mode."
    }
    if ([string]::IsNullOrWhiteSpace($ConfigurationPath)) {
        throw "Specify -ConfigurationPath when using unattended mode."
    }
    if ([string]::IsNullOrWhiteSpace($OutputIsoPath)) {
        throw "Specify -OutputIsoPath when using unattended mode."
    }
}

try {
    . (Join-Path $PSScriptRoot "src/languages.ps1")
} catch {
    Write-ColorText "CRITICAL ERROR: languages.ps1 could not be loaded." $Red
    if (-not $Unattended) { Read-Host "Press Enter to exit." }
    exit 1
}

$global:dismPath = Find-DismPath
if (-not $global:dismPath) {
    Write-ColorText $langStrings.dismNotFoundExit $Red
    exit 1
}

$global:oscdimgPath = Find-Oscdimg
if (-not $global:oscdimgPath) {
    Show-Banner
    Write-ColorText $langStrings.oscdimgNotFoundTitle $Red
    Write-ColorText $langStrings.oscdimgNotFoundDesc1 $Cyan
    if (-not $Unattended) { Read-Host }
    exit 1
}

Show-Banner

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-ColorText $langStrings.scriptNotAdmin $Red
    if (-not $Unattended) { Start-Sleep -Seconds 5 }
    exit 1
}

if ([string]::IsNullOrWhiteSpace($IsoPath)) {
    Add-Type -AssemblyName System.Windows.Forms
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = $langStrings.scriptSelectIso
    $OpenFileDialog.Filter = "ISO files (*.iso)|*.iso"
    if ($OpenFileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host $langStrings.scriptIsoNotSelected -ForegroundColor Red
        exit
    }
    $IsoPath = $OpenFileDialog.FileName
}

if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf) -or [System.IO.Path]::GetExtension($IsoPath) -ine '.iso') {
    throw ($langStrings.scriptIsoInvalid -f $IsoPath)
}

$IsoPath = [System.IO.Path]::GetFullPath($IsoPath)
Write-Host ($langStrings.scriptIsoSelected -f $IsoPath) -ForegroundColor Green

Initialize-Environment
Copy-IsoFiles -IsoPath $IsoPath
if (-not $Unattended) {
    Remove-WindowsEditions
}
if (-not (Mount-WindowsImage -Index $EditionIndex)) {
    Write-ColorText $langStrings.scriptMountFail $Red
    Cleanup
    exit 1
}

if (-not [string]::IsNullOrWhiteSpace($UpdatesPath)) {
    Add-WindowsUpdates -Path $UpdatesPath
} elseif (-not $Unattended) {
    Show-Banner
    $updateChoice = Read-Host "$($langStrings.scriptPromptUpdate) "
    if ($updateChoice -ieq 'E' -or $updateChoice -ieq 'Y') { Add-WindowsUpdates }
}

if (-not [string]::IsNullOrWhiteSpace($DriversPath)) {
    Add-Drivers -Path $DriversPath
} elseif (-not $Unattended) {
    Show-Banner
    $driverChoice = Read-Host "$($langStrings.scriptPromptDriver) "
    if ($driverChoice -ieq 'E' -or $driverChoice -ieq 'Y') { Add-Drivers }
}

if (Import-Configuration -Path $ConfigurationPath) {
    $script:runMode = 'AUTOMATIC'
} elseif ($Unattended) {
    Write-ColorText $langStrings.importReadError $Red
    Cleanup
    exit 1
}

if ($script:runMode -eq 'AUTOMATIC') {
    Write-ColorText "`n$($langStrings.execAutoModeStarted)" $Cyan
    if ($global:ScriptConfig.ComponentServiceTweaks.Count -gt 0) { Set-ComponentsAndServices }
    if ($global:ScriptConfig.RegistryTweaks.Count -gt 0) { Set-Registry }
    if ($global:ScriptConfig.RemovedApps.Count -gt 0 -or $global:ScriptConfig.RemovedAppSelectors.Count -gt 0) { Remove-WindowsApps }
    if ($global:ScriptConfig.RemovedCapabilities.Count -gt 0) { Remove-WindowsCapabilities }
    if ($global:ScriptConfig.DisabledFeatures.Count -gt 0) { Disable-WindowsFeatures }
    if ($global:ScriptConfig.EnabledFeatures.Count -gt 0) { Enable-Features }
    Write-ColorText "`n$($langStrings.execAutoModeCompleted)" $Cyan

    if ($Unattended) {
        Write-ColorText $langStrings.execAutoCreateIso $Green
        if (Complete-Image -Path $OutputIsoPath) {
            $script:runMode = 'FINISHED'
        } else {
            exit 1
        }
    } else {
        $extraChoice = Read-Host "$($langStrings.execAutoPromptManual) "
        if ($extraChoice -ieq 'E' -or $extraChoice -ieq 'Y') {
            $script:runMode = 'MANUAL'
        } else {
            Write-ColorText $langStrings.execAutoCreateIso $Green
            Start-Sleep -Seconds 2
            if (Complete-Image -Path $OutputIsoPath) {
                $script:runMode = 'FINISHED'
            } else {
                $script:runMode = 'MANUAL'
            }
        }
    }
}

if ($script:runMode -eq 'MANUAL') {
    do {
        Clear-Host
        Show-Banner
        $menuOptions = @(
            $langStrings.mainMenu1, $langStrings.mainMenu2, $langStrings.mainMenu3,
            $langStrings.mainMenu4, $langStrings.mainMenu5, $langStrings.mainMenu6,
            $langStrings.mainMenu7, $langStrings.mainMenu8, $langStrings.mainMenu9,
            $langStrings.mainMenu10, $langStrings.mainMenu11
        )
        for($i=0; $i -lt $menuOptions.Length; $i++){
            $color = $White
            if($i -eq 8) { $color = $Cyan }
            if($i -eq 9) { $color = $Green }
            if($i -eq 10) { $color = $Red }
            Write-ColorText "$($i+1). $($menuOptions[$i])" $color
        }
        Write-Host ""
        $choice = Read-Host $langStrings.promptChoice
        switch ($choice) {
            "1" { Add-WindowsUpdates }
            "2" { Add-Drivers }
            "3" { Set-ComponentsAndServices }
            "4" { Set-Registry }
            "5" { Remove-WindowsApps }
            "6" { Remove-WindowsCapabilities }
            "7" { Disable-WindowsFeatures }
            "8" { Enable-Features }
            "9" { Export-Configuration }
            "10" { if (Complete-Image -Path $OutputIsoPath) { $choice = "exit" } }
            "11" { Cleanup; $choice = "exit" }
            default { Write-Host $langStrings.invalidChoice -ForegroundColor Red; Start-Sleep -Seconds 2 }
        }
    } while ($choice -ne "exit")
}

Write-ColorText $langStrings.finishMessage $Yellow
if (-not $Unattended) { Read-Host }
