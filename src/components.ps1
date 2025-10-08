# Bu dosya, Configure-ComponentsAndServices fonksiyonu tarafından kullanılacak olan tüm bileşen ve servis ayar tanımlarını içerir.
#
# ÇOKLU DİL DESTEĞİ:
# Her ayarın açıklaması, dil koduna özel bir özellikle (`Description_tr`, `Description_en` gibi) saklanmalıdır.
# Ana script, kullanıcının seçtiği dile göre doğru açıklamayı otomatik olarak seçecektir.
# Yeni bir dil (örneğin Japonca, 'ja') eklemek için, her nesneye 'Description_ja' özelliğini eklemeniz yeterlidir.

$allComponentTweaks = @(
    [PSCustomObject]@{ 
        ID = 'RemoveIE'; 
        Description_tr = "Internet Explorer'i Kaldir (Eski bilesenleri temizler)"; 
        Description_en = "Remove Internet Explorer (Cleans up old components)"; 
        Type = 'Component'; 
        FeatureName = 'Internet-Explorer-Optional-amd64' 
    },
    [PSCustomObject]@{ 
        ID = 'RemoveWMP'; 
        Description_tr = "Windows Media Player'i Kaldir (Eski medya oynaticiyi kaldirir)"; 
        Description_en = "Remove Windows Media Player (Removes legacy media player)"; 
        Type = 'Component'; 
        FeatureName = 'WindowsMediaPlayer' 
    },
    [PSCustomObject]@{ 
        ID = 'DisableTelemetry'; 
        Description_tr = "Telemetri Servislerini Devre Disi Birak (Microsoft'a veri gonderimini engeller)"; 
        Description_en = "Disable Telemetry Services (Prevents data sending to Microsoft)"; 
        Type = 'Service'; 
        ServiceNames = @('DiagTrack', 'dmwappushservice') 
    },
    [PSCustomObject]@{ 
        ID = 'DisableWerSvc'; 
        Description_tr = "Hata Raporlama Servisini Devre Disi Birak (Sorun raporlarini gondermeyi durdurur)"; 
        Description_en = "Disable Error Reporting Service (Stops sending problem reports)"; 
        Type = 'Service'; 
        ServiceNames = @('WerSvc') 
    },
    [PSCustomObject]@{ 
        ID = 'DisableFax'; 
        Description_tr = "Fax Servisini Devre Disi Birak (Gereksiz faks ozelligini kapatir)"; 
        Description_en = "Disable Fax Service (Turns off unnecessary fax feature)"; 
        Type = 'Service'; 
        ServiceNames = @('Fax') 
    }
)