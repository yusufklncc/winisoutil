# Bu dosya, Set-Registry fonksiyonu tarafından kullanılacak olan tüm registry ayar tanımlarını içerir.
# Yeni bir ayar eklemek veya mevcut olanı düzenlemek için bu dosyayı kullanabilirsiniz.
#
# ÇOKLU DİL DESTEĞİ:
# Her ayarın açıklaması, dil koduna özel bir özellikle (`Description_tr`, `Description_en` gibi) saklanmalıdır.
# Ana script, kullanıcının seçtiği dile göre doğru açıklamayı otomatik olarak seçecektir.
# Yeni bir dil (örneğin Japonca, 'ja') eklemek için, her nesneye 'Description_ja' özelliğini eklemeniz yeterlidir.

$allTweaks = @(
    # --- Windows Update Ayarları ---
    [PSCustomObject]@{ 
        ID = 'WU_NotifyDownload'; 
        Description_tr = "Windows Update: Indirmeden once bildir"; 
        Description_en = "Windows Update: Notify before downloading";
        Action = "WU_Handler" 
    },
    [PSCustomObject]@{ 
        ID = 'WU_NotifyInstall'; 
        Description_tr = "Windows Update: Otomatik indir, yuklemeden once bildir"; 
        Description_en = "Windows Update: Download automatically, notify before installing";
        Action = "WU_Handler" 
    },
    # --- Arayüz ve Kullanıcı Deneyimi Ayarları ---
    [PSCustomObject]@{ 
        ID = 'AddDesktopIcons'; 
        Description_tr = "Masaustune temel simgeleri ekle (Bu Bilgisayar, Geri Donusum Kutusu ve Kullanici Klasoru)"; 
        Description_en = "Add basic icons to Desktop (This PC, Recycle Bin, and User Folder)"; 
        Action = "InlineScript"; 
        Code = @"
try {
    $path = 'Registry::HKLM\TEMP\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
    New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $path -Name '{20D04FE0-3AEA-1069-A2D8-08002B30309D}' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name '{59031a47-3f72-44a7-89c5-5595fe6b30ee}' -Value 0 -Type DWord -Force
}
catch {}
"@
    },
    [PSCustomObject]@{ 
        ID = 'ConfigureTaskbar'; 
        Description_tr = "Gorev Cubugu'nu yapilandir (Sola hizala, Gorev Gorunumu ve Widget simgelerini gizle ve Sağ Tık menüsüne Gorevi Sonlandir ekle)"; 
        Description_en = "Configure Taskbar (Align left, hide Task View/Widgets icons, and add End Task to context menu)"; 
        Action = "InlineScript"; 
        Code = @"
try {
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton' -Value 0 -Type DWord -Force
    New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Name 'TaskbarEndTask' -Value 1 -Type DWord -Force
    New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Dsh' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests' -Value 0 -Type DWord -Force
}
catch {}
"@
    },
    [PSCustomObject]@{ 
        ID = 'HideSearchIcon';
        Description_tr = "Gorev cubugunda Arama simgesini gizle"; 
        Description_en = "Hide the Search icon on the taskbar";
        Action = "SetupScript"; 
        Code = "try { Set-ItemProperty -Path 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Value 0 -Type DWord -Force } catch {}"
    },
    [PSCustomObject]@{ 
        ID = 'ConfigureFileExplorer'; 
        Description_tr = "Dosya Gezgini'ni yapilandir (Bu Bilgisayar ile baslat, Kompakt Gorunum, Detayli Kopyalama Diyalogu ve Dosya Uzantilarini etkinlestir )"; 
        Description_en = "Configure File Explorer (Start with This PC, Compact View, Detailed Copy Dialog, and show extensions)"; 
        Action = "InlineScript"; 
        Code = @"
try {
    $path = 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-ItemProperty -Path $path -Name 'HideFileExt' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name 'UseCompactMode' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $path -Name 'LaunchTo' -Value 1 -Type DWord -Force
    New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager' -Name 'EnthusiastMode' -Value 1 -Type DWord -Force
}
catch {}
"@
    },
    [PSCustomObject]@{ 
        ID = 'ConfigureStartMenu'; 
        Description_tr = "Baslat Menusu'nu yapilandir (Onerilenleri gizle, Bing aramasini kapat)"; 
        Description_en = "Configure Start Menu (Hide recommendations, disable Bing search)"; 
        Action = "InlineScript"; 
        Code = @"
try {
    New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Search' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'BingSearchEnabled' -Value 0 -Type DWord -Force
    New-Item -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\Explorer' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1 -Type DWord -Force
    New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Name 'HideRecommendedSection' -Value 1 -Type DWord -Force
    New-Item -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Start' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Start' -Name 'HideRecommendedSection' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_Layout' -Value 1 -Type DWord -Force
}
catch {}
"@
    },
    [PSCustomObject]@{ 
        ID = 'DisablePrivacyAndTelemetry'; 
        Description_tr = "Gizliligi ihlal eden telemetri, veri toplama ve tanima servislerini kapat"; 
        Description_en = "Disable privacy-invading telemetry, data collection, and recognition services"; 
        Action = "InlineScript"; 
        Code = @"
try {
    New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DataCollection' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -Type DWord -Force
    New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\AdvertisingInfo' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\AdvertisingInfo' -Name 'DisabledByGroupPolicy' -Value 1 -Type DWord -Force
    New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled' -Value 0 -Type DWord -Force
    New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\TabletPC' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\TabletPC' -Name 'PreventHandwritingDataSharing' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Privacy' -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0 -Type DWord -Force
    New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' -Name 'HasAccepted' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Input\TIPC' -Name 'Enabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_TrackProgs' -Value 0 -Type DWord -Force
    New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\System' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\System' -Name 'PublishUserActivities' -Value 0 -Type DWord -Force
    New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Siuf\Rules' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Siuf\Rules' -Name 'NumberOfSIUFInPeriod' -Value 0 -Type DWord -Force
}
catch {}
"@
    },
    [PSCustomObject]@{ 
        ID = 'DisableAdsAndSuggestions'; 
        Description_tr = "Windows genelinde onerilen uygulamalar, reklam, ipucu ve onerileri devre disi birak"; 
        Description_en = "Disable suggested apps, ads, tips, and suggestions across Windows"; 
        Action = "InlineScript"; 
        Code = @"
try {
    New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\CloudContent' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338387Enabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'SettingsPageNotifications' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338389Enabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-310093Enabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338388Enabled' -Value 0 -Type DWord -Force
    New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' -Name 'ScoobeSystemSettingEnabled' -Value 0 -Type DWord -Force
}
catch {}
"@
    },
    [PSCustomObject]@{ 
        ID = 'DisableSpotlight'; 
        Description_tr = "Windows Spotlight duvar kagıdı ve ozelliklerini devre disi birak"; 
        Description_en = "Disable Windows Spotlight wallpaper and features"; 
        Action = "InlineScript"; 
        Code = @"
try {
    New-Item -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsSpotlightFeatures' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent' -Name 'DisableSpotlightCollectionOnDesktop' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Control Panel\Desktop' -Name 'WallPaper' -Value 'C:\Windows\Web\Wallpaper\Windows\img0.jpg' -Force
}
catch {}
"@
    },
    [PSCustomObject]@{ 
        ID = 'DisableWindowsAIFeatures'; 
        Description_tr = "Windows Copilot, Recall ve diger AI ozelliklerini devre disi birak"; 
        Description_en = "Disable Windows Copilot, Recall, and other AI features"; 
        Action = "InlineScript"; 
        Code = @"
try {
    New-Item -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\WindowsCopilot' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1 -Type DWord -Force
    New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsAI' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowRecallEnablement' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsAI' -Name 'TurnOffSavingSnapshots' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis' -Value 1 -Type DWord -Force
    New-Item -Path 'Registry::HKLM\TEMP\WindowsNotepad' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKLM\TEMP\WindowsNotepad' -Name 'DisableAIFeatures' -Value 1 -Type DWord -Force
    New-Item -Path 'Registry::HKLM\TEMP\Microsoft\Windows\CurrentVersion\Policies\Paint' -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path 'Registry::HKLM\TEMP\Microsoft\Windows\CurrentVersion\Policies\Paint' -Name 'DisableCocreator' -Value 1 -Type DWord -Force
}
catch {}
"@
    },
    [PSCustomObject]@{ 
        ID = 'DisableEdgeAIFeatures'; 
        Description_tr = "Microsoft Edge'deki Copilot, Kenar Cubugu ve diger AI ozelliklerini kapat"; 
        Description_en = "Disable Copilot, Sidebar, and other AI features in Microsoft Edge"; 
        Action = "InlineScript"; 
        Code = @"
try {
    $path = 'Registry::HKLM\TEMP\Policies\Microsoft\Edge'
    New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $path -Name 'CopilotPageContext' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name 'HubsSidebarEnabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name 'EdgeHistoryAISearchEnabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name 'ComposeInlineEnabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name 'NewTabPageBingChatEnabled' -Value 0 -Type DWord -Force
}
catch {}
"@
    },
    [PSCustomObject]@{ 
        ID = 'DisableEdgeContentFeatures'; 
        Description_tr = "Edge'deki alisveris asistani, MSN haberleri ve diger icerik ozelliklerini kapat"; 
        Description_en = "Disable shopping assistant, MSN news, and other content features in Edge"; 
        Action = "InlineScript"; 
        Code = @"
try {
    $path = 'Registry::HKLM\TEMP\Policies\Microsoft\Edge'
    New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $path -Name 'NewTabPageContentEnabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name 'EdgeShoppingAssistantEnabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name 'PersonalizationReportingEnabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name 'DiagnosticData' -Value 0 -Type DWord -Force
}
catch {}
"@
    },
    [PSCustomObject]@{ 
        ID = 'DisableOemApps'; 
        Description_tr = "Hazir kurulu OEM uygulamalarini ve onerilerini engelle"; 
        Description_en = "Block pre-installed OEM apps and suggestions"; 
        Action = "InlineScript"; 
        Code = @"
try {
    $path = 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    Set-ItemProperty -Path $path -Name 'OemPreInstalledAppsEnabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name 'PreInstalledAppsEnabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name 'PreInstalledAppsEverEnabled' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $path -Name 'SilentInstalledAppsEnabled' -Value 0 -Type DWord -Force
}
catch {}
"@
    },
    [PSCustomObject]@{ ID = 'EnableRestartApps'; Description_tr = "Yeniden baslatirken uygulamalari otomatik olarak geri yukle"; Description_en = "Automatically restore apps on restart"; Description_ja = "再起動時にアプリを自動的に復元する"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"; Name = "RestartApps"; Value = 1; Type = "DWord" },
    [PSCustomObject]@{ ID = 'ForceOfflineAccount'; Description_tr = "Kurulumda cevrimdisi (yerel) hesap kullanmaya zorla (OOBE)"; Description_en = "Force using an offline (local) account during setup (OOBE)"; Description_ja = "セットアップ中にオフライン（ローカル）アカウントの使用を強制する（OOBE）"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Microsoft\Windows\CurrentVersion\OOBE"; Name = "BypassNRO"; Value = 1; Type = "DWord" },
    [PSCustomObject]@{ ID = 'DisableStickyKeys'; Description_tr = "Yapiskan Tuslar uyarilarini devre disi birak"; Description_en = "Disable Sticky Keys prompts"; Description_ja = "固定キーのプロンプトを無効にする"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Control Panel\Accessibility\StickyKeys"; Name = "Flags"; Value = "506"; Type = "String" },
    [PSCustomObject]@{ ID = 'EnableStorageSense'; Description_tr = "Depolama Bilinci'ni (Storage Sense) etkinlestir ve otomatik calistir"; Description_en = "Enable and autorun Storage Sense"; Description_ja = "ストレージセンサーを有効にして自動実行する"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Policies\Microsoft\Windows\StorageSense"; Name = "AllowStorageSenseTemporaryFilesCleanup"; Value = 1; Type = "DWord" },
    [PSCustomObject]@{ ID = 'DisableEdgeShortcut'; Description_tr = "Microsoft Edge otomatik masaustu kisayolu olusturmayi devre disi birak"; Description_en = "Disable automatic Microsoft Edge desktop shortcut creation"; Description_ja = "Microsoft Edgeの自動デスクトップショートカット作成を無効にする"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Policies\Microsoft\EdgeUpdate"; Name = "CreateDesktopShortcutDefault"; Value = 0; Type = "DWord" },
    [PSCustomObject]@{ ID = 'DisableOneDriveSetup'; Description_tr = "OneDrive'in baslangicta otomatik calismasini engelle"; Description_en = "Prevent OneDrive from running automatically at startup"; Description_ja = "起動時にOneDriveが自動的に実行されるのを防ぐ"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Run"; Name = "OneDriveSetup"; Value = $null; Type = "Remove" }
)