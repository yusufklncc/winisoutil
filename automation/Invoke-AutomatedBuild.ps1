[CmdletBinding()]
param(
    [string]$SettingsPath,
    [string]$ToolsPinPath,
    [string[]]$TargetId,
    [switch]$DiscoverOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'modules\Automation.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'modules\UupDump.Provider.psm1')
Import-Module (Join-Path $PSScriptRoot 'modules\Profile.Validation.psm1') -Force

if ([string]::IsNullOrWhiteSpace($SettingsPath)) { $SettingsPath = Join-Path $PSScriptRoot 'settings.json' }
if ([string]::IsNullOrWhiteSpace($ToolsPinPath)) { $ToolsPinPath = Join-Path $PSScriptRoot 'tools.pin.json' }

$script:LogPath = $null
$script:CurrentRunStatePath = $null
$script:EventSource = 'WinISOUtil Automation'

function Write-AutomationLog {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ValidateSet('Information', 'Warning', 'Error')][string]$Level = 'Information'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Level.ToUpperInvariant(), $Message
    Write-Host $line
    if (-not [string]::IsNullOrWhiteSpace($script:LogPath)) {
        Add-Content -LiteralPath $script:LogPath -Value $line -Encoding utf8
    }
}

function Get-ErrorText {
    param([Parameter(Mandatory)]$ErrorRecord)

    $message = [string]$ErrorRecord.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = ($ErrorRecord | Out-String).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = $ErrorRecord.Exception.GetType().FullName
    }
    return $message
}

function Write-RunCheckpoint {
    param(
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$Phase,
        [string]$TargetId = '',
        [string]$Message = '',
        $Summary
    )

    if ([string]::IsNullOrWhiteSpace($script:CurrentRunStatePath)) { return }
    $checkpoint = [ordered]@{
        SchemaVersion = 1
        UpdatedAt     = (Get-Date).ToString('o')
        Status        = $Status
        Phase         = $Phase
        TargetId      = $TargetId
        Message       = $Message
        LogPath       = $script:LogPath
    }
    if ($null -ne $Summary) {
        $checkpoint.Summary = $Summary
    }
    Write-JsonAtomic -Value $checkpoint -Path $script:CurrentRunStatePath
}

function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)

    if ($Value -notmatch '[\s"]') { return $Value }
    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.Append('"')
    $backslashCount = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') {
            $backslashCount++
            continue
        }
        if ($character -eq '"') {
            [void]$builder.Append(('\' * (($backslashCount * 2) + 1)))
            [void]$builder.Append('"')
            $backslashCount = 0
            continue
        }
        if ($backslashCount -gt 0) {
            [void]$builder.Append(('\' * $backslashCount))
            $backslashCount = 0
        }
        [void]$builder.Append($character)
    }
    if ($backslashCount -gt 0) {
        [void]$builder.Append(('\' * ($backslashCount * 2)))
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-LoggedProcess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$TranscriptBasePath,
        [Parameter(Mandatory)][string]$Description
    )

    $transcriptDirectory = Split-Path -Parent $TranscriptBasePath
    New-Item -ItemType Directory -Path $transcriptDirectory -Force -ErrorAction Stop | Out-Null
    $stdoutPath = "$TranscriptBasePath.stdout.log"
    $stderrPath = "$TranscriptBasePath.stderr.log"
    $exitCodePath = "$TranscriptBasePath.exitcode.log"
    $wrapperPath = "$TranscriptBasePath.wrapper.ps1"
    [System.IO.File]::WriteAllText($stdoutPath, '')
    [System.IO.File]::WriteAllText($stderrPath, '')
    Remove-Item -LiteralPath $exitCodePath -Force -ErrorAction SilentlyContinue

    @'
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Executable,
    [Parameter(Mandatory)][string]$ExitCodePath,
    [Parameter(Mandatory)][string]$NativeWorkingDirectory,
    [Parameter(Mandatory)][string]$NativeArgumentsBase64
)

Set-Location -LiteralPath $NativeWorkingDirectory
$nativeArgumentsJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($NativeArgumentsBase64))
$NativeArgument = @($nativeArgumentsJson | ConvertFrom-Json)
& $Executable @NativeArgument
$nativeExitCode = $LASTEXITCODE
[System.IO.File]::WriteAllText($ExitCodePath, [string]$nativeExitCode)
exit $nativeExitCode
'@ | Out-File -LiteralPath $wrapperPath -Encoding ascii -Force

    $nativeArgumentsJson = ConvertTo-Json -InputObject @($Arguments) -Compress
    $nativeArgumentsBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($nativeArgumentsJson))
    $wrapperArguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $wrapperPath,
        '-Executable', $FilePath,
        '-ExitCodePath', $exitCodePath,
        '-NativeWorkingDirectory', $WorkingDirectory,
        '-NativeArgumentsBase64', $nativeArgumentsBase64
    )
    $argumentLine = (@($wrapperArguments | ForEach-Object { ConvertTo-NativeArgument -Value $_ }) -join ' ')
    $process = Start-Process -FilePath 'powershell.exe' `
        -ArgumentList $argumentLine `
        -WorkingDirectory $WorkingDirectory `
        -NoNewWindow `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru `
        -ErrorAction Stop

    $readers = @()
    try {
        foreach ($path in @($stdoutPath, $stderrPath)) {
            $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $readers += [System.IO.StreamReader]::new($stream)
        }
        do {
            foreach ($reader in $readers) {
                while (-not $reader.EndOfStream) {
                    Write-AutomationLog -Message ([string]$reader.ReadLine())
                }
            }
            if (-not $process.HasExited) { Start-Sleep -Milliseconds 500 }
            $process.Refresh()
        } while (-not $process.HasExited)
        $process.WaitForExit()
        $process.Refresh()
        foreach ($reader in $readers) {
            while (-not $reader.EndOfStream) {
                Write-AutomationLog -Message ([string]$reader.ReadLine())
            }
        }
        if (-not (Test-Path -LiteralPath $exitCodePath -PathType Leaf)) {
            throw "$Description exited without an available exit code. See $stdoutPath and $stderrPath."
        }
        $exitCode = 0
        $exitCodeText = (Get-Content -LiteralPath $exitCodePath -Raw -ErrorAction Stop).Trim()
        if (-not [int]::TryParse($exitCodeText, [ref]$exitCode)) {
            throw "$Description produced an invalid exit code '$exitCodeText'. See $stdoutPath and $stderrPath."
        }
        if ($exitCode -ne 0) {
            throw "$Description exited with code $exitCode. See $stdoutPath and $stderrPath."
        }
    } finally {
        foreach ($reader in $readers) { $reader.Dispose() }
        $process.Dispose()
        Remove-Item -LiteralPath $wrapperPath -Force -ErrorAction SilentlyContinue
    }
}

function Write-AutomationEvent {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Information', 'Warning', 'Error')][string]$Level = 'Information'
    )

    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($script:EventSource)) {
            New-EventLog -LogName Application -Source $script:EventSource -ErrorAction Stop
        }
        Write-EventLog -LogName Application -Source $script:EventSource -EventId 1000 -EntryType $Level -Message $Message -ErrorAction Stop
    } catch {
        Write-AutomationLog -Level Warning -Message "Could not write Windows Event Log entry: $($_.Exception.Message)"
    }
}

function Send-WebhookSummary {
    param(
        [string]$WebhookUrl,
        [Parameter(Mandatory)]$Summary
    )

    if ([string]::IsNullOrWhiteSpace($WebhookUrl)) { return }
    $uri = [uri]$WebhookUrl
    if ($uri.Scheme -ne 'https') {
        throw "WebhookUrl must use HTTPS."
    }
    try {
        Invoke-RestMethod -Uri $uri -Method Post -ContentType 'application/json' -Body ($Summary | ConvertTo-Json -Depth 8) -ErrorAction Stop | Out-Null
    } catch {
        Write-AutomationLog -Level Warning -Message "Webhook notification failed: $($_.Exception.Message)"
    }
}

function Get-IntegerSetting {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Minimum,
        [Parameter(Mandatory)][int]$Maximum
    )

    $value = 0
    if (-not [int]::TryParse([string](Get-RequiredProperty -Object $Object -Name $Name), [ref]$value) -or
        $value -lt $Minimum -or $value -gt $Maximum) {
        throw "$Name must be an integer between $Minimum and $Maximum."
    }
    return $value
}

function Get-ConfigurationSchemaVersion {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "WinISOUtil configuration file not found: $Path"
    }
    $configuration = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($configuration.PSObject.Properties.Name -notcontains 'SchemaVersion') {
        return 1
    }
    return [int]$configuration.SchemaVersion
}

function Assert-AutomationProfileSchema {
    param([Parameter(Mandatory)][string]$Path)

    $schemaVersion = Get-ConfigurationSchemaVersion -Path $Path
    if ($schemaVersion -notin @(2, 3)) {
        throw "Zero-touch automation requires a SchemaVersion 2 or 3 WinISOUtil profile: $Path"
    }
    if ($schemaVersion -eq 2) {
        Write-AutomationLog -Level Warning -Message "SchemaVersion 2 profile remains supported, but migration to SchemaVersion 3 is recommended: $Path"
    }
    return $schemaVersion
}

function Read-AutomationSettings {
    param([Parameter(Mandatory)][string]$Path)

    $settingsFile = Resolve-AutomationPath -Path $Path -BaseDirectory (Get-Location).ProviderPath
    if (-not (Test-Path -LiteralPath $settingsFile -PathType Leaf)) {
        throw "Settings file not found: $settingsFile"
    }
    $baseDirectory = Split-Path -Parent $settingsFile
    $settings = Get-Content -LiteralPath $settingsFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ([int](Get-RequiredProperty -Object $settings -Name 'SchemaVersion') -ne 2) {
        throw "Automation settings must use SchemaVersion 2."
    }
    if ([string](Get-RequiredProperty -Object $settings -Name 'ToolLanguage') -notin @('tr', 'en')) {
        throw "ToolLanguage must be tr or en."
    }
    if ([string](Get-RequiredProperty -Object $settings -Name 'Architecture') -ne 'amd64') {
        throw "Only amd64 automation is currently supported."
    }
    if ([string](Get-RequiredProperty -Object $settings -Name 'Edition') -cne 'PROFESSIONAL') {
        throw "Only PROFESSIONAL automation is currently supported."
    }
    $initialFeatureVersion = [string](Get-RequiredProperty -Object $settings -Name 'InitialFeatureVersion')
    if ($initialFeatureVersion -notmatch '^\d{2}H[12]$') {
        throw "InitialFeatureVersion must use a value such as 25H2."
    }

    $paths = Get-RequiredProperty -Object $settings -Name 'Paths'
    $resolvedPaths = @{}
    foreach ($name in @('Tools', 'Cache', 'Staging', 'Output', 'Logs', 'Working', 'State')) {
        $resolvedPaths[$name] = Resolve-AutomationPath -Path ([string](Get-RequiredProperty -Object $paths -Name $name)) -BaseDirectory $baseDirectory
    }
    $defaultConfigurationPath = Resolve-AutomationPath -Path ([string](Get-RequiredProperty -Object $settings -Name 'DefaultConfigurationPath')) -BaseDirectory $baseDirectory
    $defaultProfileSchemaVersion = Assert-AutomationProfileSchema -Path $defaultConfigurationPath

    $targetIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $targets = [System.Collections.Generic.List[object]]::new()
    foreach ($target in @((Get-RequiredProperty -Object $settings -Name 'Targets'))) {
        $id = [string](Get-RequiredProperty -Object $target -Name 'Id')
        $locale = [string](Get-RequiredProperty -Object $target -Name 'Locale')
        Assert-SafeIdentifier -Value $id -Name 'Target Id'
        if ($locale -notmatch '^[a-z]{2}-[a-z]{2}$') {
            throw "Target locale must use a value such as tr-tr or en-us: $locale"
        }
        if (-not $targetIds.Add($id)) {
            throw "Duplicate target Id: $id"
        }
        $configurationPath = $defaultConfigurationPath
        if ($target.PSObject.Properties.Name -contains 'ConfigurationPath' -and
            -not [string]::IsNullOrWhiteSpace([string]$target.ConfigurationPath)) {
            $configurationPath = Resolve-AutomationPath -Path ([string]$target.ConfigurationPath) -BaseDirectory $baseDirectory
        }
        $profileSchemaVersion = if ($configurationPath -eq $defaultConfigurationPath) {
            $defaultProfileSchemaVersion
        } else {
            Assert-AutomationProfileSchema -Path $configurationPath
        }
        $targets.Add([PSCustomObject]@{
            Id                = $id
            Locale            = $locale.ToLowerInvariant()
            ConfigurationPath = $configurationPath
            ProfileSchemaVersion = $profileSchemaVersion
        })
    }
    if ($targets.Count -eq 0) {
        throw "At least one target must be configured."
    }

    return [PSCustomObject]@{
        File                   = $settingsFile
        Directory              = $baseDirectory
        ToolLanguage           = [string]$settings.ToolLanguage
        Architecture           = [string]$settings.Architecture
        Edition                = [string]$settings.Edition
        InitialFeatureVersion  = $initialFeatureVersion
        FeatureReleaseHoldDays = Get-IntegerSetting -Object $settings -Name 'FeatureReleaseHoldDays' -Minimum 0 -Maximum 365
        RetentionCount         = Get-IntegerSetting -Object $settings -Name 'RetentionCount' -Minimum 1 -Maximum 20
        MinimumFreeSpaceGiB    = if ($settings.PSObject.Properties.Name -contains 'MinimumFreeSpaceGiB') {
            Get-IntegerSetting -Object $settings -Name 'MinimumFreeSpaceGiB' -Minimum 20 -Maximum 1024
        } else {
            50
        }
        WebhookUrl             = if ($settings.PSObject.Properties.Name -contains 'WebhookUrl') { [string]$settings.WebhookUrl } else { '' }
        Paths                  = $resolvedPaths
        Targets                = @($targets)
    }
}

function Read-State {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$InitialFeatureVersion
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    return [PSCustomObject]@{
        SchemaVersion  = 1
        ActiveFeature  = $InitialFeatureVersion
        PendingFeature = $null
        Targets        = [PSCustomObject]@{}
    }
}

function Select-CandidateForRun {
    param(
        [Parameter(Mandatory)]$LatestCandidate,
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][int]$HoldDays,
        [Parameter(Mandatory)][string]$ApiCacheDirectory
    )

    function Get-FeatureOrdinal {
        param([Parameter(Mandatory)][string]$FeatureVersion)

        $match = [regex]::Match($FeatureVersion, '^(?<year>\d{2})H(?<half>[12])$')
        if (-not $match.Success) {
            throw "Unsupported feature release format: $FeatureVersion"
        }
        return ([int]$match.Groups['year'].Value * 2) + [int]$match.Groups['half'].Value
    }

    if ([string]::IsNullOrWhiteSpace([string]$State.ActiveFeature)) {
        $State.ActiveFeature = $LatestCandidate.FeatureVersion
        $State.PendingFeature = $null
        return $LatestCandidate
    }
    if ([string]$State.ActiveFeature -eq $LatestCandidate.FeatureVersion) {
        $State.PendingFeature = $null
        return $LatestCandidate
    }
    if ((Get-FeatureOrdinal -FeatureVersion $LatestCandidate.FeatureVersion) -lt
        (Get-FeatureOrdinal -FeatureVersion ([string]$State.ActiveFeature))) {
        Write-AutomationLog -Level Warning -Message "Ignoring older feature release $($LatestCandidate.FeatureVersion). Continuing with $($State.ActiveFeature)."
        return Get-LatestUupRetailCandidate -Architecture $LatestCandidate.Architecture -CacheDirectory $ApiCacheDirectory -FeatureVersion ([string]$State.ActiveFeature)
    }

    $now = Get-Date
    if ($null -eq $State.PendingFeature -or [string]$State.PendingFeature.FeatureVersion -ne $LatestCandidate.FeatureVersion) {
        $State.PendingFeature = [PSCustomObject]@{
            FeatureVersion = $LatestCandidate.FeatureVersion
            FirstSeenAt    = $now.ToString('o')
        }
    }
    $firstSeen = [datetime]$State.PendingFeature.FirstSeenAt
    if ($firstSeen -le $now.AddDays(-$HoldDays)) {
        $State.ActiveFeature = $LatestCandidate.FeatureVersion
        $State.PendingFeature = $null
        return $LatestCandidate
    }

    Write-AutomationLog -Message "Holding feature release $($LatestCandidate.FeatureVersion) until $($firstSeen.AddDays($HoldDays).ToString('o')). Continuing with $($State.ActiveFeature)."
    return Get-LatestUupRetailCandidate -Architecture $LatestCandidate.Architecture -CacheDirectory $ApiCacheDirectory -FeatureVersion ([string]$State.ActiveFeature)
}

function Get-ManifestEntries {
    param([Parameter(Mandatory)]$Manifest)

    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($property in $Manifest.files.PSObject.Properties) {
        $name = [string]$property.Name
        $file = $property.Value
        if ([System.IO.Path]::GetFileName($name) -ne $name -or $name -match '[\\/]') {
            throw "UUP manifest contains an unsafe filename: $name"
        }
        $sha256 = [string]$file.sha256
        $size = 0L
        if ($sha256 -notmatch '^[A-Fa-f0-9]{64}$' -or -not [long]::TryParse([string]$file.size, [ref]$size) -or $size -le 0) {
            throw "UUP manifest metadata is incomplete for: $name"
        }
        $entries.Add([PSCustomObject]@{
            Name   = $name
            Sha256 = $sha256.ToUpperInvariant()
            Size   = $size
            Url    = [uri][string]$file.url
        })
    }
    return @($entries)
}

function Merge-ManifestEntries {
    param([Parameter(Mandatory)][object[]]$Entries)

    $byName = @{}
    foreach ($entry in $Entries) {
        $key = $entry.Name.ToLowerInvariant()
        if ($byName.ContainsKey($key)) {
            if ($byName[$key].Sha256 -ne $entry.Sha256) {
                throw "UUP manifests contain conflicting files: $($entry.Name)"
            }
            continue
        }
        $byName[$key] = $entry
    }
    return @($byName.Values | Sort-Object Name)
}

function Get-CachedPayload {
    param(
        [Parameter(Mandatory)]$Entry,
        [Parameter(Mandatory)][string]$PayloadCacheDirectory
    )

    $directory = Join-Path $PayloadCacheDirectory $Entry.Sha256.Substring(0, 2).ToLowerInvariant()
    $path = Join-Path $directory $Entry.Sha256.ToLowerInvariant()
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $item = Get-Item -LiteralPath $path
        if ($item.Length -eq $Entry.Size -and (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ieq $Entry.Sha256) {
            return $path
        }
        Remove-Item -LiteralPath $path -Force -ErrorAction Stop
    }
    Write-AutomationLog -Message "Downloading UUP payload: $($Entry.Name)"
    Invoke-ResumablePayloadDownload -Uri $Entry.Url -DestinationPath $path -ExpectedSize $Entry.Size -ExpectedSha256 $Entry.Sha256
    return $path
}

function Materialize-UupFiles {
    param(
        [Parameter(Mandatory)][object[]]$Entries,
        [Parameter(Mandatory)][string]$PayloadCacheDirectory,
        [Parameter(Mandatory)][string]$DestinationDirectory
    )

    New-Item -ItemType Directory -Path $DestinationDirectory -Force -ErrorAction Stop | Out-Null
    Write-AutomationLog -Message "Materializing $($Entries.Count) UUP payload files into $DestinationDirectory."
    $processed = 0
    foreach ($entry in $Entries) {
        $cachedPath = Get-CachedPayload -Entry $entry -PayloadCacheDirectory $PayloadCacheDirectory
        Copy-OrLinkFile -Source $cachedPath -Destination (Join-Path $DestinationDirectory $entry.Name)
        $processed++
        if ($processed % 250 -eq 0) {
            Write-AutomationLog -Message "Materialized $processed of $($Entries.Count) UUP payload files."
        }
    }
    Write-AutomationLog -Message "Completed UUP payload materialization: $processed files."
}

function Materialize-TargetUupFiles {
    param(
        [Parameter(Mandatory)]$Candidate,
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)]$Settings,
        [Parameter(Mandatory)][string]$ApiCacheDirectory,
        [Parameter(Mandatory)][string]$DestinationDirectory
    )

    $lastError = $null
    for ($attempt = 0; $attempt -lt 2; $attempt++) {
        try {
            $forceRefresh = $attempt -gt 0
            $professionalManifest = Get-UupManifest -Uuid $Candidate.Uuid -Locale $Target.Locale -Edition $Settings.Edition -CacheDirectory $ApiCacheDirectory -ForceRefresh:$forceRefresh
            $appManifest = Get-UupManifest -Uuid $Candidate.Uuid -Locale 'neutral' -Edition 'APP' -CacheDirectory $ApiCacheDirectory -ForceRefresh:$forceRefresh
            $entries = Merge-ManifestEntries -Entries @(
                @(Get-ManifestEntries -Manifest $professionalManifest)
                @(Get-ManifestEntries -Manifest $appManifest)
            )
            Write-AutomationLog -Message "Resolved UUP manifests for $($Target.Id): $($entries.Count) unique payload entries."
            Materialize-UupFiles -Entries $entries -PayloadCacheDirectory (Join-Path $Settings.Paths.Cache 'payloads') -DestinationDirectory $DestinationDirectory
            return
        } catch {
            $lastError = $_
            if ($attempt -eq 0) {
                Write-AutomationLog -Level Warning -Message "Refreshing UUP manifests after payload failure: $($_.Exception.Message)"
            }
        }
    }
    throw $lastError
}

function Set-IniValue {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )

    $pattern = "(?m)^(\s*$([regex]::Escape($Name))\s*=).*$"
    if ($Content -notmatch $pattern) {
        throw "Converter INI key was not found: $Name"
    }
    return [regex]::Replace($Content, $pattern, "`${1}$Value")
}

function Get-InstalledTools {
    param(
        [Parameter(Mandatory)][string]$ToolsRoot,
        [Parameter(Mandatory)][string]$PinPath
    )

    if (-not (Test-Path -LiteralPath $PinPath -PathType Leaf)) {
        throw "Tools pin file not found: $PinPath"
    }
    $pin = Get-Content -LiteralPath $PinPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $installDirectory = Join-Path $ToolsRoot 'uup-converter'
    $markerPath = Join-Path $installDirectory '.winisoutil-uup-tools.json'
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        throw "UUP converter is not installed. Run Install-UupTools.ps1 first."
    }
    $marker = Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ([string]$marker.ArchiveSha256 -ine [string]$pin.ArchiveSha256 -or
        [string]$marker.CommandRelativePath -ne [string]$pin.CommandRelativePath) {
        throw "Installed UUP converter does not match tools.pin.json. Run Install-UupTools.ps1."
    }
    return [PSCustomObject]@{
        Directory           = $installDirectory
        CommandRelativePath = [string]$marker.CommandRelativePath
    }
}

function Assert-FullBuildPrerequisites {
    param(
        [Parameter(Mandatory)][string]$StagingRoot,
        [Parameter(Mandatory)][string]$ConverterWorkingRoot,
        [Parameter(Mandatory)][string[]]$RequiredSpacePaths,
        [Parameter(Mandatory)][int]$MinimumFreeSpaceGiB
    )

    $isAdministrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdministrator) {
        throw "The full build must run from an elevated PowerShell session or the registered SYSTEM task."
    }
    foreach ($command in @('dism.exe', 'cmd.exe', 'powershell.exe')) {
        if ($null -eq (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "Required command was not found: $command"
        }
    }
    $oscdimgCandidates = @(
        'C:\Program Files (x86)\Windows Kits\11\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe',
        'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe'
    )
    if (@($oscdimgCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }).Count -eq 0) {
        throw "Windows ADK Deployment Tools were not found. Install oscdimg.exe before starting a full build."
    }
    $mountedImages = & dism.exe /English /Get-MountedWimInfo 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Could not inspect mounted WIM images before starting the build.`n$($mountedImages -join "`n")"
    }
    $stagingPrefix = [System.IO.Path]::GetFullPath($StagingRoot).TrimEnd('\') + '\'
    if (($mountedImages -join "`n").IndexOf($stagingPrefix, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "A stale converter WIM mount exists under the configured staging directory. Unmount it with DISM /Discard before retrying."
    }
    $converterDriveRoot = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($ConverterWorkingRoot))
    foreach ($path in @(
        (Join-Path $converterDriveRoot 'W10UIuup'),
        (Join-Path $converterDriveRoot 'MountUUP')
    )) {
        if (Test-Path -LiteralPath $path) {
            throw "A stale UUP converter temporary directory exists: $path. Inspect active DISM mounts, then remove the directory before retrying."
        }
    }
    $requiredBytes = [long]$MinimumFreeSpaceGiB * 1GB
    foreach ($root in @($RequiredSpacePaths | ForEach-Object { [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($_)) } | Select-Object -Unique)) {
        $drive = [System.IO.DriveInfo]::new($root)
        if ($drive.AvailableFreeSpace -lt $requiredBytes) {
            $availableGiB = [math]::Round($drive.AvailableFreeSpace / 1GB, 2)
            throw "Insufficient free space on $root Expected at least $MinimumFreeSpaceGiB GiB before a full build, found $availableGiB GiB."
        }
    }
}

function Invoke-UupConversion {
    param(
        [Parameter(Mandatory)]$Tools,
        [Parameter(Mandatory)][string]$UupDirectory,
        [Parameter(Mandatory)][string]$ConverterWorkDirectory,
        [Parameter(Mandatory)][string]$TranscriptBasePath
    )

    Write-AutomationLog -Message "Preparing UUP converter workspace: $ConverterWorkDirectory"
    Copy-Item -LiteralPath $Tools.Directory -Destination $ConverterWorkDirectory -Recurse -Force -ErrorAction Stop
    Write-AutomationLog -Message "UUP converter tools copied to staging."
    $commandPath = Join-Path $ConverterWorkDirectory $Tools.CommandRelativePath
    $converterRoot = Split-Path -Parent $commandPath
    $iniPath = Join-Path $converterRoot 'ConvertConfig.ini'
    if (-not (Test-Path -LiteralPath $iniPath -PathType Leaf)) {
        throw "Converter configuration was not found: $iniPath"
    }
    Write-AutomationLog -Message "Configuring UUP converter INI: $iniPath"
    $ini = Get-Content -LiteralPath $iniPath -Raw -ErrorAction Stop
    foreach ($option in @{
        AutoStart = '1'; AddUpdates = '1'; Cleanup = '0'; ResetBase = '0'; SkipWinRE = '0'
        AutoExit = '1'; SkipApps = '0'; AppsLevel = '0'; StubAppsFull = '1'; CustomList = '0'
    }.GetEnumerator()) {
        $ini = Set-IniValue -Content $ini -Name $option.Key -Value $option.Value
    }
    $ini | Out-File -LiteralPath $iniPath -Encoding ascii -Force
    Write-AutomationLog -Message "UUP converter INI configured."

    $before = @(Get-ChildItem -LiteralPath $ConverterWorkDirectory -Filter '*.iso' -File -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object { $_.FullName })
    Write-AutomationLog -Message "Starting UUP conversion."
    Invoke-LoggedProcess `
        -FilePath 'cmd.exe' `
        -Arguments @('/d', '/c', "`"$commandPath`" `"$UupDirectory`"") `
        -WorkingDirectory $converterRoot `
        -TranscriptBasePath $TranscriptBasePath `
        -Description 'UUP converter'
    $created = @(Get-ChildItem -LiteralPath $ConverterWorkDirectory -Filter '*.iso' -File -Recurse -ErrorAction Stop |
        Where-Object { $_.FullName -notin $before } |
        Sort-Object LastWriteTimeUtc -Descending)
    if ($created.Count -ne 1) {
        throw "Expected one converted ISO, found $($created.Count)."
    }
    return $created[0].FullName
}

function Invoke-DismChecked {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $output = & dism.exe /English @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "DISM failed with exit code $LASTEXITCODE.`n$($output -join "`n")"
    }
    return @($output)
}

function Assert-WindowsIso {
    param(
        [Parameter(Mandatory)][string]$IsoPath,
        [Parameter(Mandatory)][string]$ExpectedBuild,
        [Parameter(Mandatory)][string]$ExpectedLocale,
        [Parameter(Mandatory)][string]$ValidationDirectory,
        [string]$ConfigurationPath,
        [string]$ValidationReportPath
    )

    New-Item -ItemType Directory -Path $ValidationDirectory -Force -ErrorAction Stop | Out-Null
    $mountedIso = $null
    $imageMounted = $false
    $imageMountDirectory = Join-Path $ValidationDirectory 'image'
    New-Item -ItemType Directory -Path $imageMountDirectory -Force -ErrorAction Stop | Out-Null
    try {
        $mountedIso = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
        $volume = $mountedIso | Get-Volume -ErrorAction Stop
        $root = "$($volume.DriveLetter):\"
        foreach ($relativePath in @('sources\boot.wim', 'boot\etfsboot.com', 'efi\microsoft\boot\efisys.bin')) {
            if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Leaf)) {
                throw "ISO is missing required file: $relativePath"
            }
        }
        $installImage = @('sources\install.wim', 'sources\install.esd') |
            ForEach-Object { Join-Path $root $_ } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace([string]$installImage)) {
            throw "ISO does not contain install.wim or install.esd."
        }
        $summary = Invoke-DismChecked -Arguments @('/Get-WimInfo', "/WimFile:$installImage")
        if (@($summary | Where-Object { $_ -match '^\s*Index\s*:\s*\d+\s*$' }).Count -ne 1) {
            throw "ISO must contain exactly one Windows edition."
        }
        $info = Invoke-DismChecked -Arguments @('/Get-WimInfo', "/WimFile:$installImage", '/Index:1')
        if (($info -join "`n") -notmatch '(?im)^\s*Edition\s*:\s*Professional\s*$') {
            throw "ISO edition is not Professional."
        }
        $expectedBuildParts = $ExpectedBuild.Split('.')
        if ($expectedBuildParts.Count -ne 2 -or
            ($info -join "`n") -notmatch "(?im)^\s*Version\s*:\s*10\.0\.$([regex]::Escape($expectedBuildParts[0]))\s*$" -or
            ($info -join "`n") -notmatch "(?im)^\s*ServicePack Build\s*:\s*$([regex]::Escape($expectedBuildParts[1]))\s*$") {
            throw "ISO build does not match selected UUP build: $ExpectedBuild"
        }
        $escapedLocale = [regex]::Escape($ExpectedLocale)
        if (($info -join "`n") -notmatch "(?im)(^\s*Default Language\s*:\s*$escapedLocale\s*$|^\s*$escapedLocale\s+\(Default\)\s*$)") {
            throw "ISO default language does not match target locale: $ExpectedLocale"
        }

        Invoke-DismChecked -Arguments @('/Mount-Image', "/ImageFile:$installImage", '/Index:1', "/MountDir:$imageMountDirectory", '/ReadOnly') | Out-Null
        $imageMounted = $true
        if (-not (Test-Path -LiteralPath (Join-Path $imageMountDirectory 'Windows\System32\Recovery\Winre.wim') -PathType Leaf)) {
            throw "ISO image does not contain Windows RE."
        }
        $apps = Invoke-DismChecked -Arguments @("/Image:$imageMountDirectory", '/Get-ProvisionedAppxPackages')
        foreach ($requiredApp in @('Microsoft.SecHealthUI', 'Microsoft.WindowsStore', 'Microsoft.DesktopAppInstaller')) {
            if (($apps -join "`n") -notmatch [regex]::Escape($requiredApp)) {
                throw "ISO image is missing required provisioned app: $requiredApp"
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($ConfigurationPath)) {
            $configuration = Get-Content -LiteralPath $ConfigurationPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            $profileValidation = Invoke-WinIsoUtilProfileValidation `
                -MountPath $imageMountDirectory `
                -Configuration $configuration `
                -RepositoryRoot ([System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))) `
                -DismPath 'dism.exe'
            if ([string]::IsNullOrWhiteSpace($ValidationReportPath)) {
                $ValidationReportPath = "$IsoPath.validation.json"
            }
            Write-WinIsoUtilValidationReport `
                -Validation $profileValidation `
                -ConfigurationPath $ConfigurationPath `
                -IsoPath $IsoPath `
                -OutputPath $ValidationReportPath | Out-Null
            if ($profileValidation.OverallStatus -ne 'Passed') {
                $failedMessages = @($profileValidation.FailedChecks | ForEach-Object { "$($_.Type)/$($_.Id): $($_.Message)" })
                throw "Offline profile validation failed: $($failedMessages -join '; ')"
            }
        }
    } finally {
        if ($imageMounted) {
            try { Invoke-DismChecked -Arguments @('/Unmount-Image', "/MountDir:$imageMountDirectory", '/Discard') | Out-Null } catch { Write-AutomationLog -Level Warning -Message $_.Exception.Message }
        }
        if ($null -ne $mountedIso) {
            Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

function Get-AssembledIsoCachePaths {
    param(
        [Parameter(Mandatory)]$Settings,
        [Parameter(Mandatory)]$Candidate,
        [Parameter(Mandatory)]$Target
    )

    $directory = Join-Path $Settings.Paths.Cache "assembled\$($Candidate.Uuid)\$($Target.Id)"
    return [PSCustomObject]@{
        Directory = $directory
        Marker    = Join-Path $directory '.winisoutil-assembled-source.json'
        Iso       = Join-Path $directory 'source.iso'
        Manifest  = Join-Path $directory 'source.iso.json'
    }
}

function Initialize-AssembledIsoCacheDirectory {
    param(
        [Parameter(Mandatory)]$Paths,
        [Parameter(Mandatory)]$Candidate,
        [Parameter(Mandatory)]$Target
    )

    New-Item -ItemType Directory -Path $Paths.Directory -Force -ErrorAction Stop | Out-Null
    if (Test-Path -LiteralPath $Paths.Marker -PathType Leaf) {
        $marker = Get-Content -LiteralPath $Paths.Marker -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ([string]$marker.Type -ne 'WinISOUtilAssembledSource' -or
            [string]$marker.Uuid -ne [string]$Candidate.Uuid -or
            [string]$marker.TargetId -ne [string]$Target.Id) {
            throw "Assembled source cache ownership marker is invalid: $($Paths.Directory)"
        }
        return
    }
    if (@(Get-ChildItem -LiteralPath $Paths.Directory -Force -ErrorAction Stop).Count -gt 0) {
        throw "Refusing to claim a non-empty assembled source cache directory: $($Paths.Directory)"
    }
    Write-JsonAtomic -Value ([ordered]@{
        Type     = 'WinISOUtilAssembledSource'
        Uuid     = $Candidate.Uuid
        TargetId = $Target.Id
    }) -Path $Paths.Marker
}

function Publish-AssembledIsoCache {
    param(
        [Parameter(Mandatory)]$Settings,
        [Parameter(Mandatory)]$Candidate,
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][string]$SourceIso
    )

    $paths = Get-AssembledIsoCachePaths -Settings $Settings -Candidate $Candidate -Target $Target
    Initialize-AssembledIsoCacheDirectory -Paths $paths -Candidate $Candidate -Target $Target
    $sourceSha256 = (Get-FileHash -LiteralPath $SourceIso -Algorithm SHA256).Hash
    if ([System.IO.Path]::GetFullPath($SourceIso) -ne [System.IO.Path]::GetFullPath($paths.Iso)) {
        Move-Item -LiteralPath $SourceIso -Destination $paths.Iso -Force -ErrorAction Stop
    }
    Write-JsonAtomic -Value ([ordered]@{
        SchemaVersion  = 1
        Uuid           = $Candidate.Uuid
        FeatureVersion = $Candidate.FeatureVersion
        Build          = $Candidate.Build
        TargetId       = $Target.Id
        Locale         = $Target.Locale
        SourceIsoSha256 = $sourceSha256
        CachedAt       = (Get-Date).ToString('o')
    }) -Path $paths.Manifest
    return $paths.Iso
}

function Get-CachedAssembledIso {
    param(
        [Parameter(Mandatory)]$Settings,
        [Parameter(Mandatory)]$Candidate,
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][string]$ValidationDirectory
    )

    $paths = Get-AssembledIsoCachePaths -Settings $Settings -Candidate $Candidate -Target $Target
    if (-not (Test-Path -LiteralPath $paths.Manifest -PathType Leaf) -or
        -not (Test-Path -LiteralPath $paths.Iso -PathType Leaf)) {
        return $null
    }
    Initialize-AssembledIsoCacheDirectory -Paths $paths -Candidate $Candidate -Target $Target
    $manifest = Get-Content -LiteralPath $paths.Manifest -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ([string]$manifest.Uuid -ne [string]$Candidate.Uuid -or
        [string]$manifest.Build -ne [string]$Candidate.Build -or
        [string]$manifest.TargetId -ne [string]$Target.Id -or
        [string]$manifest.Locale -ne [string]$Target.Locale) {
        throw "Assembled source cache metadata does not match the selected target: $($paths.Directory)"
    }
    $actualSha256 = (Get-FileHash -LiteralPath $paths.Iso -Algorithm SHA256).Hash
    if ($actualSha256 -ine [string]$manifest.SourceIsoSha256) {
        throw "Assembled source cache SHA-256 validation failed: $($paths.Iso)"
    }
    Write-AutomationLog -Message "Reusing cached assembled source ISO for $($Target.Id): $($paths.Iso)"
    Assert-WindowsIso -IsoPath $paths.Iso -ExpectedBuild $Candidate.Build -ExpectedLocale $Target.Locale -ValidationDirectory $ValidationDirectory
    return $paths.Iso
}

function Find-RecoverableStagedIso {
    param(
        [Parameter(Mandatory)]$Settings,
        [Parameter(Mandatory)]$Candidate,
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][string]$ValidationDirectory
    )

    $recoverable = [System.Collections.Generic.List[object]]::new()
    foreach ($runDirectory in @(Get-ChildItem -LiteralPath $Settings.Paths.Staging -Directory -ErrorAction SilentlyContinue)) {
        $targetStage = Join-Path $runDirectory.FullName $Target.Id
        if (-not (Test-Path -LiteralPath (Join-Path $targetStage '.winisoutil-staging.json') -PathType Leaf)) { continue }
        $converterDirectory = Join-Path $targetStage 'converter'
        foreach ($iso in @(Get-ChildItem -LiteralPath $converterDirectory -Filter '*.iso' -File -Recurse -ErrorAction SilentlyContinue)) {
            $recoverable.Add([PSCustomObject]@{ Iso = $iso; TargetStage = $targetStage })
        }
    }
    foreach ($item in @($recoverable | Sort-Object { $_.Iso.LastWriteTimeUtc } -Descending)) {
        Write-AutomationLog -Message "Validating recoverable staged source ISO for $($Target.Id): $($item.Iso.FullName)"
        try {
            Assert-WindowsIso -IsoPath $item.Iso.FullName -ExpectedBuild $Candidate.Build -ExpectedLocale $Target.Locale -ValidationDirectory $ValidationDirectory
            return $item
        } catch {
            Write-AutomationLog -Level Warning -Message "Ignoring staged ISO that failed validation: $(Get-ErrorText -ErrorRecord $_)"
        }
    }
    return $null
}

function Remove-AssembledIsoCache {
    param(
        [Parameter(Mandatory)]$Settings,
        [Parameter(Mandatory)]$Candidate,
        [Parameter(Mandatory)]$Target
    )

    $paths = Get-AssembledIsoCachePaths -Settings $Settings -Candidate $Candidate -Target $Target
    if (-not (Test-Path -LiteralPath $paths.Directory -PathType Container)) { return }
    $resolvedRoot = [System.IO.Path]::GetFullPath((Join-Path $Settings.Paths.Cache 'assembled')).TrimEnd('\') + '\'
    $resolvedDirectory = [System.IO.Path]::GetFullPath($paths.Directory)
    if (-not $resolvedDirectory.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $paths.Marker -PathType Leaf)) {
        throw "Refusing to clean an unowned assembled source cache directory: $resolvedDirectory"
    }
    Remove-Item -LiteralPath $resolvedDirectory -Recurse -Force -ErrorAction Stop
}

function Remove-ExpiredOutputs {
    param(
        [Parameter(Mandatory)][string]$TargetOutputDirectory,
        [Parameter(Mandatory)][int]$RetentionCount
    )

    $markerPath = Join-Path $TargetOutputDirectory '.winisoutil-output.json'
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        throw "Refusing retention cleanup for an unowned output directory: $TargetOutputDirectory"
    }
    $isoFiles = @(Get-ChildItem -LiteralPath $TargetOutputDirectory -Filter '*.iso' -File | Sort-Object LastWriteTimeUtc -Descending)
    foreach ($iso in @($isoFiles | Select-Object -Skip $RetentionCount)) {
        Remove-Item -LiteralPath $iso.FullName -Force -ErrorAction Stop
        Remove-Item -LiteralPath "$($iso.FullName).json" -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath "$($iso.FullName).validation.json" -Force -ErrorAction SilentlyContinue
    }
}

function Initialize-TargetOutputDirectory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$TargetId
    )

    $markerPath = Join-Path $Path '.winisoutil-output.json'
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
    }
    if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        $marker = Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ([string]$marker.Type -ne 'WinISOUtilOutput' -or [string]$marker.TargetId -ne $TargetId) {
            throw "Output directory ownership marker is invalid: $Path"
        }
        return
    }
    if (@(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop).Count -gt 0) {
        throw "Refusing to claim a non-empty output directory: $Path"
    }
    @{ Type = 'WinISOUtilOutput'; TargetId = $TargetId } | ConvertTo-Json | Out-File -LiteralPath $markerPath -Encoding utf8 -Force
}

function Remove-OwnedTargetStaging {
    param(
        [Parameter(Mandatory)][string]$TargetStage,
        [Parameter(Mandatory)][string]$StagingRoot
    )

    $resolvedRoot = [System.IO.Path]::GetFullPath($StagingRoot).TrimEnd('\') + '\'
    $resolvedTarget = [System.IO.Path]::GetFullPath($TargetStage)
    if (-not $resolvedTarget.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean staging outside the configured root: $resolvedTarget"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $resolvedTarget '.winisoutil-staging.json') -PathType Leaf)) {
        throw "Refusing to clean an unowned staging directory: $resolvedTarget"
    }
    Remove-Item -LiteralPath $resolvedTarget -Recurse -Force -ErrorAction Stop
    $runDirectory = Split-Path -Parent $resolvedTarget
    if ((Test-Path -LiteralPath $runDirectory -PathType Container) -and
        @(Get-ChildItem -LiteralPath $runDirectory -Force -ErrorAction Stop).Count -eq 0) {
        Remove-Item -LiteralPath $runDirectory -Force -ErrorAction Stop
    }
}

function Invoke-WinIsoUtil {
    param(
        [Parameter(Mandatory)]$Settings,
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][string]$SourceIso,
        [Parameter(Mandatory)][string]$OutputIso,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$TranscriptBasePath
    )

    $scriptPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\winisoutil.ps1'))
    $arguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath,
        '-Unattended', '-Language', $Settings.ToolLanguage,
        '-IsoPath', $SourceIso, '-ConfigurationPath', $Target.ConfigurationPath,
        '-EditionIndex', '1', '-OutputIsoPath', $OutputIso, '-ValidationReportPath', "$OutputIso.validation.json", '-WorkingDirectory', $WorkingDirectory
    )
    Write-AutomationLog -Message "Starting WinISOUtil for $($Target.Id)."
    Invoke-LoggedProcess `
        -FilePath 'powershell.exe' `
        -Arguments $arguments `
        -WorkingDirectory ([System.IO.Path]::GetDirectoryName($scriptPath)) `
        -TranscriptBasePath $TranscriptBasePath `
        -Description 'WinISOUtil'
}

$mutex = $null
$hasMutex = $false
$settings = $null
$installedTools = $null
$summary = [ordered]@{
    StartedAt = (Get-Date).ToString('o')
    Status    = 'failed'
    Candidate = $null
    Targets   = @()
}
try {
    $settings = Read-AutomationSettings -Path $SettingsPath
    foreach ($directory in $settings.Paths.Values) {
        New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
    }
    $script:LogPath = Join-Path $settings.Paths.Logs ("automated-build-{0}.log" -f (Get-Date).ToString('yyyy-MM-dd-HHmmss'))
    $script:CurrentRunStatePath = Join-Path $settings.Paths.State 'current-run.json'
    Write-AutomationLog -Message 'Starting multi-locale UUP automation.'
    Write-RunCheckpoint -Status 'running' -Phase 'starting' -Summary $summary

    $mutex = [System.Threading.Mutex]::new($false, 'Global\WinISOUtil-UUP-Automation')
    $hasMutex = $mutex.WaitOne(0)
    if (-not $hasMutex) {
        throw "Another WinISOUtil UUP automation run is already active."
    }
    if (-not $DiscoverOnly) {
        Assert-FullBuildPrerequisites `
            -StagingRoot $settings.Paths.Staging `
            -ConverterWorkingRoot $settings.Paths.Staging `
            -RequiredSpacePaths @($settings.Paths.Cache, $settings.Paths.Staging, $settings.Paths.Output, $settings.Paths.Working) `
            -MinimumFreeSpaceGiB $settings.MinimumFreeSpaceGiB
        $installedTools = Get-InstalledTools -ToolsRoot $settings.Paths.Tools -PinPath (Resolve-AutomationPath -Path $ToolsPinPath -BaseDirectory (Get-Location).ProviderPath)
    }

    $statePath = Join-Path $settings.Paths.State 'automation-state.json'
    $state = Read-State -Path $statePath -InitialFeatureVersion $settings.InitialFeatureVersion
    $apiCache = Join-Path $settings.Paths.Cache 'api'
    $latestCandidate = Get-LatestUupRetailCandidate -Architecture $settings.Architecture -CacheDirectory $apiCache
    $candidate = Select-CandidateForRun -LatestCandidate $latestCandidate -State $state -HoldDays $settings.FeatureReleaseHoldDays -ApiCacheDirectory $apiCache
    Write-JsonAtomic -Value $state -Path $statePath
    $summary.Candidate = $candidate
    Write-AutomationLog -Message "Selected Retail UUP: $($candidate.Title) [$($candidate.Uuid)]"
    Write-RunCheckpoint -Status 'running' -Phase 'candidate-selected' -Summary $summary

    $selectedTargets = @($settings.Targets)
    if (@($TargetId).Count -gt 0) {
        foreach ($requestedTargetId in $TargetId) {
            Assert-SafeIdentifier -Value $requestedTargetId -Name 'TargetId'
            if ($requestedTargetId -notin @($settings.Targets | ForEach-Object { $_.Id })) {
                throw "Requested TargetId is not configured: $requestedTargetId"
            }
        }
        $selectedTargets = @($settings.Targets | Where-Object { $_.Id -in $TargetId })
    }

    foreach ($target in $selectedTargets) {
        $result = [ordered]@{ Id = $target.Id; Locale = $target.Locale; Status = 'failed'; Message = '' }
        try {
            Write-RunCheckpoint -Status 'running' -Phase 'target-discovery' -TargetId $target.Id -Summary $summary
            if ($candidate.Languages -notcontains $target.Locale) {
                throw "Locale is not available for selected UUP candidate: $($target.Locale)"
            }
            $editions = Get-UupEditions -Uuid $candidate.Uuid -Locale $target.Locale -CacheDirectory $apiCache
            if ($editions.editionList -notcontains $settings.Edition) {
                throw "Edition $($settings.Edition) is not available for locale $($target.Locale)."
            }
            if ($DiscoverOnly) {
                $result.Status = 'discovered'
                $result.Message = 'Eligible target.'
                continue
            }

            $configSha256 = (Get-FileHash -LiteralPath $target.ConfigurationPath -Algorithm SHA256).Hash
            $targetOutputDirectory = Join-Path $settings.Paths.Output $target.Id
            Initialize-TargetOutputDirectory -Path $targetOutputDirectory -TargetId $target.Id
            $outputName = "Windows11-Pro-$($target.Locale)-$($candidate.FeatureVersion)-$($candidate.Build)-by-WinISOUtil.iso"
            $finalOutput = Join-Path $targetOutputDirectory $outputName
            if (Test-Path -LiteralPath $finalOutput -PathType Leaf) {
                $result.Status = 'noop'
                $result.Message = "Output already exists: $finalOutput"
                continue
            }
            $legacyOutput = Join-Path $targetOutputDirectory "Windows11-Pro-$($target.Locale)-$($candidate.FeatureVersion)-$($candidate.Build)-custom.iso"
            if (Test-Path -LiteralPath $legacyOutput -PathType Leaf) {
                $result.Status = 'noop'
                $result.Message = "Legacy output already exists: $legacyOutput"
                continue
            }

            $runId = [guid]::NewGuid().ToString('N')
            $targetStage = Join-Path $settings.Paths.Staging "$runId\$($target.Id)"
            $uupDirectory = Join-Path $targetStage 'UUPs'
            $converterWork = Join-Path $targetStage 'converter'
            $validationDirectory = Join-Path $targetStage 'validation'
            New-Item -ItemType Directory -Path $targetStage -Force -ErrorAction Stop | Out-Null
            @{ Type = 'WinISOUtilStaging'; TargetId = $target.Id } | ConvertTo-Json | Out-File -LiteralPath (Join-Path $targetStage '.winisoutil-staging.json') -Encoding utf8 -Force
            $transcriptPrefix = Join-Path $settings.Paths.Logs ("automated-build-{0}-{1}-{2}" -f (Get-Date).ToString('yyyy-MM-dd-HHmmss'), $runId, $target.Id)

            Write-RunCheckpoint -Status 'running' -Phase 'source-cache-validation' -TargetId $target.Id -Summary $summary
            $sourceIso = Get-CachedAssembledIso -Settings $settings -Candidate $candidate -Target $target -ValidationDirectory (Join-Path $validationDirectory 'cached-source')
            if ([string]::IsNullOrWhiteSpace([string]$sourceIso)) {
                Write-RunCheckpoint -Status 'running' -Phase 'staging-recovery' -TargetId $target.Id -Summary $summary
                $recovered = Find-RecoverableStagedIso -Settings $settings -Candidate $candidate -Target $target -ValidationDirectory (Join-Path $validationDirectory 'recovered-source')
                if ($null -ne $recovered) {
                    Write-AutomationLog -Message "Recovering staged source ISO for $($target.Id)."
                    $sourceIso = Publish-AssembledIsoCache -Settings $settings -Candidate $candidate -Target $target -SourceIso $recovered.Iso.FullName
                    Remove-OwnedTargetStaging -TargetStage $recovered.TargetStage -StagingRoot $settings.Paths.Staging
                }
            }
            if ([string]::IsNullOrWhiteSpace([string]$sourceIso)) {
                Write-RunCheckpoint -Status 'running' -Phase 'payload-materialization' -TargetId $target.Id -Summary $summary
                Materialize-TargetUupFiles -Candidate $candidate -Target $target -Settings $settings -ApiCacheDirectory $apiCache -DestinationDirectory $uupDirectory
                Write-RunCheckpoint -Status 'running' -Phase 'uup-conversion' -TargetId $target.Id -Summary $summary
                $sourceIso = Invoke-UupConversion -Tools $installedTools -UupDirectory $uupDirectory -ConverterWorkDirectory $converterWork -TranscriptBasePath "$transcriptPrefix-converter"
                Write-RunCheckpoint -Status 'running' -Phase 'source-validation' -TargetId $target.Id -Summary $summary
                Assert-WindowsIso -IsoPath $sourceIso -ExpectedBuild $candidate.Build -ExpectedLocale $target.Locale -ValidationDirectory (Join-Path $validationDirectory 'source')
                $sourceIso = Publish-AssembledIsoCache -Settings $settings -Candidate $candidate -Target $target -SourceIso $sourceIso
            }
            $sourceSha256 = (Get-FileHash -LiteralPath $sourceIso -Algorithm SHA256).Hash

            $stagedFinalIso = Join-Path $targetStage $outputName
            $workDirectory = Join-Path $settings.Paths.Working $target.Id
            Write-RunCheckpoint -Status 'running' -Phase 'customization' -TargetId $target.Id -Summary $summary
            Invoke-WinIsoUtil -Settings $settings -Target $target -SourceIso $sourceIso -OutputIso $stagedFinalIso -WorkingDirectory $workDirectory -TranscriptBasePath "$transcriptPrefix-winisoutil"
            Write-RunCheckpoint -Status 'running' -Phase 'final-validation' -TargetId $target.Id -Summary $summary
            $stagedValidationReport = "$stagedFinalIso.validation.json"
            Assert-WindowsIso -IsoPath $stagedFinalIso -ExpectedBuild $candidate.Build -ExpectedLocale $target.Locale -ValidationDirectory (Join-Path $validationDirectory 'final') -ConfigurationPath $target.ConfigurationPath -ValidationReportPath $stagedValidationReport
            $finalSha256 = (Get-FileHash -LiteralPath $stagedFinalIso -Algorithm SHA256).Hash
            $validationReportSha256 = (Get-FileHash -LiteralPath $stagedValidationReport -Algorithm SHA256).Hash
            Move-Item -LiteralPath $stagedFinalIso -Destination $finalOutput -ErrorAction Stop
            Move-Item -LiteralPath $stagedValidationReport -Destination "$finalOutput.validation.json" -ErrorAction Stop

            $manifest = [ordered]@{
                SchemaVersion       = 1
                TargetId            = $target.Id
                Locale              = $target.Locale
                Uuid                = $candidate.Uuid
                FeatureVersion      = $candidate.FeatureVersion
                Build               = $candidate.Build
                ConfigurationSha256 = $configSha256
                ProfileSchemaVersion = $target.ProfileSchemaVersion
                SourceIsoSha256     = $sourceSha256
                FinalIsoSha256      = $finalSha256
                ValidationReportSha256 = $validationReportSha256
                CompletedAt         = (Get-Date).ToString('o')
            }
            Write-JsonAtomic -Value $manifest -Path "$finalOutput.json"
            Remove-ExpiredOutputs -TargetOutputDirectory $targetOutputDirectory -RetentionCount $settings.RetentionCount
            Remove-AssembledIsoCache -Settings $settings -Candidate $candidate -Target $target
            Remove-OwnedTargetStaging -TargetStage $targetStage -StagingRoot $settings.Paths.Staging
            $result.Status = 'success'
            $result.Message = $finalOutput
        } catch {
            $result.Message = Get-ErrorText -ErrorRecord $_
            Write-AutomationLog -Level Error -Message "Target $($target.Id) failed: $($result.Message)"
        } finally {
            $summary.Targets += [PSCustomObject]$result
            Write-RunCheckpoint -Status 'running' -Phase 'target-completed' -TargetId $target.Id -Message $result.Message -Summary $summary
        }
    }

    if ($DiscoverOnly) {
        $summary.Status = if (@($summary.Targets | Where-Object Status -eq 'failed').Count -eq 0) { 'discovered' } else { 'partial-failure' }
    } elseif (@($summary.Targets | Where-Object Status -eq 'failed').Count -eq 0) {
        $summary.Status = 'success'
    } elseif (@($summary.Targets | Where-Object Status -in @('success', 'noop')).Count -gt 0) {
        $summary.Status = 'partial-failure'
    } else {
        $summary.Status = 'failed'
    }
} catch {
    $summary.Status = 'failed'
    $summary.Error = Get-ErrorText -ErrorRecord $_
    Write-AutomationLog -Level Error -Message $summary.Error
} finally {
    $summary.CompletedAt = (Get-Date).ToString('o')
    if ($hasMutex) { $mutex.ReleaseMutex() }
    if ($null -ne $mutex) { $mutex.Dispose() }
    if ($null -ne $settings) {
        Write-JsonAtomic -Value $summary -Path (Join-Path $settings.Paths.State 'last-run.json')
        Write-RunCheckpoint -Status 'completed' -Phase 'completed' -Message $summary.Status -Summary $summary
        Send-WebhookSummary -WebhookUrl $settings.WebhookUrl -Summary $summary
    }
    $level = if ($summary.Status -in @('success', 'discovered')) { 'Information' } elseif ($summary.Status -eq 'partial-failure') { 'Warning' } else { 'Error' }
    Write-AutomationEvent -Level $level -Message ($summary | ConvertTo-Json -Depth 8 -Compress)
}

if ($summary.Status -in @('success', 'discovered')) { exit 0 }
if ($summary.Status -eq 'partial-failure') { exit 2 }
exit 1
