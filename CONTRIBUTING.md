# Contributing

## Branch Workflow

- `dev` is the integration branch.
- `main` is the release-ready branch.
- Create feature or fix branches from the latest `dev`.
- Open pull requests against `dev`.
- Promote reviewed and validated changes from `dev` to `main`.

Keep `dev` synchronized after a `main` promotion so the integration branch does
not remain behind merge commits.

## Local Validation

Run from the repository root:

```powershell
.\tests\Test-Static.ps1
.\tests\Test-Automation.ps1
git diff --check
```

Run the opt-in live integration test for UUP provider changes:

```powershell
.\tests\Test-LiveUupApi.ps1
```

Use [`docs/TESTING.md`](docs/TESTING.md) for full-build and Hyper-V smoke test
expectations.

## Repository Hygiene

- Do not commit `automation/settings.json`, `automation/tools.pin.json`, local
  profiles, converter files, ISO files, logs, or state manifests.
- Keep PowerShell compatible with Windows PowerShell 5.1 unless the project
  explicitly changes that baseline.
- Update English and Turkish documentation together when behavior changes.
- Prefer narrowly scoped changes and preserve marker-protected cleanup rules.
