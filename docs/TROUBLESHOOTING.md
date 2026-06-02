# Automation Troubleshooting Runbook

Run diagnostics from an elevated PowerShell window on the dedicated automation
machine. Do not delete preserved staging data until the current state, logs,
and active DISM mounts have been inspected.

## Read the Current State

```powershell
Get-Content D:\WinISOUtil\state\current-run.json -Raw
Get-Content D:\WinISOUtil\state\last-run.json -Raw
Get-ChildItem D:\WinISOUtil\logs -File |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 20 Name, Length, LastWriteTime
```

Follow the active log:

```powershell
Get-Content D:\WinISOUtil\logs\automated-build-*.log -Wait -Tail 50
```

Native converter and WinISOUtil stdout, stderr, and exit-code transcripts are
stored separately in the same log directory.

## Inspect the Scheduled Task

```powershell
Get-ScheduledTask -TaskName 'WinISOUtil Daily UUP Build'
Get-ScheduledTaskInfo -TaskName 'WinISOUtil Daily UUP Build'
```

If the task is missing, register it from an elevated PowerShell window:

```powershell
.\automation\Register-ScheduledTask.ps1 `
  -SettingsPath '.\automation\settings.json' `
  -ToolsPinPath '.\automation\tools.pin.json'
```

The task runs as `SYSTEM`. Every configured local path, profile, and installed
converter file must be readable by that account.

## Inspect DISM Mounts Before Cleanup

```powershell
Get-WindowsImage -Mounted
```

If a mount belongs to an interrupted WinISOUtil run, inspect the reported path
and status before choosing discard or recovery. Do not recursively remove a
mount directory while DISM still reports it as mounted.

## Converter Temporary Directories

The pinned converter can leave these fixed directories on the staging volume
after an interruption:

```text
D:\W10UIuup
D:\MountUUP
```

Before removing them:

1. Confirm that no automation or converter process is running.
2. Run `Get-WindowsImage -Mounted`.
3. Resolve any active DISM mounts.
4. Verify that the exact paths are converter leftovers on the configured
   staging volume.
5. Remove only the verified leftover directories.

The next full build deliberately stops early when stale converter directories
exist. This protects the next conversion from inheriting uncertain state.

## Preserved Staging Data

Failed target staging directories are retained for diagnosis and recovery. The
automation automatically reuses a valid assembled source ISO after downstream
customization or validation failures.

Only consider manual deletion when a directory:

- is under the configured `Paths.Staging` root;
- contains `.winisoutil-staging.json`;
- does not contain a source ISO you still need for recovery;
- is not referenced by a running task.

## Common Failure Categories

| Symptom | Check |
| --- | --- |
| Build stops before conversion | Confirm `MinimumFreeSpaceGiB`, ADK Deployment Tools, pinned converter installation, stale converter directories, and active DISM mounts. |
| UUP API retries and fails | Check network access to `https://api.uupdump.net`. The provider retries with 5, 15, 45, and 120 second delays. |
| Payload download fails | Keep the `.partial` file. The next attempt resumes when the CDN supports ranges and always rechecks size and SHA-256. |
| One locale fails | Inspect target-specific transcripts. Other locale targets continue and valid existing outputs remain untouched. |
| Final ISO validation fails | Preserve staging and inspect the WinISOUtil transcript. The assembled source ISO is kept for reuse. |
| Task works manually but not on schedule | Confirm `SYSTEM` can access every configured drive, profile, and tools path. Avoid mapped network drives. |
| Existing output is reported as no-op | Expected behavior. The same locale, feature, and build is not rebuilt. |

## Disk Usage

Payload cache files intentionally remain between runs:

```powershell
Get-ChildItem D:\WinISOUtil\cache -Recurse -File |
  Measure-Object Length -Sum
Get-PSDrive D
```

Do not delete cache files during an active run. Cache cleanup is a separate
reviewed maintenance operation; final ISO retention does not purge shared
payloads.

## Inspect Profile Validation

Promoted and verifier-only ISOs receive an `<iso>.validation.json` sibling
report. Review `FailedChecks`, `NoOpChecks`, and `DeferredPostLoginChecks`
before changing a profile. An absent allow-listed capability, feature, or
service is an expected desired-state no-op.
