[English](README.md) | [Türkçe](README.tr.md)

# Windows 11 ISO Customization Tool

![Windows 11 Logo](https://img.shields.io/badge/Windows-11-0078D6?style=for-the-badge&logo=windows11)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell)
![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)

This PowerShell script allows you to directly modify your Windows 11 ISO files, enabling you to configure the operating system to your needs before installation. You can remove bloatware applications, improve privacy settings, apply performance-oriented registry tweaks, and integrate your frequently used drivers or updates directly into the ISO.

This tool features both an interactive menu that lets you make step-by-step selections and an automatic mode that can apply a previously saved configuration file to automate the entire process.

---

## ✨ Key Features

- **Multi-Language Interface**: Support for Turkish and English.
- **Interactive and Automatic Modes**:
  - **Manual Mode**: Choose step-by-step which components to remove or which settings to apply.
  - **Automatic Mode**: Save your settings to a `.json` file and apply the same configuration to other ISOs.
- **ISO Cleanup**:
  - Save space by removing unwanted Windows editions (e.g., Home, Pro, SE) from the ISO.
  - Clean up unnecessary Windows applications (Bloatware) before installation.
- **Integration**:
  - Add critical Windows updates (`.msu`) to the ISO file.
  - Integrate your drivers (`.inf`) directly into the ISO to avoid post-installation driver hassles.
- **Detailed Configuration**:
  - **Privacy and Telemetry**: Disable data collection services.
  - **UI Tweaks**: Align the taskbar to the left, restore the classic right-click menu, and configure desktop icons.
  - **Performance Improvements**: Disable unnecessary services and apply registry settings that boost system performance.
- **Reliability**:
  - If an error occurs during the process, a `trap` mechanism ensures a safe exit without leaving behind "dirty" files (like a mounted image).
  - Automatically downloads necessary tools (oscdimg, mkisofs) from the internet if they are not found.

## 🚀 Usage

1.  ...
2.  When the script starts, you will first be prompted to select a language.
3.  Next, a file selection window will open for you to choose the Windows 11 ISO file you want to edit.
4.  After selecting the ISO, you can proceed by choosing the desired operations from the menu.

### Usage with Parameters

You can also run the script from the command line by specifying an ISO path. This is particularly useful for automation.

```powershell
.\Win11-ISO-Customizer.ps1 -IsoPath "C:\path\to\your\windows11.iso"
```

## 🛠️ Configuration Files

- **`src\languages.ps1`**: Contains all the text used in the interface in both Turkish and English. You can edit this file to add a new language.
- **`src\tweaks.ps1`**: Contains all the tweaks listed in the "Registry" menu. You can edit this file to add a new registry tweak or modify an existing one.
- **`src\components.ps1`**: Contains all the components listed in the "Components and Services" menu. You can edit this file to add a new components, services or delete an existing one.
- **`src\features.ps1`**: Contains all the features listed in the "Windows Features" menu. You can edit this file to add a new features or delete an existing one.
- **`src\app-exclusion-list.ps1`**: Contains all the excluded apps in the "Remove Windows Apps" menu. You can edit this file to add a new apps for excluding them from listing or remove for list them again.

## 🤝 Contributing

Contributions make the project better! If you find a bug, want to suggest a new feature, or improve the code, please open an "Issue" or submit a "Pull Request."

1.  Fork the project.
2.  Create a new Feature Branch (`git checkout -b feature/AwesomeNewFeature`).
3.  Commit your changes (`git commit -m 'Add some AwesomeNewFeature'`).
4.  Push to the Branch (`git push origin feature/AwesomeNewFeature`).
5.  Open a Pull Request.

## ⚠️ Disclaimer

This script modifies critical system files within the Windows ISO. While extensively tested, it's provided "as is" without warranties. The author is not liable for any damages that might occur from its use.

- **Use at own risk**
- **Always back up important data** before installing a modified Windows version

## 📄 License

This project is licensed under the MIT License. See the `LICENSE` file for details.
