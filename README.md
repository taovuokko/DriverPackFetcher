# Driver and Firmware Download Utility

This project provides a WPF-based GUI utility for downloading and managing driver packs and firmware (BIOS). The core functionality is powered by PowerShell scripts, handling the actual downloading and management tasks. The current implementation supports Dell, Lenovo, and HP. **Please note that this project is currently in the alpha stage.**

## Features
- **Dell Drivers Download**: Automates the process of finding and downloading the latest drivers for Dell models.
- **Lenovo Drivers and Firmware Download**: Automates the process of finding and downloading the latest drivers and firmware for Lenovo models.
- **HP Drivers and BIOS Download**: Supports downloading drivers and BIOS updates for HP models.
- **User Interface**: A simple WPF-based GUI to run the scripts and monitor progress.

## Files
- `Dell-Drivers.ps1`: PowerShell script to download drivers for Dell devices.
- `Lenovo-Drivers.ps1`: PowerShell script to download drivers for Lenovo devices.
- `Download-Lenovo-Firmware.ps1`: PowerShell script to download firmware for Lenovo devices.
- `HP-Drivers.ps1`: PowerShell script to download drivers and BIOS updates for HP devices.
- `MainWindow.xaml`: XAML file defining the GUI layout.
- `MainWindow.xaml.cs`: C# code-behind for handling GUI logic.
- `config.json`: JSON configuration file containing paths and settings.
  
### GUI:
- Open the solution in Visual Studio.
- Build and run the project to use the GUI for managing downloads, or use the MSI installer.
- Use the **Settings Menu** to customize download paths and other configurations. These settings are saved in the `config.json` file for future use.


## Future Plans
- Add support for more manufacturers.
- Enhance the GUI with more features.

## License
This project is licensed under the MIT License. See the LICENSE file for details.
