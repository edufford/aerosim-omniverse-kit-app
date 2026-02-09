#!/bin/bash

# Configuration

TARGET_DIR="$AEROSIM_OMNIVERSE_ROOT/source/extensions"
AEROSIM_EXTENSION="aerosim.omniverse.extension"

CESIUM_FOLDER1="cesium.omniverse"
CESIUM_FOLDER2="cesium.usd.plugins"
ZIP_URL="https://github.com/CesiumGS/cesium-omniverse/releases/download/v0.27.0/CesiumGS-cesium-omniverse-linux-x86_64-v0.27.0.zip"
ZIP_FILE="$TARGET_DIR/cesium_omniverse.zip"
EXTRACT_PATH="$TARGET_DIR"
SETUP_CESIUM=true

# Check if the folders exist
if [ -d "$TARGET_DIR/$CESIUM_FOLDER1" ] && [ -d "$TARGET_DIR/$CESIUM_FOLDER2" ]; then
    echo "Cesium extension folders already exist. No need to download."
    SETUP_CESIUM=false
fi

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Download the ZIP file if the folders don't exist
if [ "$SETUP_CESIUM" = true ]; then
    echo "Downloading Cesium Omniverse file..."
    if curl -L -o "$ZIP_FILE" "$ZIP_URL"; then
        echo "File downloaded successfully."

        # Extract the ZIP file
        echo "Extracting the file to $EXTRACT_PATH..."
        if unzip -o "$ZIP_FILE" -d "$EXTRACT_PATH"; then
            echo "Extraction completed successfully."
        else
            echo "Error: Extraction failed."
            exit 1
        fi

        # Check if extraction was successful
        if [ -d "$EXTRACT_PATH/$CESIUM_FOLDER1" ]; then
            echo "Extraction verified."
        else
            echo "Error: The folder $CESIUM_FOLDER1 was not found after extraction."
        fi

        echo -n "repo_build.prebuild_link { \"mdl\", ext.target_dir..\"/mdl\" }" >> "$TARGET_DIR/$CESIUM_FOLDER1/premake5.lua"
        echo -n "repo_build.prebuild_link { \"vendor\", ext.target_dir..\"/vendor\" }" >> "$TARGET_DIR/$CESIUM_FOLDER1/premake5.lua"

        # Delete the ZIP file after extraction
        rm -f "$ZIP_FILE"
        echo "ZIP file deleted."
    else
        echo "Error: The file could not be downloaded."
        exit 1
    fi
fi

set -e

echo "AEROSIM_WORLD_LINK_LIB is set to: $AEROSIM_WORLD_LINK_LIB"
mkdir -p "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim-world-link-lib"
cp -r "$AEROSIM_WORLD_LINK_LIB"/* "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim-world-link-lib"
echo "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim-world-link-lib">"$TARGET_DIR/$AEROSIM_EXTENSION/aerosim_world_link_lib_path.txt"

SCRIPT_DIR=$(dirname ${BASH_SOURCE})
source "$SCRIPT_DIR/repo.sh" build $@ || exit $?
