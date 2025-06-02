#!/bin/bash

# Exit on error
set -e

# Build the Flutter application
echo "Building Flutter application..."
flutter build linux --release

# Create AppDir structure
echo "Creating AppDir structure..."
mkdir -p AppDir/usr/bin
mkdir -p AppDir/usr/share/applications
mkdir -p AppDir/usr/share/icons/hicolor/256x256/apps

# Copy the built application
echo "Copying application files..."
cp -r build/linux/x64/release/bundle/* AppDir/usr/bin/

# Copy desktop file
echo "Copying desktop file..."
cp linux/gkshare.desktop AppDir/usr/share/applications/
cp linux/gkshare.desktop AppDir/

# Copy icon
echo "Copying icon..."
cp linux/gkshare.png AppDir/usr/share/icons/hicolor/256x256/apps/gkshare.png
cp linux/gkshare.png AppDir/gkshare.png

# Create AppImage
echo "Creating AppImage..."
if ! command -v appimagetool &> /dev/null; then
    echo "Downloading appimagetool..."
    wget -O appimagetool "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x appimagetool
fi

./appimagetool AppDir

echo "Cleaning up..."
rm -rf AppDir

echo "Done! The AppImage has been created." 