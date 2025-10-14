# Define all available tweaks and their actions. Each tweak has an ID, descriptions in Turkish and English, an action type, and the corresponding code or handler.
# This structure allows for easy addition of new tweaks and localization support.
# Each tweak can be an inline script or call a predefined handler function.
# The action type determines how the tweak is applied.
# Possible action types:
# - InlineScript: Executes the provided PowerShell script block directly.
# - SetupScript: Executes a PowerShell command or script during setup.
# - WU_Handler: Calls a predefined function to handle Windows Update settings.
# The code block or handler function is specified in the 'Code' field.
# The tweaks are stored in an array of custom objects for easy management and iteration.
# Each tweak can be referenced by its unique ID for application or removal.
# The descriptions provide context for users in multiple languages.
# This file is part of the WinISOUtil project and is used to manage system tweaks.

$allTweaks = @(
    [PSCustomObject]@{ 
        ID = 'WU_NotifyDownload'; 
        Description_tr = "Windows Update: İndirmeden önce bildir"; 
        Description_en = "Windows Update: Notify before downloading";
        Action = "WU_Handler" 
    },
    [PSCustomObject]@{ 
        ID = 'WU_NotifyInstall'; 
        Description_tr = "Windows Update: Otomatik indir, yüklemeden önce bildir"; 
        Description_en = "Windows Update: Download automatically, notify before installing";
        Action = "WU_Handler" 
    },
    [PSCustomObject]@{ 
        ID = 'AddDesktopIcons'; 
        Description_tr = "Masaüstüne temel simgeleri ekle (Bu Bilgisayar, Geri Dönüşüm Kutusu ve Kullanıcı Klasörü)"; 
        Description_en = "Add basic icons to Desktop (This PC, Recycle Bin, and User Folder)"; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
            Set-ItemProperty -Path $path -Name '{20D04FE0-3AEA-1069-A2D8-08002B30309D}' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name '{59031a47-3f72-44a7-89c5-5595fe6b30ee}' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'ConfigureTaskbar'; 
        Description_tr = "Görev Çubuğu'nu yapılandır (Sola hizala, Görev Görünümü ve Widget simgelerini gizle ve Sağ Tık menüsüne görevi Sonlandır ekle)"; 
        Description_en = "Configure Taskbar (Align left, hide Task View/Widgets icons, and add End Task to context menu)"; 
        Action = "InlineScript"; 
        Code = {
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Name 'TaskbarEndTask' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Dsh' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Name 'NoPinningStoreToTaskbar' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\Explorer' -Name 'NoPinningStoreToTaskbar' -Value 1 -Type DWord -Force

        }
    },
    [PSCustomObject]@{ 
        ID = 'HideSearchIcon';
        Description_tr = "Görev çubuğunda Arama simgesini gizle"; 
        Description_en = "Hide the Search icon on the taskbar";
        Action = "SetupScript"; 
        Code = "try { Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Value 0 -Type DWord -Force } catch {}"
    },
    [PSCustomObject]@{ 
        ID = 'ConfigureFileExplorer'; 
        Description_tr = "Dosya Gezgini'ni yapılandır (Bu Bilgisayar ile başlat, Kompakt Görünüm, Detaylı Kopyalama Diyaloğu ve Dosya Uzantılarını etkinleştir)"; 
        Description_en = "Configure File Explorer (Start with This PC, Compact View, Detailed Copy Dialog, and show extensions)"; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Set-ItemProperty -Path $path -Name 'HideFileExt' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'UseCompactMode' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'LaunchTo' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager' -Name 'EnthusiastMode' -Value 1 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'ConfigureStartMenu'; 
        Description_tr = "Başlat Menüsü'nü yapılandır (Önerilenleri gizle, Bing aramasını kapat)"; 
        Description_en = "Configure Start Menu (Hide recommendations, disable Bing search)"; 
        Action = "InlineScript"; 
        Code = {
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Search' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'BingSearchEnabled' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\Explorer' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Name 'HideRecommendedSection' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Start' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Start' -Name 'HideRecommendedSection' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Education' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Education' -Name 'IsEducationEnvironment' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_Layout' -Value 1 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisablePrivacyAndTelemetry'; 
        Description_tr = "Gizliliği ihlal eden telemetri, veri toplama ve tanıma servislerini kapat"; 
        Description_en = "Disable privacy-invading telemetry, data collection, and recognition services"; 
        Action = "InlineScript"; 
        Code = {
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
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'SettingsPageVisibility' -Value 'hide:home' -Type String -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableAdsAndSuggestions'; 
        Description_tr = "Windows genelinde önerilen uygulamalar, reklam, ipucu ve önerileri devre dışı bırak"; 
        Description_en = "Disable suggested apps, ads, tips, and suggestions across Windows"; 
        Action = "InlineScript"; 
        Code = {
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
    },
    [PSCustomObject]@{ 
        ID = 'DisableSpotlight'; 
        Description_tr = "Windows Spotlight duvar kağıdı ve özelliklerini devre dışı bırak"; 
        Description_en = "Disable Windows Spotlight wallpaper and features"; 
        Action = "InlineScript"; 
        Code = {
            New-Item -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsSpotlightFeatures' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent' -Name 'DisableSpotlightCollectionOnDesktop' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Control Panel\Desktop' -Name 'WallPaper' -Value 'C:\Windows\Web\Wallpaper\Windows\img0.jpg' -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableWindowsAIFeatures'; 
        Description_tr = "Windows Copilot, Recall ve diğer AI özelliklerini devre dışı bırak"; 
        Description_en = "Disable Windows Copilot, Recall, and other AI features"; 
        Action = "InlineScript"; 
        Code = {
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
    },
    [PSCustomObject]@{ 
        ID = 'DisableEdgeAIFeatures'; 
        Description_tr = "Microsoft Edge'deki Copilot, Kenar Çubuğu ve diğer AI özelliklerini kapat"; 
        Description_en = "Disable Copilot, Sidebar, and other AI features in Microsoft Edge"; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\Policies\Microsoft\Edge'
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $path -Name 'CopilotPageContext' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'HubsSidebarEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'EdgeHistoryAISearchEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'ComposeInlineEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'NewTabPageBingChatEnabled' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableEdgeContentFeatures'; 
        Description_tr = "Edge'deki alışveriş asistanı, MSN haberleri ve diğer içerik özelliklerini kapat"; 
        Description_en = "Disable shopping assistant, MSN news, and other content features in Edge"; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\Policies\Microsoft\Edge'
            New-Item -Path $path -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $path -Name 'NewTabPageContentEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'EdgeShoppingAssistantEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'PersonalizationReportingEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'DiagnosticData' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableOemApps'; 
        Description_tr = "Hazır kurulu OEM uygulamalarını ve önerilerini engelle"; 
        Description_en = "Block pre-installed OEM apps and suggestions"; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            Set-ItemProperty -Path $path -Name 'OemPreInstalledAppsEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'PreInstalledAppsEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'PreInstalledAppsEverEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'SilentInstalledAppsEnabled' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'EnableRestartApps';
        Description_tr = "Yeniden başlatırken uygulamaları otomatik olarak geri yükle"; 
        Description_en = "Automatically restore apps on restart"; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKU\TEMP\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $path -Name 'RestartApps' -Value 1 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'ForceOfflineAccount'; 
        Description_tr = "Kurulumda çevrimdışı (yerel) hesap kullanmaya zorla (OOBE)"; 
        Description_en = "Force using an offline (local) account during setup (OOBE)"; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\Microsoft\Windows\CurrentVersion\OOBE'
            Set-ItemProperty -Path $path -Name 'BypassNRO' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'HideOnlineAccountScreens' -Value 1 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableStickyKeys'; 
        Description_tr = "Yapışkan Tuşlar uyarılarını devre dışı bırak"; 
        Description_en = "Disable Sticky Keys prompts"; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKU\TEMP\Control Panel\Accessibility\StickyKeys'
            Set-ItemProperty -Path $path -Name 'Flags' -Value '506' -Type String -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'EnableStorageSense'; 
        Description_tr = "Depolama Bilincini (Storage Sense) etkinleştir ve otomatik çalıştır"; 
        Description_en = "Enable and autorun Storage Sense"; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\StorageSense'
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $path -Name 'AllowStorageSenseTemporaryFilesCleanup' -Value 1 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableEdgeShortcut'; 
        Description_tr = "Microsoft Edge otomatik masaüstü kısayolu oluşturmayı devre dışı bırak"; 
        Description_en = "Disable automatic Microsoft Edge desktop shortcut creation"; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\Policies\Microsoft\EdgeUpdate'
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $path -Name 'CreateDesktopShortcutDefault' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableOneDriveSetup'; 
        Description_tr = "OneDrive'in başlangıçta otomatik çalışmasını engelle"; 
        Description_en = "Prevent OneDrive from running automatically at startup"; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Run'
            Remove-ItemProperty -Path $path -Name 'OneDriveSetup' -Force
        }
    }
)