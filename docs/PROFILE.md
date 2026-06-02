# Schema Version 3 Profiles

WinISOUtil profiles store reviewed customization selections for interactive
imports and unattended runs. New exports use `SchemaVersion: 3`.

## Contract

Version 2 introduced stable `RemovedAppSelectors` values so monthly AppX
package version changes do not invalidate reviewed removals. Version 3 adds
stable `RemovedCapabilities` and `DisabledFeatures` arrays and keeps service
selections separate under `ComponentServiceTweaks`.

```json
{
  "SchemaVersion": 3,
  "RemovedAppSelectors": [],
  "RemovedCapabilities": [],
  "DisabledFeatures": [],
  "RegistryTweaks": [],
  "EnabledFeatures": [],
  "ComponentServiceTweaks": []
}
```

All IDs are validated against the allow-lists under `src\`. Unknown IDs and
enable/disable conflicts fail closed. Version 1 profiles remain readable for
one-off use. Version 2 profiles remain supported in scheduled automation with
a migration warning.

## Create a Reviewed Profile

1. Open an elevated PowerShell window and run `.\winisoutil.ps1`.
2. Select a current baseline ISO and the edition you intend to automate.
3. Apply reviewed service, registry, AppX, capability, feature-disable, and
   feature-enable choices.
4. Choose `9. Export Settings (.json)` from the main menu.
5. Store the profile outside the public repository, for example:

```text
D:\WinISOUtil\config\desktop-v3.json
```

6. Validate the resulting ISO in a disposable Hyper-V VM.

## Migrate a Version 2 Profile

The migration command writes a timestamped backup before replacing an existing
profile:

```powershell
.\automation\Convert-WinIsoUtilProfile.ps1 `
  -Path 'D:\WinISOUtil\config\desktop-v2.json' `
  -InPlace
```

Legacy `RemoveIE` and `RemoveWMP` values are normalized into
`DisabledFeatures`. Existing AppX, registry, feature-enable, and service
selections remain unchanged.

## Use a Profile Directly

```powershell
.\winisoutil.ps1 `
  -Unattended `
  -Language en `
  -IsoPath 'D:\ISO\Windows11.iso' `
  -ConfigurationPath 'D:\WinISOUtil\config\desktop-v3.json' `
  -EditionIndex 1 `
  -OutputIsoPath 'D:\ISO\out\Windows11-by-WinISOUtil.iso'
```

Unattended output receives a sibling `<iso>.validation.json` report. Strict
offline mismatches prevent ISO completion.

## Use Profiles in Scheduled Automation

`DefaultConfigurationPath` applies to every target unless a target defines its
own override:

```json
{
  "DefaultConfigurationPath": "D:\\WinISOUtil\\config\\desktop-v3.json",
  "Targets": [
    { "Id": "tr-tr-pro", "Locale": "tr-tr" },
    {
      "Id": "de-de-pro",
      "Locale": "de-de",
      "ConfigurationPath": "D:\\WinISOUtil\\config\\desktop-de-v3.json"
    }
  ]
}
```

Review profiles after feature release changes or meaningful customization
changes. Stable IDs reduce monthly maintenance but do not replace installation
validation.
