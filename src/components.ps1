# Define all component tweaks with their IDs, descriptions in Turkish and English, types, and relevant feature or service names
# Note: This script creates an array of custom objects representing each tweak

$allComponentTweaks = @(
    [PSCustomObject]@{ 
        ID = 'RemoveIE'; 
        Description_tr = "Internet Explorer'i Kaldır (Eski bileşenleri temizler)"; 
        Description_en = "Remove Internet Explorer (Cleans up old components)"; 
        Type = 'Component'; 
        FeatureName = 'Internet-Explorer-Optional-amd64' 
    },
    [PSCustomObject]@{ 
        ID = 'RemoveWMP'; 
        Description_tr = "Windows Media Player'i Kaldır (Eski medya oynatıcıyı kaldırır)"; 
        Description_en = "Remove Windows Media Player (Removes legacy media player)"; 
        Type = 'Component'; 
        FeatureName = 'WindowsMediaPlayer' 
    },
    [PSCustomObject]@{ 
        ID = 'DisableTelemetry'; 
        Description_tr = "Telemetri Servislerini Devre Dışı Bırak (Microsoft'a veri göndermesini engeller)"; 
        Description_en = "Disable Telemetry Services (Prevents data sending to Microsoft)"; 
        Type = 'Service'; 
        ServiceNames = @('DiagTrack', 'dmwappushservice') 
    },
    [PSCustomObject]@{ 
        ID = 'DisableWerSvc'; 
        Description_tr = "Hata Raporlama Servisini Devre Dışı Bırak (Sorun raporlarını göndermeyi durdurur)"; 
        Description_en = "Disable Error Reporting Service (Stops sending problem reports)"; 
        Type = 'Service'; 
        ServiceNames = @('WerSvc') 
    },
    [PSCustomObject]@{ 
        ID = 'DisableFax'; 
        Description_tr = "Fax Servisini Devre Dışı Bırak (Gereksiz faks özelliğini kapatır)"; 
        Description_en = "Disable Fax Service (Turns off unnecessary fax feature)"; 
        Type = 'Service'; 
        ServiceNames = @('Fax') 
    }
)