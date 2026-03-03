#!/bin/bash
#
# Solar2D Hello Plugin - Android Build Script
#
# Builds libplugin_hello.so for Android (multiple ABIs).
#
# Usage:
#   ./build.sh [output_dir]
#
# Prerequisites:
#   Android NDK (set ANDROID_NDK_HOME, ANDROID_NDK_ROOT, or NDK_ROOT)
#
# The script uses the bundled Lua headers. Lua symbols are resolved
# at runtime by the Solar2D host application.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
OUTPUT_DIR="${1:-$SCRIPT_DIR}"
TARGET_NAME="plugin_hello"
ANDROID_MIN_API=21

# Find Android NDK
NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-${NDK_ROOT:-}}}"
if [ -z "$NDK" ] || [ ! -d "$NDK" ]; then
    echo "ERROR: Android NDK not found."
    echo "Set ANDROID_NDK_HOME, ANDROID_NDK_ROOT, or NDK_ROOT."
    exit 1
fi

INCLUDE_FLAGS="-I$PROJECT_ROOT/external/lua51"

# Determine host platform for NDK toolchain
case "$(uname -s)" in
    Linux*)  HOST_TAG="linux-x86_64" ;;
    Darwin*) HOST_TAG="darwin-x86_64" ;;
    *)       echo "Unsupported host OS"; exit 1 ;;
esac

TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG"
if [ ! -d "$TOOLCHAIN" ]; then
    echo "ERROR: NDK toolchain not found at $TOOLCHAIN"
    exit 1
fi

echo "Building lib${TARGET_NAME}.so for Android..."
echo "  NDK: $NDK"
echo "  Source: $SRC_DIR"
echo "  Output: $OUTPUT_DIR"
echo "  Min API: $ANDROID_MIN_API"

# Build for each ABI
for ABI in armeabi-v7a arm64-v8a x86 x86_64; do
    case $ABI in
        armeabi-v7a) TARGET="armv7a-linux-androideabi${ANDROID_MIN_API}" ;;
        arm64-v8a)   TARGET="aarch64-linux-android${ANDROID_MIN_API}" ;;
        x86)         TARGET="i686-linux-android${ANDROID_MIN_API}" ;;
        x86_64)      TARGET="x86_64-linux-android${ANDROID_MIN_API}" ;;
    esac

    echo "  Building for $ABI..."
    mkdir -p "$OUTPUT_DIR/$ABI"

    "$TOOLCHAIN/bin/clang" \
        --target=$TARGET \
        -shared -fPIC \
        -std=c99 -O2 -fvisibility=hidden -DNDEBUG \
        $INCLUDE_FLAGS \
        "$SRC_DIR/plugin_hello.c" \
        -o "$OUTPUT_DIR/$ABI/lib${TARGET_NAME}.so"

    echo "    Built: $OUTPUT_DIR/$ABI/lib${TARGET_NAME}.so"
done

echo "Done."
