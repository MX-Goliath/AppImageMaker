# AppImageMaker

This repository contains a Bash script that automates the process of converting an installed package into an AppImage.

## Prerequisites

- The script is designed for Arch Linux and derivatives, as it utilizes `pacman` for package management.
- `wget` is required to download the `appimagetool` if it's not already present.
- You need to have the package installed on your system that you wish to convert into an AppImage.

## How It Works

1. The script checks for the presence of `appimagetool-x86_64.AppImage`; if it's not found, it downloads and makes it executable.
2. It prompts the user to enter the name of the package to be converted.
3. The script then checks if the package is installed. If not, it asks for the package name again.
4. It creates a directory structure mimicking the AppDir format, copying the package files and necessary dependencies into this structure.
5. For packages depending on Qt, it ensures Qt dependencies are copied correctly.
6. It sets up an `AppRun` script inside the AppDir, which is the entry point for running the AppImage, configuring necessary environment variables for application execution.
7. Finally, it uses `appimagetool` to package the AppDir into an AppImage.

## Usage

1. Clone this repository or download the script to your local machine.
2. Ensure the script is executable: `chmod +x package_to_appimage.sh`
3. Run the script: `./package_to_appimage.sh`
4. Follow the on-screen prompts to enter the package name you want to convert.
5. Once completed, the script will produce an AppImage in the current directory.

## Notes

- The script assumes that the main executable of the package is located under `/usr/bin/`.
- It automatically includes Qt platform plugins if the `qt6-base` package is installed, ensuring Qt applications run smoothly.
- The script attempts to find and set the application icon by looking for icon files in the package directory. If no icons are found, it looks for a default icon named `AppImage.png` in the same directory as the script.

## Limitations

- Currently, this script is tailored for Arch Linux and require adjustments to work with other distributions.
- It does not handle complex dependencies or configurations that might require manual intervention.
- Simple packages, including those installed from AUR, are currently supported. The work was tested on a small number of packages: Clementine, Obsidian, Qbittorrent, Veracrypt. MATLAB 2021a and Unreal Engine 5.3.2 were also packaged.
