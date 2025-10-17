# Define all Windows features with their technical feature names and source paths if applicable.
# All user-facing descriptions are now stored in 'languages.ps1'.
# The main script will fetch descriptions using a key like 'feature_FeatureName_desc'.

$allFeatures = @(
    [PSCustomObject]@{ 
        FeatureName = "NetFx3"; 
        Source = "C:\temp_iso\sources\sxs" 
    },
    [PSCustomObject]@{ 
        FeatureName = "NetFx4-AdvSrvs"; 
        Source = "C:\temp_iso\sources\sxs" 
    },
    [PSCustomObject]@{ 
        FeatureName = "TelnetClient"; 
        Source = $null 
    }
)