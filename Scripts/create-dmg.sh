#!/bin/bash
set -e

# Configuration
APP_NAME="Sonata"
DMG_NAME="Sonata.dmg"
BUILD_DIR="build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Release/${APP_NAME}.app"
DMG_DIR="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "Creating DMG for $APP_NAME..."

# Verify app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    echo "Available in Release:"
    ls -la "$DERIVED_DATA/Build/Products/Release/" 2>/dev/null || echo "Release directory not found"
    exit 1
fi

# Clean up previous DMG artifacts
rm -rf "$DMG_DIR"
rm -f "$DMG_PATH"

# Create DMG directory structure
mkdir -p "$DMG_DIR"

# Copy app to DMG directory
echo "Copying app..."
cp -R "$APP_PATH" "$DMG_DIR/"

# Create Applications symlink for drag-and-drop installation
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# Clean up
rm -rf "$DMG_DIR"

echo "DMG created at $DMG_PATH"
ls -lh "$DMG_PATH"
