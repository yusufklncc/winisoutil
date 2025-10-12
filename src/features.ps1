# Define all Windows features with their names in Turkish and English, feature names, and source paths if applicable
# Note: Adjust the Source paths as necessary for your environment
# Example source path: "C:\temp_iso\sources\sxs"
# This script creates an array of custom objects representing each feature

$allFeatures = @(
    [PSCustomObject]@{ 
        Name_tr = ".NET Framework 3.5 (2 ve 3 dahil)"; 
        Name_en = ".NET Framework 3.5 (includes 2 and 3)"; 
        FeatureName = "NetFx3"; 
        Source = "C:\temp_iso\sources\sxs" 
    },
    [PSCustomObject]@{ 
        Name_tr = ".NET Framework 4.8 Gelişmiş Servisler"; 
        Name_en = ".NET Framework 4.8 Advanced Services"; 
        FeatureName = "NetFx4-AdvSrvs"; 
        Source = "C:\temp_iso\sources\sxs" 
    },
    [PSCustomObject]@{ 
        Name_tr = "Telnet İstemcisi"; 
        Name_en = "Telnet Client"; 
        FeatureName = "TelnetClient"; 
        Source = $null 
    }
)
