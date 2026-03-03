#!/bin/bash
#
# Solar2D Hello Plugin - iOS Build Script
#
# Builds libplugin_hello.a static libraries for iOS device and Simulator.
#
# Usage:
#   ./build.sh [output_dir]
#
# Prerequisites:
#   Xcode Command Line Tools (xcode-select --install)
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
IOS_MIN_VERSION="12.0"

# Determine include paths
if [ -n "$CORONA_ROOT" ] && [ -d "$CORONA_ROOT/Corona/shared/include" ]; then
    echo "Using Solar2D Native SDK headers from: $CORONA_ROOT"
    INCLUDE_FLAGS="-I$CORONA_ROOT/Corona/shared/include/Corona -I$CORONA_ROOT/Corona/shared/include/lua"
else
    echo "CORONA_ROOT not set or not found. Using bundled Lua headers."
    INCLUDE_FLAGS="-I$PROJECT_ROOT/external/lua51"
fi

IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)

echo "Building lib${TARGET_NAME}.a for iOS..."
echo "  Source: $SRC_DIR"
echo "  Output: $OUTPUT_DIR"
echo "  Min iOS version: $IOS_MIN_VERSION"

# iOS device (arm64)
echo "  Building for iOS device (arm64)..."
mkdir -p "$OUTPUT_DIR/device"
clang -c \
    -arch arm64 \
    -isysroot "$IOS_SDK" \
    -miphoneos-version-min=$IOS_MIN_VERSION \
    -std=c99 -O2 -fvisibility=hidden -DNDEBUG \
    $INCLUDE_FLAGS \
    "$SRC_DIR/plugin_hello.c" \
    -o "$OUTPUT_DIR/device/plugin_hello.o"

ar rcs "$OUTPUT_DIR/device/lib${TARGET_NAME}.a" "$OUTPUT_DIR/device/plugin_hello.o"
rm "$OUTPUT_DIR/device/plugin_hello.o"

# iOS Simulator (arm64 + x86_64)
echo "  Building for iOS Simulator (arm64 + x86_64)..."
mkdir -p "$OUTPUT_DIR/simulator"
clang -c \
    -arch arm64 -arch x86_64 \
    -isysroot "$SIM_SDK" \
    -mios-simulator-version-min=$IOS_MIN_VERSION \
    -std=c99 -O2 -fvisibility=hidden -DNDEBUG \
    $INCLUDE_FLAGS \
    "$SRC_DIR/plugin_hello.c" \
    -o "$OUTPUT_DIR/simulator/plugin_hello.o"

ar rcs "$OUTPUT_DIR/simulator/lib${TARGET_NAME}.a" "$OUTPUT_DIR/simulator/plugin_hello.o"
rm "$OUTPUT_DIR/simulator/plugin_hello.o"

echo "Built:"
echo "  Device:    $OUTPUT_DIR/device/lib${TARGET_NAME}.a"
echo "  Simulator: $OUTPUT_DIR/simulator/lib${TARGET_NAME}.a"
file "$OUTPUT_DIR/device/lib${TARGET_NAME}.a"
file "$OUTPUT_DIR/simulator/lib${TARGET_NAME}.a"
