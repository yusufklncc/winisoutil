# WinISOUtil - Windows ISO Customization Tool

![Windows 11](https://img.shields.io/badge/Windows-11-0078D6?style=for-the-badge&logo=windows11)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell)
![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)

**WinISOUtil** is a powerful PowerShell script that allows you to directly modify your Windows ISO files, enabling you to configure the operating system to your needs before installation. You can remove bloatware applications, improve privacy settings, apply performance-oriented registry tweaks, and integrate your frequently used drivers or updates directly into the ISO.

This tool features both an interactive menu-driven **Manual Mode** and an **Automatic Mode** that can apply a previously saved configuration file to automate the entire process.

---

## ✨ Key Features

- **Multi-Language Interface**: Support for Turkish and English.
- **Interactive and Automatic Modes**:
  - **Manual Mode**: Choose step-by-step which components to remove or which settings to apply.
  - **Automatic Mode**: Save your settings to a `.json` file and apply the same configuration to other ISOs automatically.
- **ISO Cleanup**:
  - Save space by removing unwanted Windows editions (e.g., Home, Pro) from the ISO.
  - Clean up unnecessary provisioned Windows applications (Bloatware) before installation.
- **Integration**:
  - Add critical Windows updates (`.msu`) to the ISO file.
  - Integrate your drivers (`.inf`) directly into the ISO to avoid post-installation driver hassles.
- **Detailed Configuration**:
  - **Privacy and Telemetry**: Disable data collection and error reporting services.
  - **UI Tweaks**: Align the taskbar to the left, configure desktop icons, and tweak File Explorer.
  - **Component Removal**: Remove legacy components like Internet Explorer and Windows Media Player.
- **Reliability**:
  - A `trap` mechanism ensures a safe exit and cleanup if an error occurs, preventing a "dirty" state (like a mounted image).
  - Automatically downloads necessary tools (`mkisofs.exe`) from the project's repository if they are not found locally.

---

## 🚀 Quick Start

To use this tool, simply open a **Terminal** window and run the following command. This will download and execute the bootstrapper script, which handles the setup for you.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/yusufklncc/winisoutil/refs/heads/main/install.ps1 | iex
```

---

## ⚙️ Usage and Workflow

1.  The script first checks for Administrator privileges.
2.  It downloads all necessary project files from GitHub to a temporary directory.
3.  The main script, `winisoutil.ps1`, is launched.
4.  You will first be prompted to select a language.
5.  A file selection window will open for you to choose the Windows ISO file you want to edit.
6.  The ISO is mounted, its contents are copied to `C:\temp_iso`, and the image inside `install.wim` is mounted to `C:\mount`.
7.  The main menu appears, allowing you to proceed with your desired customizations.

---

## 🤖 Automatic Mode with JSON

Instead of manually selecting the same options every time, you can streamline your workflow using a configuration file.

1.  **Exporting Settings**:

    - Run the script in interactive mode and select all your desired tweaks, component removals, and app cleanups from the menus.
    - From the main menu, choose option **"7. Export Settings (.json)"** to save your current selections into a configuration file.

2.  **Importing Settings**:
    - The next time you run the script, after selecting an ISO, it will ask if you want to import a configuration file.
    - Select "Yes" (`Y`) and choose your saved `.json` file. The script will automatically apply all the settings defined in the file.

---

## 🛠️ Modular Structure & Customization

The project is designed to be modular. You can easily add or modify customizations by editing the files in the `src/` directory:

- **`src\languages.ps1`**: Contains all the interface text strings for supported languages. Add a new language block here to extend localization.
- **`src\tweaks.ps1`**: Defines all available registry tweaks. You can add your own `[PSCustomObject]` to this list to create a new tweak.
- **`src\components.ps1`**: Lists Windows components and services that can be removed or disabled.
- **`src\features.ps1`**: Defines optional Windows features that can be enabled, like `.NET Framework 3.5`.
- **`src\app-exclusion-list.ps1`**: Contains a list of critical system apps (like the Microsoft Store) that are excluded from the removal list to prevent breaking the system.

---

## 📋 Requirements

- Windows 10 or Windows 11
- PowerShell 5.1+
- Administrator privileges to run
- Internet connection (for the initial download)

---

## 🤝 Contributing

Contributions make the project better! If you find a bug, want to suggest a new feature, or improve the code, please open an "Issue" or submit a "Pull Request."

1.  Fork the project.
2.  Create a new Feature Branch (`git checkout -b feature/AwesomeNewFeature`).
3.  Commit your changes (`git commit -m 'Add some AwesomeNewFeature'`).
4.  Push to the Branch (`git push origin feature/AwesomeNewFeature`).
5.  Open a Pull Request.

---

## ⚠️ Disclaimer

This script modifies critical system files within the Windows ISO. While extensively tested, it's provided "as is" without warranties. The author is not liable for any damages that might occur from its use.

- **Use at your own risk**.
- **Always back up important data** before making system modifications.

---

## 📄 License

This project is licensed under the MIT License. See the `LICENSE` file for details.
