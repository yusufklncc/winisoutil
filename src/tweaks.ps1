# Define all available tweaks and their actions.
# This file only contains the unique ID and the action/code for each tweak.
# All user-facing descriptions are stored in 'languages.ps1' for easier localization.
# The main script will fetch the description from the language file using a key like 'tweak_ID_desc'.
# This file is part of the WinISOUtil project.

$allTweaks = @(
    [PSCustomObject]@{ 
        ID = 'WU_NotifyDownload'; 
        Action = "WU_Handler" 
    },
    [PSCustomObject]@{ 
        ID = 'WU_NotifyInstall'; 
        Action = "WU_Handler" 
    },
    [PSCustomObject]@{ 
        ID = 'AddDesktopIcons'; 
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
        Action = "InlineScript"; 
        Code = {
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Name 'TaskbarEndTask' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Dsh' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Name 'NoPinningStoreToTaskbar' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\Explorer' -Name 'NoPinningStoreToTaskbar' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Name 'HideRecommendedSection' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Name 'HideSCAMeetNow' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\Windows\Windows Chat' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\Windows\Windows Chat' -Name 'ChatIcon' -Value 3 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'HideSearchIcon';
        Action = "SetupScript"; 
        Code = "try { Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Value 0 -Type DWord -Force } catch {}"
    },
    [PSCustomObject]@{ 
        ID = 'ConfigureFileExplorer'; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Set-ItemProperty -Path $path -Name 'HideFileExt' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'UseCompactMode' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'LaunchTo' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager' -Name 'EnthusiastMode' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\NamingTemplates' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\NamingTemplates' -Name 'ShortcutNameTemplate' -Value '"%s.lnk"' -Type String -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'MultipleInvokePromptMinimum' -Value 100 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'ConfigureStartMenu'; 
        Action = "InlineScript"; 
        Code = {
            # Disable Bing Search
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Search' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'BingSearchEnabled' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\Explorer' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Windows Search' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Windows Search' -Name 'DisableWebSearch' -Value 1 -Type DWord -Force
            
            # Disable Recommendations
            $advPath = 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Set-ItemProperty -Path $advPath -Name 'Start_IrisRecommendations' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $advPath -Name 'Start_AccountNotifications' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Start' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Start' -Name 'HideRecommendedSection' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Education' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Education' -Name 'IsEducationEnvironment' -Value 1 -Type DWord -Force

        }
    },
    [PSCustomObject]@{ 
        ID = 'DisablePrivacyAndTelemetry'; 
        Action = "InlineScript"; 
        Code = {
            # --- General Data Collection & Telemetry ---
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DataCollection' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DataCollection' -Name 'MaxTelemetryAllowed' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DataCollection' -Name 'AllowDeviceNameInTelemetry' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DataCollection' -Name 'DoNotShowFeedbackNotifications' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Name 'AllowTelemetry' -Value 0 -Type DWord -Force

            # --- Advertising & Tailored Experiences ---
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\AdvertisingInfo' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\AdvertisingInfo' -Name 'DisabledByGroupPolicy' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Privacy' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Privacy' -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent' -Name 'DisableTailoredExperiencesWithDiagnosticData' -Value 1 -Type DWord -Force
            
            # --- Input & Handwriting Telemetry ---
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\TabletPC' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\TabletPC' -Name 'PreventHandwritingDataSharing' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\HandwritingErrorReports' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\HandwritingErrorReports' -Name 'PreventHandwritingErrorReports' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Input\TIPC' -Name 'Enabled' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\Input\TIPC' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\Input\TIPC' -Name 'Enabled' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\InputPersonalization' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\InputPersonalization' -Name 'RestrictImplicitInkCollection' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\InputPersonalization' -Name 'RestrictImplicitTextCollection' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore' -Name 'HarvestContacts' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Input\Settings' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Input\Settings' -Name 'InsightsEnabled' -Value 0 -Type DWord -Force

            # --- Other Telemetry (CEIP, KMS, Diagnostics, etc.) ---
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\System' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\System' -Name 'PublishUserActivities' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\System' -Name 'UploadUserActivities' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' -Name 'HasAccepted' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_TrackProgs' -Value 0 -Type DWord -Force
            $siufPath = 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Siuf\Rules'
            New-Item -Path $siufPath -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $siufPath -Name 'NumberOfSIUFInPeriod' -Value 0 -Type DWord -Force
            Remove-ItemProperty -Path $siufPath -Name 'PeriodInNanoSeconds' -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'SettingsPageVisibility' -Value 'hide:home' -Type String -Force
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\AppV\CEIP' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\AppV\CEIP' -Name 'CEIPEnable' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\SQMClient\Windows' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\SQMClient\Windows' -Name 'CEIPEnable' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance' -Name 'DisableDiagnosticTracing' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\Windows\Messaging' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\Windows\Messaging' -Name 'AllowMessageSync' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform' -Name 'NoGenTicket' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack' -Name 'ShowedToastAtLevel' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey' -Name 'EnableEventTranscript' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey' -Name 'MiniTraceSlotEnabled' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableAdsAndSuggestions'; 
        Action = "InlineScript"; 
        Code = {
            # Disable general ads and consumer features
            $cloudContentPath = 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\CloudContent'
            New-Item -Path $cloudContentPath -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableWindowsConsumerFeatures' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableSoftLanding' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableCloudOptimizedContent' -Value 1 -Type DWord -Force
            $contentDeliveryPath = 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            Set-ItemProperty -Path $contentDeliveryPath -Name 'SubscribedContent-338387Enabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $contentDeliveryPath -Name 'SubscribedContent-338389Enabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $contentDeliveryPath -Name 'SubscribedContent-310093Enabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $contentDeliveryPath -Name 'SubscribedContent-338388Enabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $contentDeliveryPath -Name 'OemPreInstalledAppsEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $contentDeliveryPath -Name 'PreInstalledAppsEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $contentDeliveryPath -Name 'PreInstalledAppsEverEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $contentDeliveryPath -Name 'SilentInstalledAppsEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'SettingsPageNotifications' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications' -Name 'EnableAccountNotifications' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' -Name 'ScoobeSystemSettingEnabled' -Value 0 -Type DWord -Force
            
            # Disable Settings Banner (Win 11 22000+)
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\ValueBanner.IdealStateFeatureControlProvider' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\ValueBanner.IdealStateFeatureControlProvider' -Name 'ActivationType' -Value 0 -Type DWord -Force
            
            # Disable Settings Tips
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\PolicyManager\default\Settings\AllowOnlineTips' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\PolicyManager\default\Settings\AllowOnlineTips' -Name 'value' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Name 'AllowOnlineTips' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableSpotlight'; 
        Action = "InlineScript"; 
        Code = {
            $cloudContentPath = 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent'
            New-Item -Path $cloudContentPath -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableWindowsSpotlightFeatures' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableWindowsSpotlightWindowsWelcomeExperience' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableWindowsSpotlightOnActionCenter' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableWindowsSpotlightOnSettings' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableThirdPartySuggestions' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableSpotlightCollectionOnDesktop' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Control Panel\Desktop' -Name 'WallPaper' -Value 'C:\Windows\Web\Wallpaper\Windows\img0.jpg' -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableWindowsAIFeatures'; 
        Action = "InlineScript"; 
        Code = {
            New-Item -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\WindowsCopilot' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsAI' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowRecallEnablement' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsAI' -Name 'TurnOffSavingSnapshots' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Name 'EnableFeeds' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\WindowsNotepad' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\WindowsNotepad' -Name 'DisableAIFeatures' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Microsoft\Windows\CurrentVersion\Policies\Paint' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Microsoft\Windows\CurrentVersion\Policies\Paint' -Name 'DisableCocreator' -Value 1 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableEdgeAIFeatures'; 
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
        ID = 'DisableSystemPerformanceTweaks';
        Action = "InlineScript"; 
        Code = {
            # Disable Aero Shake
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'DisallowShaking' -Value 1 -Type DWord -Force
            # Disable Menu Hover Delay
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '20' -Type String -Force
            # Disable Startup Delay
            New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Name 'StartupDelayInMSec' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'ConfigureCrashControl'; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\SYSTEM\CurrentControlSet\Control\CrashControl'
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $path -Name 'AutoReboot' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'CrashDumpEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'LogEvent' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'DisplayParameters' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SYSTEM\CurrentControlSet\Control\CrashControl\StorageTelemetry' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SYSTEM\CurrentControlSet\Control\CrashControl\StorageTelemetry' -Name 'DeviceDumpEnabled' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableSecurityRisks'; 
        Action = "SetupScript"; 
        Code = {
            # Disable WPBT (Windows Platform Binary Table)
            $path = 'Registry::HKLM\SYSTEM\CurrentControlSet\Control\Session Manager'
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $path -Name 'DisableWpbtExecution' -Value 1 -Type DWord -Force
            
            # Disable Remote Assistance
            $raPath = 'Registry::HKLM\SYSTEM\CurrentControlSet\Control\Remote Assistance'
            New-Item -Path $raPath -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $raPath -Name 'fAllowFullControl' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $raPath -Name 'fAllowToGetHelp' -Value 0 -Type DWord -Force
            
            # Disable Remote Assistance Firewall Rule
            netsh advfirewall firewall set rule group="Remote Assistance" new enable=no
        }
    },
    [PSCustomObject]@{ 
        ID = 'EnableRestartApps';
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKU\TEMP\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $path -Name 'RestartApps' -Value 1 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'ForceOfflineAccount'; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\Microsoft\Windows\CurrentVersion\OOBE'
            Set-ItemProperty -Path $path -Name 'BypassNRO' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'HideOnlineAccountScreens' -Value 1 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableStickyKeys'; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKU\TEMP\Control Panel\Accessibility\StickyKeys'
            Set-ItemProperty -Path $path -Name 'Flags' -Value '506' -Type String -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'EnableStorageSense'; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\StorageSense'
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $path -Name 'AllowStorageSenseTemporaryFilesCleanup' -Value 1 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableEdgeShortcut'; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\Policies\Microsoft\EdgeUpdate'
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $path -Name 'CreateDesktopShortcutDefault' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableStoreAutoUpdate';
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate'
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $path -Name 'AutoDownload' -Value 2 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableOneDriveSetup'; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Run'
            Remove-ItemProperty -Path $path -Name 'OneDriveSetup' -Force -ErrorAction SilentlyContinue
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableErrorReporting'; 
        Action = "InlineScript"; 
        Code = {
            # Disable Windows Error Reporting
            New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\PCHealth\ErrorReporting' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\PCHealth\ErrorReporting' -Name 'DoReport' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Windows Error Reporting' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Windows Error Reporting' -Name 'DontShowUI' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\PCHealth\ErrorReporting' -Name 'ShowUI' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Windows Error Reporting' -Name 'LoggingDisabled' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Windows Error Reporting' -Name 'DontSendAdditionalData' -Value 1 -Type DWord -Force
            
            # Disable WER for driver installations
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DeviceInstall\Settings' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DeviceInstall\Settings' -Name 'DisableSendGenericDriverNotFoundToWER' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DeviceInstall\Settings' -Name 'DisableSendRequestAdditionalSoftwareToWER' -Value 1 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableOfficeTelemetry'; 
        Action = "InlineScript"; 
        Code = {
            # Disable Office Customer Experience Program and Data Sending
            $officeCommonPath = 'Registry::HKU\TEMP\Software\Policies\Microsoft\office\16.0\common'
            New-Item -Path $officeCommonPath -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $officeCommonPath -Name 'sendcustomerdata' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $officeCommonPath -Name 'qmenable' -Value 0 -Type DWord -Force

            # Disable Office Telemetry Sending
            $officeTelemetryPath = 'Registry::HKU\TEMP\Software\Policies\Microsoft\office\common\clienttelemetry'
            New-Item -Path $officeTelemetryPath -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $officeTelemetryPath -Name 'sendtelemetry' -Value 3 -Type DWord -Force
        }
    }
)