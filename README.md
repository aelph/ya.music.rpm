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
3. Run the build script as a regular user: `./build_rpm.sh`.

The script runs most steps as your regular user and will use `sudo` only for the privileged operations (installing the RPM, copying the desktop file, and updating the desktop database). When needed, it will request your `sudo` password once at the start and cache credentials briefly, so you won't be prompted at every privileged command.

If you run the whole script with `sudo ./build_rpm.sh`, it will execute as root and no further password prompts will occur, but this is not recommended because files created in the working directory may become owned by root. The script attempts to restore file ownership to the invoking user when possible, but preferring to run it without `sudo` avoids ownership surprises.

## Why Not a Prebuilt RPM?

To avoid violating the rights of the license holder, the binary in this repository is included only as an example of a successful script run.

The script only automates the conversion of the official package provided by Yandex for your local system.

No changes are made to the source code; only a repackaging is performed using the alien tool.

## Update

To update the application, run the script again as a regular user: `./build_rpm.sh`.
If the script needs to perform privileged actions it will prompt for `sudo` credentials as described above.

## Audio Troubleshooting

If you experience dropouts on Bluetooth headphones, it is recommended to use a sample rate that is a multiple of the source rate (for example, 88.2 KHz for a 176.4 KHz source).
