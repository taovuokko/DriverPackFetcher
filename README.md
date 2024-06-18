# Driver and Firmware Download Utility

This project provides a PowerShell-based utility for downloading and managing drivers and firmware for Dell and Lenovo devices. The current implementation supports Dell and Lenovo, with plans to add more manufacturers in future versions.

## Features

- **Dell Drivers Download**: Automates the process of finding and downloading the latest drivers for Dell models.
- **Lenovo Drivers and Firmware Download**: Automates the process of finding and downloading the latest drivers and firmware for Lenovo models.
- **User Interface**: A simple WPF-based GUI to run the scripts and monitor progress.

## Files

- `Dell-Drivers.ps1`: PowerShell script to download drivers for Dell devices.
- `Download-Lenovo-Firmware.ps1`: PowerShell script to download firmware for Lenovo devices.
- `Lenovo-Drivers.ps1`: PowerShell script to download drivers for Lenovo devices.
- `MainWindow.xaml`: XAML file defining the GUI layout.
- `MainWindow.xaml.cs`: C# code-behind for handling GUI logic.

## Usage

1. **Dell Drivers**:
   - Run `Dell-Drivers.ps1` to start the download process for Dell drivers.
   - The script checks for the latest driver versions compatible with Windows 10 and Windows 11.

2. **Lenovo Drivers and Firmware**:
   - Run `Lenovo-Drivers.ps1` to download the latest drivers for Lenovo models.
   - Run `Download-Lenovo-Firmware.ps1` to download the latest firmware for Lenovo models.

3. **GUI**:
   - Open the solution in Visual Studio.
   - Build and run the project to use the GUI for managing downloads.

## Future Plans

- Add support for more manufacturers.
- Enhance the GUI with more features.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
