### Disclaimer

PSADT-LenovoThinInstaller is an independent project and not endorsed or supported in any way by Lenovo Group Limited.

### What is PSADT-LenovoThinInstaller?

PSADT-LenovoThinInstaller is a wrapper for the [Lenovo Thin Installer](https://support.lenovo.com/ca/en/solutions/ht037099#ti) utility that allows it to be deployed and run on workstations in a user-friendly manner. It is intended to be deployed with Microsoft System Center Configuration Manager but should be adaptable to other deployment solutions. It is based on the [PowerShell App Deployment Toolkit](https://psappdeploytoolkit.com/) which is a versatile and easy to use framework for performing application installation tasks.

### Features

* Prompts user for permission before attempting to install updates that force a reboot and allows them to defer the installation
* Will only install updates not requiring user interaction if no user is logged in
* Suspends BitLocker before attempting to install BIOS updates (and schedules a task to resume it if needed)

### Deployment instructions

To be completed

### Technical details

To be completed

## License

PSADT-LenovoThinInstaller is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.
 
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more details.
