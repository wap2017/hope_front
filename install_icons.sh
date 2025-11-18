#!/bin/bash

# Quick script to install your new app icons
# Usage: ./install_icons.sh /path/to/your/flutter/project

if [ -z "$1" ]; then
    echo "Usage: ./install_icons.sh /path/to/your/flutter/project"
    echo "Example: ./install_icons.sh ~/development/hope_front"
    exit 1
fi

PROJECT_PATH="$1"
RES_PATH="${PROJECT_PATH}/android/app/src/main/res"

if [ ! -d "$RES_PATH" ]; then
    echo "Error: Cannot find $RES_PATH"
    echo "Make sure you provided the correct Flutter project path"
    exit 1
fi

echo "📱 Installing app icons to: $RES_PATH"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ICONS_DIR="${SCRIPT_DIR}/icons"

if [ ! -d "$ICONS_DIR" ]; then
    echo "Error: Cannot find icons folder at $ICONS_DIR"
    echo "Make sure the icons folder is in the same directory as this script"
    exit 1
fi

# Backup existing icons
echo "📦 Creating backup of existing icons..."
BACKUP_DIR="${HOME}/flutter_icon_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r "${RES_PATH}"/mipmap-*/ic_launcher.png "$BACKUP_DIR/" 2>/dev/null
echo "✅ Backup saved to: $BACKUP_DIR"
echo ""

# Copy new icons
echo "🎨 Installing new icons..."
for folder in mipmap-mdpi mipmap-hdpi mipmap-xhdpi mipmap-xxhdpi mipmap-xxxhdpi; do
    if [ -f "${ICONS_DIR}/${folder}/ic_launcher.png" ]; then
        cp "${ICONS_DIR}/${folder}/ic_launcher.png" "${RES_PATH}/${folder}/"
        echo "  ✓ Copied ${folder}/ic_launcher.png"
    else
        echo "  ⚠ Warning: ${folder}/ic_launcher.png not found"
    fi
done

echo ""
echo "✅ Icons installed successfully!"
echo ""
echo "Next steps:"
echo "1. cd $PROJECT_PATH"
echo "2. flutter clean"
echo "3. flutter run -d YOUR_DEVICE_ID"
echo ""
echo "Note: If the icon doesn't update, uninstall the app and reinstall it."
echo "Android caches launcher icons aggressively!"
