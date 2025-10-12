# Define a list of applications to exclude from removal during system cleanup
# Note: The asterisk (*) acts as a wildcard to match any version of the application
# This script creates an array of strings representing each application to be excluded

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
