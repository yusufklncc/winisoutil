# Conservative allow-list of removable Windows optional features.

$allRemovableFeatures = @(
    [PSCustomObject]@{
        FeatureName = 'Internet-Explorer-Optional-amd64'; LegacyComponentId = 'RemoveIE'
        Category = 'Legacy'; RiskLevel = 'Low'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $true; Verification = 'FeaturePayloadRemoved'
    },
    [PSCustomObject]@{
        FeatureName = 'WindowsMediaPlayer'; LegacyComponentId = 'RemoveWMP'
        Category = 'Media'; RiskLevel = 'Medium'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $true; Verification = 'FeaturePayloadRemoved'
    },
    [PSCustomObject]@{
        FeatureName = 'Printing-XPSServices-Features'; LegacyComponentId = $null
        Category = 'Legacy'; RiskLevel = 'Low'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $true; Verification = 'FeaturePayloadRemoved'
    },
    [PSCustomObject]@{
        FeatureName = 'WorkFolders-Client'; LegacyComponentId = $null
        Category = 'Enterprise'; RiskLevel = 'Low'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $true; Verification = 'FeaturePayloadRemoved'
    },
    [PSCustomObject]@{
        FeatureName = 'SMB1Protocol'; LegacyComponentId = $null
        Category = 'Legacy'; RiskLevel = 'Low'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $true; Verification = 'FeaturePayloadRemoved'
    }
)
