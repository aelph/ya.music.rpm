# Yandex Music RPM Workaround for Fedora/openSUSE

This repository contains tools for adapting the official Yandex Music `.deb` package to RPM-based distributions (Fedora, openSUSE).

## Build Features

- **Hi-Res Audio:** Stable operation confirmed up to **176.4 KHz** via ALSA.
- **Bluetooth:** Optimized for LDAC codec (tested on Sony WH-XB900N, 88.2 KHz).
- **Package Name:** Alien automatically increments the package version for correct package manager behavior. You'll see "Beta" where the app shows the build number.
- **Integration:** Menu categories fixed (now shown under "Music") and taskbar icon display fixed (StartupWMClass). These changes are only in the app launcher. The source code is not modified.

## How to Use

1. Clone the repository.
2. Install dependencies: `sudo dnf install alien curl`.
3. Run the build script:
   - `sudo ./build_rpm.sh`
   - `fakeroot ./build_rpm.sh` (Safe)
   - `./build_rpm.sh` (Undesirable)
4. Install the resulting package: `sudo dnf install ./*.rpm`.

## Why Not a Prebuilt RPM?

To avoid violating the rights of the license holder, the binary in this repository is included only as an example of a successful script run.

The script only automates the conversion of the official package provided by Yandex for your local system.

No changes are made to the source code; only a repackaging is performed using the alien tool.

## Update

By script or manually:

``sh
sudo dnf install./path to the new package.rpm
```

After the manual update, you need to edit the shortcut:

```sh
sudo cp ./yandexmusic.desktop /usr/share/applications/
```

## Audio Troubleshooting

If you experience dropouts on Bluetooth headphones, it is recommended to use a sample rate that is a multiple of the source rate (for example, 88.2 KHz for a 176.4 KHz source).
