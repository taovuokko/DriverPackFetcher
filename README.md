# Driver and Firmware Download Utility

This project provides a PowerShell-based utility for downloading and managing drivers and firmware for Dell, Lenovo, and HP devices. The current implementation supports Dell, Lenovo, and HP, with plans to add more manufacturers in future versions. **Please note that this project is currently in the pre-alpha stage.**

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
- `config.json`: JSON configuration file containing paths and settings for future use.

### GUI:
- Open the solution in Visual Studio.
- Build and run the project to use the GUI for managing downloads.

## Future Plans
- Add support for more manufacturers.
- Enhance the GUI with more features.

## License
This project is licensed under the MIT License. See the LICENSE file for details.
