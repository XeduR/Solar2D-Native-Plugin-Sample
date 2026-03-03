#!/bin/bash
#
# Solar2D Hello Plugin - macOS Build Script
#
# Builds plugin_hello.dylib using the Solar2D Native SDK headers.
# This script can be used standalone or as part of a CI pipeline.
#
# Usage:
#   ./build.sh [output_dir]
#
# If CORONA_ROOT is set, Solar2D Native headers are used.
# Otherwise, falls back to the bundled Lua headers.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
OUTPUT_DIR="${1:-$SCRIPT_DIR}"
TARGET_NAME="plugin_hello"
OUTPUT_FILE="$OUTPUT_DIR/$TARGET_NAME.dylib"

# Determine include paths
if [ -n "$CORONA_ROOT" ] && [ -d "$CORONA_ROOT/Corona/shared/include" ]; then
    echo "Using Solar2D Native SDK headers from: $CORONA_ROOT"
    INCLUDE_FLAGS="-I$CORONA_ROOT/Corona/shared/include/Corona -I$CORONA_ROOT/Corona/shared/include/lua"
else
    echo "CORONA_ROOT not set or not found. Using bundled Lua headers."
    INCLUDE_FLAGS="-I$PROJECT_ROOT/external/lua51"
fi

echo "Building $TARGET_NAME.dylib..."
echo "  Source: $SRC_DIR"
echo "  Output: $OUTPUT_FILE"

# Build universal binary (x86_64 + arm64)
clang -dynamiclib \
    -arch x86_64 -arch arm64 \
    -std=c99 \
    -O2 \
    -fvisibility=hidden \
    -DNDEBUG \
    $INCLUDE_FLAGS \
    -undefined dynamic_lookup \
    "$SRC_DIR/plugin_hello.c" \
    -o "$OUTPUT_FILE"

echo "Built: $OUTPUT_FILE"
file "$OUTPUT_FILE"

# Optionally copy to Solar2D Simulator plugins directory
SIMULATOR_PLUGINS="$HOME/Library/Application Support/Corona/Simulator/Plugins"
if [ -d "$SIMULATOR_PLUGINS" ] || [ -d "$(dirname "$SIMULATOR_PLUGINS")" ]; then
    mkdir -p "$SIMULATOR_PLUGINS"
    cp "$OUTPUT_FILE" "$SIMULATOR_PLUGINS/"
    echo "Installed to: $SIMULATOR_PLUGINS/$TARGET_NAME.dylib"
fi
