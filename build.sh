#!/bin/bash

# Configuration

TARGET_DIR="$AEROSIM_OMNIVERSE_ROOT/source/extensions"
AEROSIM_EXTENSION="aerosim.omniverse.extension"

# Cesium extension is disabled for Kit 107.3.0 (requires rebuild for Python 3.11)
# CESIUM_FOLDER1="cesium.omniverse"
# CESIUM_FOLDER2="cesium.usd.plugins"
# ZIP_URL="https://github.com/CesiumGS/cesium-omniverse/releases/download/v0.24.0/CesiumGS-cesium-omniverse-linux-x86_64-v0.24.0.zip"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

set -e

echo "AEROSIM_WORLD_LINK_LIB is set to: $AEROSIM_WORLD_LINK_LIB"
mkdir -p "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim-world-link-lib"
cp -r "$AEROSIM_WORLD_LINK_LIB"/* "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim-world-link-lib"
echo "$TARGET_DIR/$AEROSIM_EXTENSION/aerosim-world-link-lib">"$TARGET_DIR/$AEROSIM_EXTENSION/aerosim_world_link_lib_path.txt"

SCRIPT_DIR=$(dirname ${BASH_SOURCE})
source "$SCRIPT_DIR/repo.sh" build $@ || exit $?
