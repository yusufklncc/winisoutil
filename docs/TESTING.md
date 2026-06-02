# Validation and Testing

WinISOUtil combines local PowerShell logic, Windows servicing tools, a
third-party metadata API, Microsoft CDN payloads, and bootable ISO output. Use
layered validation rather than treating one successful script run as complete
coverage.

## Local Fixture Checks

Run these checks from the repository root after code or documentation changes:

```powershell
.\tests\Test-Static.ps1
.\tests\Test-Automation.ps1
git diff --check
```

`Test-Static.ps1` parses PowerShell files and checks localization and critical
invariants. `Test-Automation.ps1` validates provider fixtures, settings
examples, supply-chain restrictions, recovery hooks, logging behavior, and
output naming.

## Live UUP API Smoke Test

This opt-in test calls the current UUP Dump API and validates configured locale
manifests without downloading Windows payloads:

```powershell
.\tests\Test-LiveUupApi.ps1
```

Specify locales explicitly when needed:

```powershell
.\tests\Test-LiveUupApi.ps1 -Locales @('tr-tr', 'en-us')
```

Treat a live test failure as an integration signal. Determine whether the
cause is local code, network access, upstream availability, or upstream schema
drift before changing production policy.

## Target-Scoped Full Build

Run one locale manually before enabling a scheduled batch:

```powershell
.\automation\Invoke-AutomatedBuild.ps1 `
  -SettingsPath '.\automation\settings.json' `
  -ToolsPinPath '.\automation\tools.pin.json' `
  -TargetId 'tr-tr-pro'
```

The automation mounts the final ISO and verifies the Professional image,
locale, selected build and revision, boot image, WinRE structure, and protected
required apps before promoting the output.

## Hyper-V Installation Smoke Test

For the first two monthly outputs, every feature release change, converter pin
change, profile change, and servicing logic change:

1. Create a disposable Generation 2 Hyper-V VM.
2. Boot from the promoted ISO.
3. Perform a clean installation.
4. Confirm setup reaches the desktop.
5. Confirm expected locale and edition.
6. Confirm networking, Windows Security, Microsoft Store, recovery environment,
   and Windows Update remain usable.
7. Confirm selected removed apps, services, features, and registry choices
   behave as intended.

Keep the ISO sibling JSON manifest and the relevant logs with the test record.
