# Multi-Locale UUP Automation

WinISOUtil can build refreshed Windows 11 Pro ISOs without GitHub Actions or
manual ISO downloads. A single Windows Task Scheduler job discovers an eligible
Retail build through the third-party UUP Dump API, downloads payload files from
Microsoft CDN hosts, assembles one ISO per configured locale, and applies a
WinISOUtil profile.

Related documentation:

- [`PROFILE.md`](PROFILE.md): create and maintain schema version 2 profiles
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md): operational recovery runbook
- [`TESTING.md`](TESTING.md): fixture, live API, and installation validation
- [`../SECURITY.md`](../SECURITY.md): trust boundaries and supply-chain policy

## Trust Model

- Microsoft UUP is the Windows update distribution mechanism.
- `api.uupdump.net` is a third-party metadata service. The automation fails
  closed when its schema, availability, or metadata does not satisfy policy.
- Payload URLs are accepted only from `*.delivery.mp.microsoft.com`. Some
  signed Microsoft CDN URLs currently use HTTP and cannot be safely upgraded to
  HTTPS because the CDN certificate does not match the upgraded hostname.
  Every payload is therefore size-checked and SHA-256 verified before use.
- Remote PowerShell and CMD files are never executed directly.
- Massgrave is not an automatic fallback. Keep it as a documented manual
  emergency option only.

## Build Policy

- Only `RETAIL`, `Active`, SHA-256-ready Windows 11 `amd64` feature builds are
  accepted.
- Only the `PROFESSIONAL` edition is assembled.
- Monthly updates within the active feature release are applied immediately.
- A newly observed feature release is held for 30 days before automatic
  promotion. `InitialFeatureVersion` seeds the first local state so the first
  scheduled run cannot bypass that hold window.
- Each locale produces a separate ISO. Targets run sequentially so DISM mounts,
  converter workspaces, and API calls cannot overlap.
- A failed target does not replace its previous ISO and does not stop other
  locales. The batch exits with code `2` for a partial failure.

## Prerequisites

Use a dedicated, updated Windows 11 x64 machine or VM with at least 100 GB of
free disk space. Install Windows ADK Deployment Tools. Run setup commands from
an elevated PowerShell window.

`MinimumFreeSpaceGiB` defaults to `50`. A full build fails before conversion
when any configured cache, staging, output, or working volume has less free
space. This is an additional workspace reserve; the shared payload cache remains
on disk between runs.

The UUP converter is a separate third-party project. Its redistribution license
is not asserted by this repository, so converter files are not vendored. Review
the converter package, place the reviewed ZIP at an HTTPS URL you control, and
record its SHA-256 locally. Treat converter updates as reviewed maintenance
changes: update the local pin manually, reinstall the tools, and run the full
validation sequence before enabling the scheduled task again.

## Setup

1. Create the local settings file:

```powershell
Copy-Item .\automation\settings.example.json .\automation\settings.json
```

2. Edit paths and `Targets`. Every path must be local and accessible to the
   `SYSTEM` account. Set `InitialFeatureVersion` to the established feature
   release you intentionally want to use for the first run.

3. Export a `SchemaVersion: 2` WinISOUtil profile interactively from a current
   baseline ISO. Version 2 stores stable `RemovedAppSelectors` instead of
   version-specific package names. Follow [`PROFILE.md`](PROFILE.md). Use
   `automation\profile-v2.example.json` as a minimal starting point when no app
   removals are required.

4. Create the local converter pin:

```powershell
Copy-Item .\automation\tools.pin.example.json .\automation\tools.pin.json
```

5. Set `ArchiveUri`, `ArchiveSha256`, and `CommandRelativePath` in
   `tools.pin.json`, then install the reviewed ZIP:

```powershell
.\automation\Install-UupTools.ps1 `
  -SettingsPath '.\automation\settings.json' `
  -ToolsPinPath '.\automation\tools.pin.json'
```

The ZIP must contain `convert-UUP.cmd`, `ConvertConfig.ini`, and its companion
files at the configured relative path. The installer refuses to promote an
archive whose SHA-256 does not match the local pin.

6. Run discovery:

```powershell
.\automation\Invoke-AutomatedBuild.ps1 `
  -SettingsPath '.\automation\settings.json' `
  -ToolsPinPath '.\automation\tools.pin.json' `
  -DiscoverOnly
```

7. Run a target-scoped full build manually and validate the ISO in Hyper-V:

```powershell
.\automation\Invoke-AutomatedBuild.ps1 `
  -SettingsPath '.\automation\settings.json' `
  -ToolsPinPath '.\automation\tools.pin.json' `
  -TargetId 'tr-tr-pro'
```

   Repeat the smoke build for each locale before enabling the complete batch.
   Omit `-TargetId` to process all configured targets sequentially.

8. Register the daily `04:00` SYSTEM task after the manual validation succeeds:

```powershell
.\automation\Register-ScheduledTask.ps1 `
  -SettingsPath '.\automation\settings.json' `
  -ToolsPinPath '.\automation\tools.pin.json'
```

   Add `-RunNow` only when you intentionally want to start the registered task
   immediately.

## Settings Reference

| Setting | Purpose |
| --- | --- |
| `SchemaVersion` | Automation settings schema. Must be `2`. |
| `ToolLanguage` | WinISOUtil message language passed to unattended runs. |
| `Architecture` | UUP architecture. The current production policy uses `amd64`. |
| `Edition` | UUP edition. The current production policy requires `PROFESSIONAL`. |
| `InitialFeatureVersion` | Seeds the active feature release on first use. |
| `FeatureReleaseHoldDays` | Observation window before a newer feature release is promoted. |
| `RetentionCount` | Successful final ISOs retained per target. |
| `MinimumFreeSpaceGiB` | Required reserve on cache, staging, output, and working volumes before a full build. Defaults to `50` when omitted. |
| `DefaultConfigurationPath` | Default schema version 2 WinISOUtil profile. |
| `WebhookUrl` | Optional HTTPS endpoint that receives the final batch summary. Keep credentials out of tracked files. |
| `Targets[].Id` | Stable local target identifier used in paths, logs, and `-TargetId`. |
| `Targets[].Locale` | UUP locale such as `tr-tr`, `en-us`, or `de-de`. |
| `Targets[].ConfigurationPath` | Optional target-specific schema version 2 profile override. |
| `Paths` | Local tools, cache, staging, output, logs, working, and state roots accessible to `SYSTEM`. |

## Operational Notes

The automation retains the last two successful ISOs per locale by default.
Payloads use a shared SHA-256 cache, so common UUP and AppX files are reused.
Incomplete downloads resume where the Microsoft CDN supports ranges. Expired
signed URLs trigger one manifest refresh.

Promoted ISOs use the name
`Windows11-Pro-<locale>-<feature>-<build>-by-WinISOUtil.iso`.
Existing `-custom.iso` outputs remain valid no-op matches during migration, so
the naming change does not rebuild an already promoted build.

Logs are written live under `Paths.Logs`. Native converter and WinISOUtil
stdout/stderr transcripts are retained separately. `Paths.State\current-run.json`
is updated atomically at phase boundaries, so an interrupted run still records
its last known phase and log path. State manifests, per-target ISO hashes, and
the last completed batch result are written under `Paths.State` and beside
promoted ISOs. The batch also writes an Application Event Log entry. An optional
HTTPS `WebhookUrl` receives the same summary JSON. To follow the current log:

```powershell
Get-Content D:\WinISOUtil\logs\automated-build-*.log -Wait -Tail 50
```

After UUP assembly, the verified source ISO is moved to a transient assembled
source cache. If customization or final validation fails, the next run reuses
that source ISO instead of rebuilding it. A successful promoted ISO removes the
transient cached source to reclaim disk space. Valid assembled ISO files left in
owned staging directories are also recovered automatically.

Failed staging directories are intentionally preserved for diagnosis. Remove
them only after confirming they are under `Paths.Staging` and contain the
`.winisoutil-staging.json` ownership marker.

The pinned converter also uses `<staging-volume>:\W10UIuup` and
`<staging-volume>:\MountUUP` as fixed temporary directories. An interrupted
conversion can leave them behind. The next full build fails early until active
DISM mounts are inspected and those stale directories are removed.

`Invoke-MonthlyBuild.ps1` remains as a deprecated compatibility wrapper.

## Task Operations

Inspect the registered task:

```powershell
Get-ScheduledTask -TaskName 'WinISOUtil Daily UUP Build'
Get-ScheduledTaskInfo -TaskName 'WinISOUtil Daily UUP Build'
```

Start an already registered task:

```powershell
Start-ScheduledTask -TaskName 'WinISOUtil Daily UUP Build'
```

Remove the task without deleting local outputs or caches:

```powershell
Unregister-ScheduledTask -TaskName 'WinISOUtil Daily UUP Build' -Confirm:$false
```

Inspect the latest state and Application Event Log records:

```powershell
Get-Content D:\WinISOUtil\state\current-run.json -Raw
Get-Content D:\WinISOUtil\state\last-run.json -Raw
Get-WinEvent -FilterHashtable @{
  LogName = 'Application'
  ProviderName = 'WinISOUtil Automation'
} -MaxEvents 10
```

## Results and Exit Codes

The final ISO is promoted only after validation succeeds. Validation checks the
Professional edition, requested locale, selected build and revision, boot
image, install image, WinRE structure, and required protected provisioned apps.
The promoted ISO receives a sibling JSON manifest containing source and final
SHA-256 values.

| Exit code | Meaning |
| --- | --- |
| `0` | Discovery or build batch completed without target failures. Existing output matches are reported as no-op targets. |
| `1` | The batch failed before any usable result could be completed. |
| `2` | Partial failure: at least one target succeeded or was a no-op while another target failed. |

Use [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) before manually removing
preserved staging data or converter temporary directories.
