# Yandex Music RPM Workaround for Fedora/openSUSE

This repository contains a tool for adapting the official Yandex Music `.deb` package to RPM-based distributions (Fedora, openSUSE).

## Build Features

- **Hi-Res Audio:** Stable operation confirmed up to **176.4 KHz** via ALSA.
- **Bluetooth:** Optimized for LDAC codec (tested on Sony WH-XB900N, 88.2 KHz).
- **Package Name:** Alien automatically increments the package version for correct package manager behavior. You'll see "Beta" where the app shows the build number.
- **Integration:** Menu categories fixed (now shown under "Music") and taskbar icon display fixed (StartupWMClass). These changes are only in the app launcher. The source code is not modified.

## How to Use

1. Clone the repository.
2. Install dependencies: `sudo dnf install alien curl desktop-file-utils`.
3. Build the RPM as a regular user: `./build_rpm.sh`.
4. Install the resulting RPM with your system's regular package tools, or use `./install_rpm.sh` if you want a guided install/check flow.

`build_rpm.sh` is a simple builder. It only downloads the `.deb`, patches the launcher in the Alien build tree, and builds the RPM. It does not require `sudo`. The resulting RPM can be installed with your system's standard package management tools.

`install_rpm.sh` is only needed if you want more control over the installation or debugging flow. It handles the privileged part: it looks for a ready RPM in the project directory, runs `./build_rpm.sh` if needed, installs the package, updates the desktop database, and verifies that the package and desktop file are present.

## Why Not a Prebuilt RPM?

To avoid violating the rights of the license holder, the binary in this repository is included only as an example of a successful script run.

The scripts only automate the conversion of the official package provided by Yandex for your local system.

No changes are made to the application source code; only repackaging is performed using the alien tool, including fixing the launcher inside the generated RPM build tree before the package is built.

## Update

Do not start the update process from inside the application itself. When Yandex Music notifies you about a new version, close the program first.

Then either:

1. Run `./build_rpm.sh`, then install the resulting RPM with your regular system tools.
2. Run `./install_rpm.sh`, which will build the RPM if needed and install it for you.
