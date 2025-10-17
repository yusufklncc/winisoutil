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
            # Makes the "This PC" icon visible on the desktop.
            Set-ItemProperty -Path $path -Name '{20D04FE0-3AEA-1069-A2D8-08002B30309D}' -Value 0 -Type DWord -Force
            # Makes the "Recycle Bin" icon visible on the desktop.
            Set-ItemProperty -Path $path -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Value 0 -Type DWord -Force
            # Makes the "User's Files" icon visible on the desktop.
            Set-ItemProperty -Path $path -Name '{59031a47-3f72-44a7-89c5-5595fe6b30ee}' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'ConfigureTaskbar'; 
        Action = "InlineScript"; 
        Code = {
            # Aligns the taskbar to the left side of the screen.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -Value 0 -Type DWord -Force
            # Hides Task View button
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton' -Value 0 -Type DWord -Force
            # Hides Widgets button
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn' -Value 0 -Type DWord -Force
            # Enables "End task" option on right-clicking taskbar icons
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Name 'TaskbarEndTask' -Value 1 -Type DWord -Force
            # Disable News and Interests
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Dsh' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests' -Value 0 -Type DWord -Force
            # Disable pinning Microsoft Store to taskbar 
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Name 'NoPinningStoreToTaskbar' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\Explorer' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\Explorer' -Name 'NoPinningStoreToTaskbar' -Value 1 -Type DWord -Force
            # Hides Recommended section from taskbar Start Menu
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Name 'HideRecommendedSection' -Value 1 -Type DWord -Force
            # Hide Meet Now icon from taskbar
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Name 'HideSCAMeetNow' -Value 1 -Type DWord -Force
            # Disable Chat icon from taskbar
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
            # Show file extensions
            Set-ItemProperty -Path $path -Name 'HideFileExt' -Value 0 -Type DWord -Force
            # Compact view by default
            Set-ItemProperty -Path $path -Name 'UseCompactMode' -Value 1 -Type DWord -Force
            # Open "This PC" by default
            Set-ItemProperty -Path $path -Name 'LaunchTo' -Value 1 -Type DWord -Force
            # Detailed copy/move dialog
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager' -Name 'EnthusiastMode' -Value 1 -Type DWord -Force
            # Removes the "- Shortcut" text that Windows automatically adds to the end of new shortcut file names.
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\NamingTemplates' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\NamingTemplates' -Name 'ShortcutNameTemplate' -Value '"%s.lnk"' -Type String -Force
            # Increase the number of items that can be selected before a confirmation prompt appears when performing bulk actions.
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
            # Disable Search Suggestions 
            New-Item -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\Explorer' -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1 -Type DWord -Force
            # Disable Web Search in Search Box
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
            # Disables Telemetry and data collection, preventing Windows from sending diagnostic and usage data to Microsoft.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -Type DWord -Force
            # Sets the maximum allowed telemetry level to the most restrictive (basic) setting, further limiting data collection for privacy.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DataCollection' -Name 'MaxTelemetryAllowed' -Value 0 -Type DWord -Force
            # Disables the inclusion of the device name in telemetry data sent to Microsoft.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DataCollection' -Name 'AllowDeviceNameInTelemetry' -Value 0 -Type DWord -Force
            # Prevents Windows from displaying feedback notifications that prompt users to provide feedback about their experience.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\DataCollection' -Name 'DoNotShowFeedbackNotifications' -Value 1 -Type DWord -Force
            # Disables the collection of telemetry data from 32-bit applications running on 64-bit Windows systems.
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Name 'AllowTelemetry' -Value 0 -Type DWord -Force

            # --- Advertising & Tailored Experiences ---
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\AdvertisingInfo' -Force -ErrorAction SilentlyContinue | Out-Null
            #  Disables advertising ID, preventing apps from using it to deliver personalized ads.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\AdvertisingInfo' -Name 'DisabledByGroupPolicy' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Force -ErrorAction SilentlyContinue | Out-Null
            #  Disables advertising ID for the current user, preventing apps from using it to deliver personalized ads.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Privacy' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables tailored experiences based on diagnostic data, preventing personalized content and recommendations.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Privacy' -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables tailored experiences based on diagnostic data for the current user.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent' -Name 'DisableTailoredExperiencesWithDiagnosticData' -Value 1 -Type DWord -Force
            
            # --- Input & Handwriting Telemetry ---
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\TabletPC' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables handwriting data sharing, preventing the collection and sharing of handwriting input data.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\TabletPC' -Name 'PreventHandwritingDataSharing' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\HandwritingErrorReports' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables handwriting error reports, preventing the sending of error reports related to handwriting input.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\HandwritingErrorReports' -Name 'PreventHandwritingErrorReports' -Value 1 -Type DWord -Force
            # Disables Text Input Personalization, preventing the collection of typing and input data for personalization purposes.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Input\TIPC' -Name 'Enabled' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\Input\TIPC' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables the Text Input Personalization feature, preventing the collection of typing and input data for personalization purposes.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\Input\TIPC' -Name 'Enabled' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\InputPersonalization' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables implicit ink and text collection, preventing the collection of handwriting and text input data for personalization.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\InputPersonalization' -Name 'RestrictImplicitInkCollection' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\InputPersonalization' -Name 'RestrictImplicitTextCollection' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables contact harvesting, preventing the collection of contact data for personalization purposes.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore' -Name 'HarvestContacts' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Input\Settings' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables input insights, preventing the collection of input data for insights and personalization.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Input\Settings' -Name 'InsightsEnabled' -Value 0 -Type DWord -Force

            # --- Other Telemetry (CEIP, KMS, Diagnostics, etc.) ---
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\System' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables User Activity Publishing and Uploading, preventing the publishing of user activities to Microsoft services.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\System' -Name 'PublishUserActivities' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\System' -Name 'UploadUserActivities' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables online speech recognition, preventing the use of online speech services for recognition tasks.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' -Name 'HasAccepted' -Value 0 -Type DWord -Force
            # Disables Start Menu program tracking, preventing Windows from tracking and suggesting frequently used programs.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_TrackProgs' -Value 0 -Type DWord -Force
            $siufPath = 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Siuf\Rules'
            New-Item -Path $siufPath -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables the SIUF (Software Improvement User Feedback) feature, preventing Windows from collecting user feedback for software improvement.
            Set-ItemProperty -Path $siufPath -Name 'NumberOfSIUFInPeriod' -Value 0 -Type DWord -Force
            # Removes the periodic SIUF data collection interval, effectively disabling periodic feedback prompts.
            Remove-ItemProperty -Path $siufPath -Name 'PeriodInNanoSeconds' -Force -ErrorAction SilentlyContinue
            # Hides the Settings page related to privacy and telemetry to prevent user access.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'SettingsPageVisibility' -Value 'hide:home' -Type String -Force
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\AppV\CEIP' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables the Customer Experience Improvement Program (CEIP) for App-V, preventing participation in the program.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\AppV\CEIP' -Name 'CEIPEnable' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\SQMClient\Windows' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\SQMClient\Windows' -Name 'CEIPEnable' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables diagnostic tracing for performance monitoring, preventing the collection of performance-related diagnostic data.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance' -Name 'DisableDiagnosticTracing' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\Windows\Messaging' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables message synchronization, preventing the synchronization of messages across devices.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\Windows\Messaging' -Name 'AllowMessageSync' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables toast notifications related to diagnostics tracking.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack' -Name 'ShowedToastAtLevel' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables event transcript logging for diagnostics tracking.
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey' -Name 'EnableEventTranscript' -Value 0 -Type DWord -Force
            # Disables mini trace slot logging for diagnostics tracking.
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
            # Disables Windows consumer features, preventing the display of consumer-oriented content and suggestions.
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableWindowsConsumerFeatures' -Value 1 -Type DWord -Force
            # Disables soft landing, preventing Windows from displaying promotional content when users interact with certain features.
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableSoftLanding' -Value 1 -Type DWord -Force
            # Disables cloud-optimized content, preventing Windows from downloading and displaying content optimized for cloud services.
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableCloudOptimizedContent' -Value 1 -Type DWord -Force
            $contentDeliveryPath = 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            # Disables "Suggested Apps" from being automatically installed from the Microsoft Store.
            Set-ItemProperty -Path $contentDeliveryPath -Name 'SubscribedContent-338387Enabled' -Value 0 -Type DWord -Force
            # Disables tips, tricks, and fun facts from appearing on the Windows lock screen.
            Set-ItemProperty -Path $contentDeliveryPath -Name 'SubscribedContent-338389Enabled' -Value 0 -Type DWord -Force
            # Disables the "Windows Welcome Experience", which sometimes appears after updates to highlight new features.
            Set-ItemProperty -Path $contentDeliveryPath -Name 'SubscribedContent-310093Enabled' -Value 0 -Type DWord -Force
            # Disables suggestions in the Start Menu (like recommended apps) and throughout Windows.
            Set-ItemProperty -Path $contentDeliveryPath -Name 'SubscribedContent-338388Enabled' -Value 0 -Type DWord -Force
            # Disables the automatic installation of pre-installed apps that come with Windows.
            Set-ItemProperty -Path $contentDeliveryPath -Name 'OemPreInstalledAppsEnabled' -Value 0 -Type DWord -Force
            # Disables the automatic installation of pre-installed apps that were ever enabled.
            Set-ItemProperty -Path $contentDeliveryPath -Name 'PreInstalledAppsEnabled' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $contentDeliveryPath -Name 'PreInstalledAppsEverEnabled' -Value 0 -Type DWord -Force
            # Disables the automatic installation of apps that were silently installed.
            Set-ItemProperty -Path $contentDeliveryPath -Name 'SilentInstalledAppsEnabled' -Value 0 -Type DWord -Force
            # Disables notifications and suggestions that appear within the Windows Settings app.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'SettingsPageNotifications' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables account-related notifications in the Settings app.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications' -Name 'EnableAccountNotifications' -Value 0 -Type DWord -Force
            New-Item -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables notifications that suggest "Ways to finish setting up your device," which often prompt you to sign in with a Microsoft Account or enable cloud services.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' -Name 'ScoobeSystemSettingEnabled' -Value 0 -Type DWord -Force
            
            # Disables the Settings Banner feature that displays tips and suggestions in the Settings app. (Win 11 22000+)
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\ValueBanner.IdealStateFeatureControlProvider' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\ValueBanner.IdealStateFeatureControlProvider' -Name 'ActivationType' -Value 0 -Type DWord -Force
            
            # Disables online tips in the Settings app, preventing Windows from displaying tips and suggestions sourced from online content.
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\PolicyManager\default\Settings\AllowOnlineTips' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\PolicyManager\default\Settings\AllowOnlineTips' -Name 'value' -Value 0 -Type DWord -Force
            # Disables online tips in File Explorer, preventing Windows from displaying tips and suggestions sourced from online content.
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Name 'AllowOnlineTips' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableSpotlight'; 
        Action = "InlineScript"; 
        Code = {
            $cloudContentPath = 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent'
            New-Item -Path $cloudContentPath -Force -ErrorAction SilentlyContinue | Out-Null
            # Disables Windows Spotlight features, preventing the display of dynamic content and suggestions on the lock screen and desktop.
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableWindowsSpotlightFeatures' -Value 1 -Type DWord -Force
            # Disables Windows Spotlight on the lock screen, preventing the display of Spotlight images and suggestions.
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableWindowsSpotlightWindowsWelcomeExperience' -Value 1 -Type DWord -Force
            # Disables Windows Spotlight suggestions in the Action Center.
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableWindowsSpotlightOnActionCenter' -Value 1 -Type DWord -Force
            # Disables Windows Spotlight suggestions in the Settings app.
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableWindowsSpotlightOnSettings' -Value 1 -Type DWord -Force
            # Disables third-party suggestions provided by Windows Spotlight.
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableThirdPartySuggestions' -Value 1 -Type DWord -Force
            # Disables Windows Spotlight collection on the desktop, preventing dynamic desktop backgrounds from Spotlight.
            Set-ItemProperty -Path $cloudContentPath -Name 'DisableSpotlightCollectionOnDesktop' -Value 1 -Type DWord -Force
            # Sets a static wallpaper by disabling the dynamic wallpaper feature of Windows Spotlight.
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Control Panel\Desktop' -Name 'WallPaper' -Value 'C:\Windows\Web\Wallpaper\Windows\img0.jpg' -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableWindowsAIFeatures'; 
        Action = "InlineScript"; 
        Code = {
            New-Item -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\WindowsCopilot' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disable Windows Copilot UI and functionality
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsAI' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disable Recall Enablement, Saving Snapshots, and AI Data Analysis features
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowRecallEnablement' -Value 0 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsAI' -Name 'TurnOffSavingSnapshots' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis' -Value 1 -Type DWord -Force
            New-Item -Path 'Registry::HKLM\TEMP\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Force -ErrorAction SilentlyContinue | Out-Null
            # Disable AI features in Notepad
            New-Item -Path 'Registry::HKLM\TEMP\WindowsNotepad' -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path 'Registry::HKLM\TEMP\WindowsNotepad' -Name 'DisableAIFeatures' -Value 1 -Type DWord -Force
            # Disable AI features in Paint
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
            # Disables the Microsoft Edge Copilot from reading or using the content of the web page you are currently viewing.
            Set-ItemProperty -Path $path -Name 'CopilotPageContext' -Value 0 -Type DWord -Force
            # Disables the Microsoft Edge Copilot sidebar feature.
            Set-ItemProperty -Path $path -Name 'HubsSidebarEnabled' -Value 0 -Type DWord -Force
            # Disables AI-powered search suggestions in the Edge address bar.
            Set-ItemProperty -Path $path -Name 'EdgeHistoryAISearchEnabled' -Value 0 -Type DWord -Force
            # Disables the inline AI compose feature in Microsoft Edge.
            Set-ItemProperty -Path $path -Name 'ComposeInlineEnabled' -Value 0 -Type DWord -Force
            # Disables the Bing Chat feature on the New Tab Page in Microsoft Edge.
            Set-ItemProperty -Path $path -Name 'NewTabPageBingChatEnabled' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableEdgeContentFeatures'; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\Policies\Microsoft\Edge'
            New-Item -Path $path -ErrorAction SilentlyContinue | Out-Null
            # Disables content suggestions on the New Tab Page in Microsoft Edge.
            Set-ItemProperty -Path $path -Name 'NewTabPageContentEnabled' -Value 0 -Type DWord -Force
            # Disables the Shopping Assistant feature in Microsoft Edge, which provides price comparisons and coupons.
            Set-ItemProperty -Path $path -Name 'EdgeShoppingAssistantEnabled' -Value 0 -Type DWord -Force
            # Disables the reporting of personalization data in Microsoft Edge, which prevents the browser from sending usage information to tailor content and ads.
            Set-ItemProperty -Path $path -Name 'PersonalizationReportingEnabled' -Value 0 -Type DWord -Force
            # Disables the collection of diagnostic data by Microsoft Edge.
            Set-ItemProperty -Path $path -Name 'DiagnosticData' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableSystemPerformanceTweaks';
        Action = "InlineScript"; 
        Code = {
            # Disables Aero Shake
            Set-ItemProperty -Path 'Registry::HKU\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'DisallowShaking' -Value 1 -Type DWord -Force
            # Disables Menu Hover Delay
            Set-ItemProperty -Path 'Registry::HKU\TEMP\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '40' -Type String -Force
            # Disables Startup Delay
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
            # Disables automatic reboot on system crash
            Set-ItemProperty -Path $path -Name 'AutoReboot' -Value 0 -Type DWord -Force
            # Configures the system to create a complete memory dump on crash
            Set-ItemProperty -Path $path -Name 'CrashDumpEnabled' -Value 1 -Type DWord -Force
            # Sets the dump file location to %SystemRoot%\MEMORY.DMP
            Set-ItemProperty -Path $path -Name 'DisplayParameters' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $path -Name 'DumpFile' -Value '%SystemRoot%\MEMORY.DMP' -Type String -Force
            # Sets the minimum free space for dump file creation to 768 MB
            Set-ItemProperty -Path $path -Name 'MinDumpSpace' -Value 768 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'EnableRestartApps';
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKU\TEMP\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            # Enables the feature that allows Windows to restart apps that were open before a shutdown or restart.
            Set-ItemProperty -Path $path -Name 'RestartApps' -Value 1 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'ForceOfflineAccount'; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\Microsoft\Windows\CurrentVersion\OOBE'
            # Forces the use of offline accounts during the Out-Of-Box Experience (OOBE) setup process.
            Set-ItemProperty -Path $path -Name 'BypassNRO' -Value 1 -Type DWord -Force
            # Hides the online account creation screens during OOBE.
            Set-ItemProperty -Path $path -Name 'HideOnlineAccountScreens' -Value 1 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableStickyKeys'; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKU\TEMP\Control Panel\Accessibility\StickyKeys'
            # Disables the Sticky Keys feature, which allows users to press modifier keys (like Shift, Ctrl, Alt) one at a time instead of simultaneously.
            Set-ItemProperty -Path $path -Name 'Flags' -Value '506' -Type String -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'EnableStorageSense'; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\StorageSense'
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            # Enables Storage Sense, a feature that automatically frees up disk space by deleting unnecessary files.
            Set-ItemProperty -Path $path -Name 'AllowStorageSense' -Value   1 -Type DWord -Force
            # Configures Storage Sense to automatically clean up temporary files.
            Set-ItemProperty -Path $path -Name 'AllowStorageSenseTemporaryFilesCleanup' -Value 1 -Type DWord -Force   
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableEdgeShortcut'; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\Policies\Microsoft\EdgeUpdate'
            # Prevents Microsoft Edge from creating a desktop shortcut during installation or updates.
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $path -Name 'CreateDesktopShortcutDefault' -Value 0 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableStoreAutoUpdate';
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKLM\TEMP\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate'
            # Disables automatic updates for apps installed from the Microsoft Store.
            New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $path -Name 'AutoDownload' -Value 2 -Type DWord -Force
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableOneDriveSetup'; 
        Action = "InlineScript"; 
        Code = {
            $path = 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Run'
            # Disables the OneDrive setup process that runs at user login.
            Remove-ItemProperty -Path $path -Name 'OneDriveSetup' -Force -ErrorAction SilentlyContinue
        }
    },
    [PSCustomObject]@{ 
        ID = 'DisableOfficeTelemetry'; 
        Action = "InlineScript"; 
        Code = {
            # Disables participation in the Office Customer Experience Improvement Program.
            $officeCommonPath = 'Registry::HKU\TEMP\Software\Policies\Microsoft\office\16.0\common'
            New-Item -Path $officeCommonPath -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $officeCommonPath -Name 'sendcustomerdata' -Value 0 -Type DWord -Force

            # Disables the sending of telemetry data from Office applications.
            $officeTelemetryPath = 'Registry::HKU\TEMP\Software\Policies\Microsoft\office\common\clienttelemetry'
            New-Item -Path $officeTelemetryPath -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $officeTelemetryPath -Name 'sendtelemetry' -Value 3 -Type DWord -Force
        }
    }
)