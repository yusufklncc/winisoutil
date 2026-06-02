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
.\tests\Test-ProfileValidation.ps1
git diff --check
```

`Test-Static.ps1` parses PowerShell files and checks localization and critical
invariants. `Test-Automation.ps1` validates provider fixtures, settings
examples, supply-chain restrictions, recovery hooks, logging behavior, and
output naming. `Test-ProfileValidation.ps1` verifies schema migration, legacy
normalization, fail-closed catalogs, desired-state no-ops, strict checks, and
deferred post-login reporting without mounting a Windows image.

## Verifier-Only Check

Validate an existing ISO without running UUP assembly or debloat again:

```powershell
.\automation\Test-WinIsoUtilIso.ps1 `
  -IsoPath 'D:\WinISOUtil\output\tr-tr-pro\Windows11-Pro-tr-tr-25H2-26200.8524-custom.iso' `
  -ConfigurationPath 'D:\WinISOUtil\config\desktop-v3.json'
```

The command mounts the final install image read-only, runs profile-aware checks,
and writes `<iso>.validation.json`.

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
locale, selected build and revision, boot image, WinRE structure, protected
required apps, strict offline profile state, and deferred post-login artifacts
before promoting the output.

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
8. Run the desktop post-login BAT manually and confirm the Search icon behavior.

Keep the ISO sibling manifest, validation JSON, and relevant logs with the test
record.
