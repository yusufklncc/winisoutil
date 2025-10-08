# Bu dosya, Enable-Features fonksiyonu tarafından kullanılacak olan tüm özellik tanımlarını içerir.
#
# ÇOKLU DİL DESTEĞİ:
# Her özelliğin adı, dil koduna özel bir özellikle (`Name_tr`, `Name_en` gibi) saklanmalıdır.
# Ana script, kullanıcının seçtiği dile göre doğru adı otomatik olarak seçecektir.

$allFeatures = @(
    [PSCustomObject]@{ 
        Name_tr = ".NET Framework 3.5 (2 ve 3 dahil)"; 
        Name_en = ".NET Framework 3.5 (includes 2 and 3)"; 
        Name_ja = ".NET Framework 3.5 (2 と 3 を含む)";
        FeatureName = "NetFx3"; 
        Source = "C:\temp_iso\sources\sxs" 
    },
    [PSCustomObject]@{ 
        Name_tr = ".NET Framework 4.8 Advanced Services"; 
        Name_en = ".NET Framework 4.8 Advanced Services"; 
        Name_ja = ".NET Framework 4.8 アドバンスト サービス";
        FeatureName = "NetFx4-AdvSrvs"; 
        Source = "C:\temp_iso\sources\sxs" 
    },
    [PSCustomObject]@{ 
        Name_tr = "Telnet Istemcisi"; 
        Name_en = "Telnet Client"; 
        Name_ja = "Telnet クライアント";
        FeatureName = "TelnetClient"; 
        Source = $null 
    }
)
