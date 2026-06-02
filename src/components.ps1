# Define service tweaks. Removable features live in removable-features.ps1.
# User-facing descriptions are stored in languages.ps1.

$allComponentTweaks = @(
    [PSCustomObject]@{
        ID = 'DisableTelemetry'; Type = 'Service'; ServiceNames = @('DiagTrack', 'dmwappushservice')
        Category = 'Privacy'; RiskLevel = 'Medium'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $true; Verification = 'ServiceDisabled'
    },
    [PSCustomObject]@{
        ID = 'DisableWerSvc'; Type = 'Service'; ServiceNames = @('WerSvc')
        Category = 'Privacy'; RiskLevel = 'Medium'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $true; Verification = 'ServiceDisabled'
    },
    [PSCustomObject]@{
        ID = 'DisableFax'; Type = 'Service'; ServiceNames = @('Fax')
        Category = 'Legacy'; RiskLevel = 'Low'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $true; Verification = 'ServiceDisabled'
    }
)
