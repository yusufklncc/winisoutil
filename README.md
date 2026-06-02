[English](README.md) | [Türkçe](README.tr.md)

# WinISOUtil - Windows ISO Customization Tool

![Windows 11](https://img.shields.io/badge/Windows-11-0078D6?style=for-the-badge&logo=windows11)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell)
![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)

**WinISOUtil** is a powerful PowerShell script that allows you to directly modify your Windows ISO files, enabling you to configure the operating system to your needs before installation. You can remove bloatware applications, improve privacy settings, apply performance-oriented registry tweaks, and integrate your frequently used drivers or updates directly into the ISO.

This tool features both an interactive menu-driven **Manual Mode** and an **Unattended Mode** that can apply a previously saved configuration file without UI prompts.

---

## ✨ Key Features

- **Multi-Language Interface**: Support for Turkish and English.
- **Interactive and Unattended Modes**:
  - **Manual Mode**: Choose step-by-step which components to remove or which settings to apply.
  - **Unattended Mode**: Save your settings to a `.json` file and apply the same configuration to refreshed ISOs without UI prompts.
- **ISO Cleanup**:
  - Save space by removing unwanted Windows editions (e.g., Home, Pro) from the ISO.
  - Clean up unnecessary provisioned Windows applications (Bloatware) before installation.
- **Integration**:
  - Add critical Windows updates (`.msu`) to the ISO file.
  - Integrate your drivers (`.inf`) directly into the ISO to avoid post-installation driver hassles.
- **Detailed Configuration**:
  - **Privacy and Telemetry**: Disable data collection and error reporting services.
  - **UI Tweaks**: Align the taskbar to the left, configure desktop icons, and tweak File Explorer.
  - **Controlled Debloat Catalog**: Remove opt-in provisioned AppX packages, conservative Windows capabilities, and legacy optional features.
- **Reliability and Dependency Management**:
  - A `trap` mechanism ensures a safe exit and cleanup if an error occurs, preventing a "dirty" state (like a mounted image).
  - Temporary files are only deleted from an owned, marker-protected workspace under `%TEMP%\WinISOUtil`.
  - Both `install.wim` and `install.esd` source images are supported.
  - The script automatically checks for the required **Windows ADK**. If it's not found, it provides clear instructions for the user to install it.

---

## 🚀 Quick Start

Download a reviewed release archive or clone the repository, then run the script from a local checkout:

```powershell
git clone https://github.com/yusufklncc/winisoutil.git
cd winisoutil
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\winisoutil.ps1
```

Run `winisoutil.ps1` from an **elevated PowerShell window**. The main script
checks administrator privileges and stops when they are missing. The optional
bootstrapper requests elevation automatically.

Avoid piping remote scripts directly into `iex`. For reproducible bootstrap installs, run the local `install.ps1` with a pinned Git ref and the expected archive SHA-256:

```powershell
.\install.ps1 -Ref '<tag-or-commit>' -ExpectedArchiveSha256 '<sha256>'
```

## ⚙️ Usage and Workflow

1.  The bootstrapper script first requests Administrator privileges.
2.  If you use the optional bootstrapper, it downloads project files from GitHub to a unique temporary directory and can verify the archive SHA-256.
3.  The main script, `winisoutil.ps1`, is launched.
4.  You will be prompted to select a language.
5.  The script verifies that all requirements (like the Windows ADK) are met before proceeding.
6.  A file selection window will open for you to choose the Windows ISO file you want to edit.
7.  The ISO is mounted, its contents are copied to `%TEMP%\WinISOUtil\iso`, and the selected image is mounted to `%TEMP%\WinISOUtil\mount`.
8.  The main menu appears, allowing you to proceed with your desired customizations.

---

## 🤖 Unattended Mode with JSON

Instead of manually selecting the same options every time, you can streamline your workflow using a configuration file.

1.  **Exporting Settings**:

    - Run the script in interactive mode and select all your desired tweaks, component removals, and app cleanups from the menus.
    - From the main menu, choose option **"9. Export Settings (.json)"** to save your current selections into a configuration file.

2.  **Importing Settings**:
    - The next time you run the script, after selecting an ISO, it will ask if you want to import a configuration file.
    - Select "Yes" (`Y`) and choose your saved `.json` file. The script will automatically apply all validated settings defined in the file.

3.  **Running without UI prompts**:

```powershell
.\winisoutil.ps1 `
  -Unattended `
  -Language en `
  -IsoPath 'D:\ISO\Windows11.iso' `
  -ConfigurationPath '.\config\desktop.json' `
  -EditionIndex 1 `
  -OutputIsoPath 'D:\ISO\out\Windows11-by-WinISOUtil.iso'
```

New exports use configuration schema version 3. Stable `RemovedAppSelectors`,
`RemovedCapabilities`, and `DisabledFeatures` keep reviewed debloat choices
reusable across refreshed ISO builds and locales. Version 1 profiles remain
readable for one-off runs. Version 2 remains supported in zero-touch automation
with a migration warning. See [`docs/PROFILE.md`](docs/PROFILE.md).

### Unattended CLI Reference

| Parameter | Purpose |
| --- | --- |
| `-IsoPath` | Input Windows ISO. Required in unattended mode. |
| `-ConfigurationPath` | Exported JSON profile. Required in unattended mode. |
| `-OutputIsoPath` | Final ISO path. Required in unattended mode. |
| `-ValidationReportPath` | Optional output path for the ISO sibling validation report. Defaults to `<iso>.validation.json`. |
| `-EditionIndex` | Image index to customize. Required when the ISO contains multiple editions. |
| `-Language` | Tool message language: `tr` or `en`. Defaults to `en` in unattended mode. |
| `-UpdatesPath` | Optional folder containing `.msu` update packages. |
| `-DriversPath` | Optional folder containing `.inf` drivers. Subdirectories are included. |
| `-WorkingDirectory` | Optional owned workspace. Defaults to `%TEMP%\WinISOUtil`. |
| `-SkipWimOptimization` | Skips the final WIM export optimization step. Useful only for diagnostics. |

## Scheduled UUP Automation

The recommended zero-touch model runs on a dedicated Windows 11 machine or VM,
not on GitHub Actions. A daily SYSTEM task discovers an eligible Retail UUP
build, downloads hash-verified payloads from Microsoft CDN hosts, assembles one
Windows 11 Pro ISO per configured locale, applies a reviewed profile, validates
the result, and retains the configured number of successful outputs.

See [`docs/AUTOMATION.md`](docs/AUTOMATION.md) for setup and operations.

## Documentation

- [`docs/AUTOMATION.md`](docs/AUTOMATION.md): daily multi-locale UUP automation
- [`docs/PROFILE.md`](docs/PROFILE.md): create, migrate, and maintain schema version 3 profiles
- [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md): recovery and diagnostics runbook
- [`docs/TESTING.md`](docs/TESTING.md): fixture, live API, and Hyper-V validation
- [`SECURITY.md`](SECURITY.md): trust boundaries and supply-chain policy
- [`CONTRIBUTING.md`](CONTRIBUTING.md): contribution and branch workflow

---

## 🛠️ Modular Structure & Customization

The project is designed to be modular. You can easily add or modify customizations by editing the files in the `src/` directory:

- **`src\languages.ps1`**: Contains all the interface text strings for supported languages. Add a new language block here to extend localization.
- **`src\tweaks.ps1`**: Defines all available registry tweaks. You can add your own `[PSCustomObject]` to this list to create a new tweak.
- **`src\components.ps1`**: Lists service tweaks that can be applied offline.
- **`src\capabilities.ps1`**: Defines the conservative removable capability allow-list.
- **`src\removable-features.ps1`**: Defines the conservative disable/remove optional-feature allow-list.
- **`src\features.ps1`**: Defines optional Windows features that can be enabled, like `.NET Framework 3.5`.
- **`src\app-exclusion-list.ps1`**: Contains a list of critical system apps (like the Microsoft Store) that are excluded from the removal list to prevent breaking the system.

---

## 📋 Requirements

- Windows 10 or Windows 11
- PowerShell 5.1+
- Administrator privileges to run
- Internet connection (for the initial download of the script)
- **Windows ADK**: The [Windows Assessment and Deployment Kit (ADK)](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install) must be installed.
  - During the ADK setup, you only need to select the **"Deployment Tools"** feature, which includes the necessary `oscdimg.exe` for creating the final ISO file.

## ✅ Validation

Run local fixture checks before submitting a change:

```powershell
.\tests\Test-Static.ps1
.\tests\Test-Automation.ps1
.\tests\Test-ProfileValidation.ps1
```

The live UUP API smoke test and Hyper-V installation test are documented in
[`docs/TESTING.md`](docs/TESTING.md).

---

## 🤝 Contributing

Use [`CONTRIBUTING.md`](CONTRIBUTING.md) for the development workflow. Changes
are integrated through `dev`; `main` is the release-ready branch.

---

## ⚠️ Disclaimer

This script modifies critical system files within the Windows ISO. While extensively tested, it's provided "as is" without warranties. The author is not liable for any damages that might occur from its use.

- **Use at your own risk**.
- **Always back up important data** before making system modifications.

---

## 📄 License

This project is licensed under the MIT License. See the `LICENSE` file for details.
