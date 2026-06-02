# Schema Version 2 Profiles

WinISOUtil profiles store reusable customization selections for interactive
imports and unattended runs. Zero-touch UUP automation requires
`SchemaVersion: 2`.

## Why Version 2

Windows provisioned app package names include version-specific values that can
change between monthly builds. Version 2 exports `RemovedAppSelectors` using
stable app `DisplayName` values. During an unattended run, WinISOUtil resolves
those selectors against the packages present in the mounted image, removes the
current package names, and verifies that selected apps are no longer present.

Version 1 profiles remain readable for one-off use. Do not use them for
scheduled automation.

## Create a Reviewed Profile

1. Open an elevated PowerShell window.
2. Start WinISOUtil from a local checkout:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\winisoutil.ps1
```

3. Select a current baseline ISO and the edition you intend to automate.
4. Apply the component, service, registry, app removal, and optional feature
   selections you want to preserve.
5. Choose `7. Export Settings (.json)` from the main menu.
6. Store the exported profile in a local configuration directory such as:

```text
D:\WinISOUtil\config\desktop-v2.json
```

7. Mount or install a resulting ISO in a disposable Hyper-V VM and verify the
   expected applications, setup path, networking, servicing, and recovery
   behavior.

Review the profile again after feature release changes or significant
customization changes. Stable selectors reduce monthly maintenance but are not
a substitute for installation validation.

## Minimal Profile

Use [`../automation/profile-v2.example.json`](../automation/profile-v2.example.json)
when no removals or tweaks are required:

```json
{
  "SchemaVersion": 2,
  "Description": "Example unattended WinISOUtil profile",
  "RemovedAppSelectors": [],
  "RegistryTweaks": [],
  "EnabledFeatures": [],
  "ComponentServiceTweaks": []
}
```

The ID values in the arrays are validated against the definitions under
`src\`. Unknown IDs fail closed.

## Use a Profile Directly

```powershell
.\winisoutil.ps1 `
  -Unattended `
  -Language en `
  -IsoPath 'D:\ISO\Windows11.iso' `
  -ConfigurationPath 'D:\WinISOUtil\config\desktop-v2.json' `
  -EditionIndex 1 `
  -OutputIsoPath 'D:\ISO\out\Windows11-by-WinISOUtil.iso'
```

If the input ISO has one install image, `-EditionIndex` can be omitted.

## Use Profiles in Scheduled Automation

`DefaultConfigurationPath` applies to every target unless a target defines its
own `ConfigurationPath`:

```json
{
  "DefaultConfigurationPath": "D:\\WinISOUtil\\config\\desktop-v2.json",
  "Targets": [
    { "Id": "tr-tr-pro", "Locale": "tr-tr" },
    {
      "Id": "de-de-pro",
      "Locale": "de-de",
      "ConfigurationPath": "D:\\WinISOUtil\\config\\desktop-de-v2.json"
    }
  ]
}
```

Keep production profiles outside the public repository. Back them up as local
operational configuration and review changes before use.
