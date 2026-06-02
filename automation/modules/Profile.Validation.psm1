Set-StrictMode -Version Latest

function ConvertTo-WinIsoUtilStringArray {
    param([AllowNull()]$Value, [string]$Field = 'configuration property')

    if ($null -eq $Value) { return @() }
    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($Value)) {
        if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) {
            throw "$Field must contain non-empty strings only."
        }
        $result.Add($item.Trim())
    }
    return [string[]]$result.ToArray()
}

function Get-WinIsoUtilPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        $DefaultValue = $null
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $DefaultValue }
    return $property.Value
}

function Get-WinIsoUtilDefinitions {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

    . (Join-Path $RepositoryRoot 'src\app-exclusion-list.ps1')
    . (Join-Path $RepositoryRoot 'src\features.ps1')
    . (Join-Path $RepositoryRoot 'src\components.ps1')
    . (Join-Path $RepositoryRoot 'src\tweaks.ps1')
    . (Join-Path $RepositoryRoot 'src\capabilities.ps1')
    . (Join-Path $RepositoryRoot 'src\removable-features.ps1')

    return [PSCustomObject]@{
        ProtectedAppSelectors = @($appExclusionList)
        EnabledFeatures = @($allFeatures)
        ComponentServiceTweaks = @($allComponentTweaks)
        RegistryTweaks = @($allTweaks)
        RemovedCapabilities = @($allRemovableCapabilities)
        DisabledFeatures = @($allRemovableFeatures)
    }
}

function Assert-WinIsoUtilAllowedValues {
    param(
        [Parameter(Mandatory = $true)][string]$Field,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Values,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$AllowedValues
    )

    $unknown = @($Values | Where-Object { $_ -notin $AllowedValues })
    if ($unknown.Count -gt 0) {
        throw "Unsupported $Field value(s): $($unknown -join ', ')"
    }
}

function ConvertTo-ValidatedWinIsoUtilConfiguration {
    param(
        [Parameter(Mandatory = $true)]$Configuration,
        [Parameter(Mandatory = $true)][string]$RepositoryRoot
    )

    $definitions = Get-WinIsoUtilDefinitions -RepositoryRoot $RepositoryRoot
    $schemaVersion = [int](Get-WinIsoUtilPropertyValue -Object $Configuration -Name 'SchemaVersion' -DefaultValue 1)
    if ($schemaVersion -notin @(1, 2, 3)) {
        throw "Unsupported WinISOUtil profile SchemaVersion: $schemaVersion"
    }

    $removedApps = @(ConvertTo-WinIsoUtilStringArray (Get-WinIsoUtilPropertyValue $Configuration 'RemovedApps') 'RemovedApps')
    $removedAppSelectors = @(ConvertTo-WinIsoUtilStringArray (Get-WinIsoUtilPropertyValue $Configuration 'RemovedAppSelectors') 'RemovedAppSelectors')
    $removedCapabilities = @(ConvertTo-WinIsoUtilStringArray (Get-WinIsoUtilPropertyValue $Configuration 'RemovedCapabilities') 'RemovedCapabilities')
    $disabledFeatures = @(ConvertTo-WinIsoUtilStringArray (Get-WinIsoUtilPropertyValue $Configuration 'DisabledFeatures') 'DisabledFeatures')
    $registryTweaks = @(ConvertTo-WinIsoUtilStringArray (Get-WinIsoUtilPropertyValue $Configuration 'RegistryTweaks') 'RegistryTweaks')
    $enabledFeatures = @(ConvertTo-WinIsoUtilStringArray (Get-WinIsoUtilPropertyValue $Configuration 'EnabledFeatures') 'EnabledFeatures')
    $componentServiceTweaks = @(ConvertTo-WinIsoUtilStringArray (Get-WinIsoUtilPropertyValue $Configuration 'ComponentServiceTweaks') 'ComponentServiceTweaks')
    $legacyMappings = [System.Collections.Generic.List[string]]::new()

    foreach ($removableFeature in $definitions.DisabledFeatures) {
        if ($removableFeature.LegacyComponentId -and $removableFeature.LegacyComponentId -in $componentServiceTweaks) {
            $disabledFeatures += $removableFeature.FeatureName
            $componentServiceTweaks = @($componentServiceTweaks | Where-Object { $_ -ne $removableFeature.LegacyComponentId })
            $legacyMappings.Add("$($removableFeature.LegacyComponentId)->$($removableFeature.FeatureName)")
        }
    }

    $removedApps = @($removedApps | Sort-Object -Unique)
    $removedAppSelectors = @($removedAppSelectors | Sort-Object -Unique)
    $removedCapabilities = @($removedCapabilities | Sort-Object -Unique)
    $disabledFeatures = @($disabledFeatures | Sort-Object -Unique)
    $registryTweaks = @($registryTweaks | Sort-Object -Unique)
    $enabledFeatures = @($enabledFeatures | Sort-Object -Unique)
    $componentServiceTweaks = @($componentServiceTweaks | Sort-Object -Unique)

    if ($schemaVersion -ge 2 -and $removedApps.Count -gt 0) {
        throw 'SchemaVersion 2 and 3 profiles must use RemovedAppSelectors instead of versioned RemovedApps.'
    }
    foreach ($packageName in $removedApps) {
        if ($packageName -cnotmatch '^[A-Za-z0-9._~\-]+$') {
            throw "Invalid provisioned AppX package name: $packageName"
        }
    }
    foreach ($selector in $removedAppSelectors) {
        if ($selector -cnotmatch '^[A-Za-z0-9._~\-]+$') {
            throw "Invalid provisioned AppX selector: $selector"
        }
    }

    Assert-WinIsoUtilAllowedValues 'RemovedCapabilities' $removedCapabilities @($definitions.RemovedCapabilities.Name)
    Assert-WinIsoUtilAllowedValues 'DisabledFeatures' $disabledFeatures @($definitions.DisabledFeatures.FeatureName)
    Assert-WinIsoUtilAllowedValues 'RegistryTweaks' $registryTweaks @($definitions.RegistryTweaks.ID)
    Assert-WinIsoUtilAllowedValues 'EnabledFeatures' $enabledFeatures @($definitions.EnabledFeatures.FeatureName)
    Assert-WinIsoUtilAllowedValues 'ComponentServiceTweaks' $componentServiceTweaks @($definitions.ComponentServiceTweaks.ID)

    $protectedSelectors = @($definitions.ProtectedAppSelectors)
    $protectedRequested = @($removedAppSelectors | Where-Object {
        $selector = $_
        @($protectedSelectors | Where-Object { $selector -like $_ }).Count -gt 0
    })
    $protectedRequested += @($removedApps | Where-Object {
        $packageName = $_
        @($protectedSelectors | Where-Object { $packageName -like $_ }).Count -gt 0
    })
    if ($protectedRequested.Count -gt 0) {
        throw "Protected AppX selectors cannot be removed: $($protectedRequested -join ', ')"
    }

    $conflicts = @($enabledFeatures | Where-Object { $_ -in $disabledFeatures })
    if ($conflicts.Count -gt 0) {
        throw "A feature cannot be both enabled and disabled: $($conflicts -join ', ')"
    }

    return [PSCustomObject]@{
        SchemaVersion = $schemaVersion
        Description = [string](Get-WinIsoUtilPropertyValue $Configuration 'Description' '')
        DateCreated = [string](Get-WinIsoUtilPropertyValue $Configuration 'DateCreated' '')
        RemovedApps = $removedApps
        RemovedAppSelectors = $removedAppSelectors
        RemovedCapabilities = $removedCapabilities
        DisabledFeatures = $disabledFeatures
        RegistryTweaks = $registryTweaks
        EnabledFeatures = $enabledFeatures
        ComponentServiceTweaks = $componentServiceTweaks
        LegacyMappings = @($legacyMappings)
    }
}

function ConvertTo-WinIsoUtilV3Profile {
    param(
        [Parameter(Mandatory = $true)]$Configuration,
        [Parameter(Mandatory = $true)][string]$RepositoryRoot
    )

    $normalized = ConvertTo-ValidatedWinIsoUtilConfiguration -Configuration $Configuration -RepositoryRoot $RepositoryRoot
    return [ordered]@{
        SchemaVersion = 3
        Description = if ($normalized.Description) { $normalized.Description } else { 'WinISOUtil customization profile' }
        DateCreated = if ($normalized.DateCreated) { $normalized.DateCreated } else { (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }
        RemovedAppSelectors = @($normalized.RemovedAppSelectors)
        RemovedCapabilities = @($normalized.RemovedCapabilities)
        DisabledFeatures = @($normalized.DisabledFeatures)
        RegistryTweaks = @($normalized.RegistryTweaks)
        EnabledFeatures = @($normalized.EnabledFeatures)
        ComponentServiceTweaks = @($normalized.ComponentServiceTweaks)
    }
}

function Get-WinIsoUtilMapValue {
    param($Map, [string]$Key)

    if ($null -eq $Map) { return $null }
    if ($Map -is [System.Collections.IDictionary]) {
        if ($Map.Contains($Key)) { return $Map[$Key] }
        return $null
    }

    $property = $Map.PSObject.Properties[$Key]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function New-WinIsoUtilCheck {
    param([string]$Type, [string]$Id, [string]$Message)
    return [PSCustomObject]@{ Type = $Type; Id = $Id; Message = $Message }
}

function Test-WinIsoUtilProfileState {
    param(
        [Parameter(Mandatory = $true)]$Configuration,
        [Parameter(Mandatory = $true)]$Definitions,
        [Parameter(Mandatory = $true)]$Inventory
    )

    $verified = [System.Collections.Generic.List[object]]::new()
    $noOp = [System.Collections.Generic.List[object]]::new()
    $deferred = [System.Collections.Generic.List[object]]::new()
    $failed = [System.Collections.Generic.List[object]]::new()

    foreach ($selector in $Configuration.RemovedAppSelectors) {
        if ($selector -in @($Inventory.ProvisionedApps)) {
            $failed.Add((New-WinIsoUtilCheck 'AppX' $selector 'Provisioned AppX package is still present.'))
        } else {
            $verified.Add((New-WinIsoUtilCheck 'AppX' $selector 'Provisioned AppX package is absent.'))
        }
    }
    foreach ($packageName in $Configuration.RemovedApps) {
        if ($packageName -in @(Get-WinIsoUtilPropertyValue $Inventory 'ProvisionedPackageNames' @())) {
            $failed.Add((New-WinIsoUtilCheck 'AppXPackage' $packageName 'Provisioned AppX package is still present.'))
        } else {
            $verified.Add((New-WinIsoUtilCheck 'AppXPackage' $packageName 'Provisioned AppX package is absent.'))
        }
    }

    foreach ($capabilityName in $Configuration.RemovedCapabilities) {
        $state = Get-WinIsoUtilMapValue $Inventory.Capabilities $capabilityName
        if ($null -eq $state) {
            $noOp.Add((New-WinIsoUtilCheck 'Capability' $capabilityName 'Capability is not present in this Windows image.'))
        } elseif ([string]$state -eq 'Installed') {
            $failed.Add((New-WinIsoUtilCheck 'Capability' $capabilityName 'Capability is still installed.'))
        } else {
            $verified.Add((New-WinIsoUtilCheck 'Capability' $capabilityName "Capability state is $state."))
        }
    }

    foreach ($featureName in $Configuration.DisabledFeatures) {
        $state = Get-WinIsoUtilMapValue $Inventory.Features $featureName
        if ($null -eq $state) {
            $noOp.Add((New-WinIsoUtilCheck 'DisabledFeature' $featureName 'Feature is not present in this Windows image.'))
        } elseif ([string]$state -in @('Disabled with Payload Removed', 'Removed')) {
            $verified.Add((New-WinIsoUtilCheck 'DisabledFeature' $featureName "Feature state is $state."))
        } else {
            $failed.Add((New-WinIsoUtilCheck 'DisabledFeature' $featureName "Expected payload-removed feature state, found $state."))
        }
    }

    foreach ($featureName in $Configuration.EnabledFeatures) {
        $state = Get-WinIsoUtilMapValue $Inventory.Features $featureName
        if ([string]$state -in @('Enabled', 'Enable Pending')) {
            $verified.Add((New-WinIsoUtilCheck 'EnabledFeature' $featureName "Feature desired state is satisfied: $state."))
        } else {
            $failed.Add((New-WinIsoUtilCheck 'EnabledFeature' $featureName "Expected Enabled feature state, found $state."))
        }
    }

    foreach ($componentId in $Configuration.ComponentServiceTweaks) {
        $component = @($Definitions.ComponentServiceTweaks | Where-Object { $_.ID -eq $componentId })[0]
        foreach ($serviceName in $component.ServiceNames) {
            $service = Get-WinIsoUtilMapValue $Inventory.Services $serviceName
            if ($null -eq $service -or -not $service.Exists) {
                $noOp.Add((New-WinIsoUtilCheck 'Service' $serviceName 'Service is not present in this Windows image.'))
            } elseif ([int]$service.Start -eq 4) {
                $verified.Add((New-WinIsoUtilCheck 'Service' $serviceName 'Service startup value is Disabled (4).'))
            } else {
                $failed.Add((New-WinIsoUtilCheck 'Service' $serviceName "Expected service Start=4, found $($service.Start)."))
            }
        }
    }

    $postLoginTweaks = [System.Collections.Generic.List[object]]::new()
    foreach ($tweakId in $Configuration.RegistryTweaks) {
        $tweak = @($Definitions.RegistryTweaks | Where-Object { $_.ID -eq $tweakId })[0]
        if ($tweak.ExecutionPhase -eq 'PostLogin') {
            $postLoginTweaks.Add($tweak)
            continue
        }

        foreach ($rule in @($tweak.Verification)) {
            $key = "$($rule.Hive)|$($rule.Path)|$($rule.Name)"
            $actual = Get-WinIsoUtilMapValue $Inventory.Registry $key
            if ($rule.ContainsKey('Absent') -and $rule.Absent) {
                if ($null -eq $actual -or -not $actual.Exists) {
                    $verified.Add((New-WinIsoUtilCheck 'Registry' $tweakId "Registry value is absent: $key"))
                } else {
                    $failed.Add((New-WinIsoUtilCheck 'Registry' $tweakId "Registry value should be absent: $key"))
                }
            } elseif ($null -ne $actual -and $actual.Exists -and [string]$actual.Value -eq [string]$rule.Value) {
                $verified.Add((New-WinIsoUtilCheck 'Registry' $tweakId "Registry value matches: $key"))
            } else {
                $found = if ($null -eq $actual -or -not $actual.Exists) { '<absent>' } else { [string]$actual.Value }
                $failed.Add((New-WinIsoUtilCheck 'Registry' $tweakId "Expected $($rule.Value), found ${found}: $key"))
            }
        }
    }

    if ($postLoginTweaks.Count -gt 0) {
        $payload = 'Windows\Setup\Scripts\post-setup.ps1'
        $runnerCandidates = @(
            'Users\Default\Desktop\Apply Custom Settings.bat',
            'Users\Default\Desktop\Ozel Ayarlari Uygula.bat'
        )
        if ($payload -notin @($Inventory.Files)) {
            $failed.Add((New-WinIsoUtilCheck 'PostLogin' 'Payload' "Missing post-login PowerShell payload: $payload"))
        }
        if (@($runnerCandidates | Where-Object { $_ -in @($Inventory.Files) }).Count -eq 0) {
            $failed.Add((New-WinIsoUtilCheck 'PostLogin' 'Runner' 'Missing post-login desktop BAT runner.'))
        }
        foreach ($tweak in $postLoginTweaks) {
            $deferred.Add((New-WinIsoUtilCheck 'PostLogin' $tweak.ID 'Post-login action is deferred to the desktop BAT runner.'))
        }
    }

    return [PSCustomObject]@{
        OverallStatus = if ($failed.Count -eq 0) { 'Passed' } else { 'Failed' }
        VerifiedChecks = @($verified)
        NoOpChecks = @($noOp)
        DeferredPostLoginChecks = @($deferred)
        FailedChecks = @($failed)
    }
}

function Invoke-WinIsoUtilDism {
    param(
        [Parameter(Mandatory = $true)][string]$DismPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    $output = @(& $DismPath @Arguments 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
        throw "DISM failed with exit code $LASTEXITCODE`: $($output -join [Environment]::NewLine)"
    }
    return [PSCustomObject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Get-WinIsoUtilDismBlockMap {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][AllowEmptyCollection()][string[]]$Output,
        [Parameter(Mandatory = $true)][string]$IdentityLabel,
        [Parameter(Mandatory = $true)][string]$StateLabel
    )

    $result = @{}
    $current = $null
    foreach ($line in $Output) {
        if ($line -match "^\s*$([regex]::Escape($IdentityLabel))\s*:\s*(.+?)\s*$") {
            $current = $matches[1]
        } elseif ($current -and $line -match "^\s*$([regex]::Escape($StateLabel))\s*:\s*(.+?)\s*$") {
            $result[$current] = $matches[1]
            $current = $null
        }
    }
    return $result
}

function Get-WinIsoUtilProvisionedApps {
    param([string]$DismPath, [string]$MountPath)

    $result = Invoke-WinIsoUtilDism $DismPath @("/Image:$MountPath", '/English', '/Get-ProvisionedAppxPackages')
    $apps = [System.Collections.Generic.List[object]]::new()
    $displayName = $null
    foreach ($line in $result.Output) {
        if ($line -match '^\s*DisplayName\s*:\s*(.+?)\s*$') {
            $displayName = $matches[1]
        } elseif ($displayName -and $line -match '^\s*PackageName\s*:\s*(.+?)\s*$') {
            $apps.Add([PSCustomObject]@{ DisplayName = $displayName; PackageName = $matches[1] })
            $displayName = $null
        }
    }
    return @($apps)
}

function Get-WinIsoUtilOfflineInventory {
    param(
        [Parameter(Mandatory = $true)][string]$MountPath,
        [Parameter(Mandatory = $true)]$Configuration,
        [Parameter(Mandatory = $true)]$Definitions,
        [string]$DismPath = 'dism.exe'
    )

    $capabilitiesResult = Invoke-WinIsoUtilDism $DismPath @("/Image:$MountPath", '/English', '/Get-Capabilities')
    $capabilities = Get-WinIsoUtilDismBlockMap $capabilitiesResult.Output 'Capability Identity' 'State'
    $features = @{}
    foreach ($featureName in @($Configuration.DisabledFeatures + $Configuration.EnabledFeatures | Sort-Object -Unique)) {
        $result = Invoke-WinIsoUtilDism $DismPath @("/Image:$MountPath", '/English', '/Get-FeatureInfo', "/FeatureName:$featureName") -AllowFailure
        if ($result.ExitCode -eq 0) {
            foreach ($line in $result.Output) {
                if ($line -match '^\s*State\s*:\s*(.+?)\s*$') {
                    $features[$featureName] = $matches[1]
                    break
                }
            }
        } elseif (($result.Output -join "`n") -notmatch '0x800f080c') {
            throw "Unable to read optional feature state for $featureName`: $($result.Output -join [Environment]::NewLine)"
        }
    }

    $softwareHive = 'WINISOUTILVERIFY_SOFTWARE'
    $systemHive = 'WINISOUTILVERIFY_SYSTEM'
    $defaultHive = 'WINISOUTILVERIFY_DEFAULT'
    $loaded = [System.Collections.Generic.List[string]]::new()
    $registry = @{}
    $services = @{}
    try {
        foreach ($item in @(
            @{ Target = "HKLM\$softwareHive"; Path = (Join-Path $MountPath 'Windows\System32\config\SOFTWARE') },
            @{ Target = "HKLM\$systemHive"; Path = (Join-Path $MountPath 'Windows\System32\config\SYSTEM') },
            @{ Target = "HKU\$defaultHive"; Path = (Join-Path $MountPath 'Users\Default\NTUSER.DAT') }
        )) {
            & reg.exe LOAD $item.Target $item.Path | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Unable to load offline registry hive $($item.Target)." }
            $loaded.Add($item.Target)
        }

        $select = Get-ItemProperty -LiteralPath "Registry::HKEY_LOCAL_MACHINE\$systemHive\Select" -ErrorAction Stop
        $controlSet = 'ControlSet{0:D3}' -f [int]$select.Current

        foreach ($tweakId in $Configuration.RegistryTweaks) {
            $tweak = @($Definitions.RegistryTweaks | Where-Object { $_.ID -eq $tweakId })[0]
            if ($tweak.ExecutionPhase -ne 'Offline') { continue }
            foreach ($rule in @($tweak.Verification)) {
                $path = ([string]$rule.Path).Replace('{ControlSet}', $controlSet)
                $root = switch ($rule.Hive) {
                    'SOFTWARE' { "Registry::HKEY_LOCAL_MACHINE\$softwareHive" }
                    'SYSTEM' { "Registry::HKEY_LOCAL_MACHINE\$systemHive" }
                    'DEFAULT' { "Registry::HKEY_USERS\$defaultHive" }
                    default { throw "Unsupported registry verification hive: $($rule.Hive)" }
                }
                $key = "$($rule.Hive)|$($rule.Path)|$($rule.Name)"
                try {
                    $value = Get-ItemPropertyValue -LiteralPath "$root\$path" -Name $rule.Name -ErrorAction Stop
                    $registry[$key] = [PSCustomObject]@{ Exists = $true; Value = $value }
                } catch {
                    $registry[$key] = [PSCustomObject]@{ Exists = $false; Value = $null }
                }
            }
        }

        foreach ($componentId in $Configuration.ComponentServiceTweaks) {
            $component = @($Definitions.ComponentServiceTweaks | Where-Object { $_.ID -eq $componentId })[0]
            foreach ($serviceName in $component.ServiceNames) {
                try {
                    $start = Get-ItemPropertyValue -LiteralPath "Registry::HKEY_LOCAL_MACHINE\$systemHive\$controlSet\Services\$serviceName" -Name Start -ErrorAction Stop
                    $services[$serviceName] = [PSCustomObject]@{ Exists = $true; Start = [int]$start }
                } catch {
                    $services[$serviceName] = [PSCustomObject]@{ Exists = $false; Start = $null }
                }
            }
        }
    } finally {
        foreach ($target in @($loaded | Sort-Object -Descending)) {
            [gc]::Collect()
            [gc]::WaitForPendingFinalizers()
            & reg.exe UNLOAD $target | Out-Null
        }
    }

    $files = @(
        'Windows\Setup\Scripts\post-setup.ps1',
        'Users\Default\Desktop\Apply Custom Settings.bat',
        'Users\Default\Desktop\Ozel Ayarlari Uygula.bat'
    ) | Where-Object { Test-Path -LiteralPath (Join-Path $MountPath $_) }

    $provisionedApps = @(Get-WinIsoUtilProvisionedApps $DismPath $MountPath)
    return [PSCustomObject]@{
        ProvisionedApps = @($provisionedApps.DisplayName)
        ProvisionedPackageNames = @($provisionedApps.PackageName)
        Capabilities = $capabilities
        Features = $features
        Services = $services
        Registry = $registry
        Files = @($files)
    }
}

function Invoke-WinIsoUtilProfileValidation {
    param(
        [Parameter(Mandatory = $true)][string]$MountPath,
        [Parameter(Mandatory = $true)]$Configuration,
        [Parameter(Mandatory = $true)][string]$RepositoryRoot,
        [string]$DismPath = 'dism.exe'
    )

    $definitions = Get-WinIsoUtilDefinitions $RepositoryRoot
    $normalized = ConvertTo-ValidatedWinIsoUtilConfiguration $Configuration $RepositoryRoot
    $inventory = Get-WinIsoUtilOfflineInventory $MountPath $normalized $definitions $DismPath
    return Test-WinIsoUtilProfileState $normalized $definitions $inventory
}

function Get-WinIsoUtilSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-WinIsoUtilValidationReport {
    param(
        [Parameter(Mandatory = $true)]$Validation,
        [Parameter(Mandatory = $true)][string]$ConfigurationPath,
        [Parameter(Mandatory = $true)][string]$IsoPath,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    $configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json
    $schemaVersion = [int](Get-WinIsoUtilPropertyValue $configuration 'SchemaVersion' 1)
    $report = [ordered]@{
        SchemaVersion = 1
        ProfileSchemaVersion = $schemaVersion
        ConfigurationSha256 = Get-WinIsoUtilSha256 $ConfigurationPath
        IsoSha256 = Get-WinIsoUtilSha256 $IsoPath
        OverallStatus = $Validation.OverallStatus
        VerifiedChecks = @($Validation.VerifiedChecks)
        NoOpChecks = @($Validation.NoOpChecks)
        DeferredPostLoginChecks = @($Validation.DeferredPostLoginChecks)
        FailedChecks = @($Validation.FailedChecks)
        GeneratedAt = (Get-Date).ToString('o')
    }

    $parent = Split-Path -Parent $OutputPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $temporaryPath = "$OutputPath.tmp"
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
    Move-Item -LiteralPath $temporaryPath -Destination $OutputPath -Force
    return [PSCustomObject]$report
}

Export-ModuleMember -Function @(
    'ConvertTo-ValidatedWinIsoUtilConfiguration',
    'ConvertTo-WinIsoUtilV3Profile',
    'Get-WinIsoUtilDefinitions',
    'Get-WinIsoUtilOfflineInventory',
    'Invoke-WinIsoUtilProfileValidation',
    'Test-WinIsoUtilProfileState',
    'Write-WinIsoUtilValidationReport'
)
