# Security Policy

## Scope

WinISOUtil modifies offline Windows installation images and can run unattended
with administrator privileges. Review profiles, converter pins, and code
changes before use. Run production automation on a dedicated Windows machine or
VM with restricted access.

## Trust Boundaries

- `api.uupdump.net` is a third-party metadata service. Automation accepts only
  the expected HTTPS API host and fails closed when required metadata is
  missing.
- Windows payloads are accepted only from `*.delivery.mp.microsoft.com`.
  Signed CDN links may use HTTP. Every payload is size-checked and SHA-256
  verified before use.
- The UUP converter is third-party software. It is not vendored or updated
  automatically. Install only a reviewed ZIP through
  `automation\Install-UupTools.ps1` with a pinned SHA-256.
- Remote PowerShell and CMD text is never downloaded and executed directly by
  the automation.
- Massgrave is not an automatic fallback.

## Local Secrets and Configuration

The repository ignores:

```text
automation/settings.json
automation/tools.pin.json
automation/tools/
```

Keep production profiles outside the public repository. Treat webhook URLs as
credentials when they include tokens. Do not commit private URLs, hashes tied
to private artifacts, logs, ISO files, or state manifests.

## Updating the Converter Pin

1. Obtain the intended converter archive from the upstream project.
2. Review the archive contents and licensing.
3. Host the reviewed immutable ZIP at an HTTPS location you control.
4. Update the local `ArchiveUri`, `ArchiveSha256`, and
   `CommandRelativePath`.
5. Run `automation\Install-UupTools.ps1`.
6. Run fixture checks, the live API smoke test, a target-scoped full build, and
   a Hyper-V clean-install smoke test before restoring scheduled execution.

## Reporting a Vulnerability

Do not publish sensitive vulnerability details in a public issue. Use the
repository's private GitHub security advisory channel when available. Include
the affected commit, reproduction steps, impact, and any proposed mitigation.
