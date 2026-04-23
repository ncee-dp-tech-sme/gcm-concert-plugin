#!/bin/bash
# GCM Plugin Packaging Script for Unix/Linux/macOS
# This script packages a GCM plugin into a zip file ready for deployment

set -e  # Exit on error

# Read plugin metadata from manifest.json
if [ ! -f "manifest.json" ]; then
    echo "Error: manifest.json not found in current directory"
    exit 1
fi

PLUGIN_CODE=$(python3 -c "import json; print(json.load(open('manifest.json'))['code'])" 2>/dev/null)
PLUGIN_VERSION=$(python3 -c "import json; print(json.load(open('manifest.json'))['version'])" 2>/dev/null)

if [ -z "$PLUGIN_CODE" ] || [ -z "$PLUGIN_VERSION" ]; then
    echo "Error: Could not read 'code' or 'version' from manifest.json"
    exit 1
fi

PLUGIN_DIR="${PLUGIN_CODE}_${PLUGIN_VERSION}"
ZIP_NAME="${PLUGIN_CODE}-${PLUGIN_VERSION}.zip"

echo "Packaging plugin: $PLUGIN_CODE v$PLUGIN_VERSION"

# Verify .bundleignore exists
if [ ! -f ".bundleignore" ]; then
    echo "Error: .bundleignore file not found"
    exit 1
fi

# Clean up old files
echo "Cleaning up old files..."
rm -f "$ZIP_NAME"
rm -rf "$PLUGIN_DIR"

# Create temp directory
echo "Creating temporary directory..."
mkdir -p "$PLUGIN_DIR"

# Copy all files and directories to temp directory
echo "Copying files (excluding patterns from .bundleignore)..."
rsync -av --exclude-from='.bundleignore' \
  --exclude="$PLUGIN_DIR" \
  --exclude="*.zip" \
  . "$PLUGIN_DIR/"

# Create zip from contents of temp directory (files at root level)
echo "Creating zip file..."
cd "$PLUGIN_DIR"
zip -r "../$ZIP_NAME" . > /dev/null
cd ..

# Cleanup temp directory
echo "Cleaning up temporary directory..."
rm -rf "$PLUGIN_DIR"

# Report success
echo ""
echo "Plugin packaged successfully!"
echo "Zip file: $ZIP_NAME"
ls -lh "$ZIP_NAME"

# Verify structure
echo ""
echo "Verifying package structure..."
unzip -l "$ZIP_NAME" | head -20

echo ""
echo "Package ready for deployment!"


