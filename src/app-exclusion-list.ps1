# Bu dosya, Remove-WindowsApps fonksiyonu tarafından kullanılacak olan ve
# kaldırılmaması gereken kritik uygulama paketlerinin bir listesini içerir.
# Liste, joker karakter (*) kullanımını destekler.

$appExclusionList = @(
    "Microsoft.ApplicationCompatibilityEnhancements*",
    "Microsoft.AV1VideoExtension*",
    "Microsoft.AVCEncoderVideoExtension*",
    "Microsoft.BingSearch*",
    "Microsoft.DesktopAppInstaller*",
    "Microsoft.HEIFImageExtension*",
    "Microsoft.HEVCVideoExtension*",
    "Microsoft.MPEG2VideoExtension*",
    "Microsoft.RawImageExtension*",
    "Microsoft.SecHealthUI*",
    "Microsoft.StorePurchaseApp*",
    "Microsoft.VP9VideoExtensions*",
    "Microsoft.WebMediaExtensions*",
    "Microsoft.WebpImageExtension*",
    "Microsoft.WindowsStore*",
    "MicrosoftWindows.Client.WebExperience*"
)
