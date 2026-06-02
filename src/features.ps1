# Define Windows features that can be enabled.
# User-facing descriptions are stored in languages.ps1.

$allFeatures = @(
    [PSCustomObject]@{
        FeatureName = 'NetFx3'; Source = 'sources\sxs'
        Category = 'Runtime'; RiskLevel = 'Low'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $false; Verification = 'FeatureEnabled'
    },
    [PSCustomObject]@{
        FeatureName = 'NetFx4-AdvSrvs'; Source = 'sources\sxs'
        Category = 'Runtime'; RiskLevel = 'Low'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $false; Verification = 'FeatureEnabled'
    },
    [PSCustomObject]@{
        FeatureName = 'TelnetClient'; Source = $null
        Category = 'Legacy'; RiskLevel = 'Medium'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $false; Verification = 'FeatureEnabled'
    }
)
