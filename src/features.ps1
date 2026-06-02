# Define all Windows features with their technical feature names and source paths if applicable.
# All user-facing descriptions are now stored in 'languages.ps1'.
# The main script will fetch descriptions using a key like 'feature_FeatureName_desc'.

$allFeatures = @(
    [PSCustomObject]@{ 
        FeatureName = "NetFx3"; 
        Source = "sources\sxs"
    },
    [PSCustomObject]@{ 
        FeatureName = "NetFx4-AdvSrvs"; 
        Source = "sources\sxs"
    },
    [PSCustomObject]@{ 
        FeatureName = "TelnetClient"; 
        Source = $null 
    }
)
