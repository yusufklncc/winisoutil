# Define all component tweaks with their IDs, types, and relevant feature or service names.
# This file only contains the technical identifiers for each tweak.
# All user-facing descriptions are stored in 'languages.ps1' for easier localization.
# The main script will fetch the description from the language file using a key like 'comp_ID_desc'.
# This file is part of the WinISOUtil project.

$allComponentTweaks = @(
    [PSCustomObject]@{ 
        ID = 'RemoveIE'; 
        Type = 'Component'; 
        FeatureName = 'Internet-Explorer-Optional-amd64' 
    },
    [PSCustomObject]@{ 
        ID = 'RemoveWMP'; 
        Type = 'Component'; 
        FeatureName = 'WindowsMediaPlayer' 
    },
    [PSCustomObject]@{ 
        ID = 'DisableTelemetry'; 
        Type = 'Service'; 
        ServiceNames = @('DiagTrack', 'dmwappushservice') 
    },
    [PSCustomObject]@{ 
        ID = 'DisableWerSvc'; 
        Type = 'Service'; 
        ServiceNames = @('WerSvc') 
    },
    [PSCustomObject]@{ 
        ID = 'DisableFax'; 
        Type = 'Service'; 
        ServiceNames = @('Fax') 
    }
)