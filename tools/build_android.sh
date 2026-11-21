#!/bin/bash
#
# Builds lib<plugin name>.so per ABI into <output dir>/<abi>/ with the NDK's
# CMake toolchain. Needs the Android NDK (ANDROID_NDK_HOME, ANDROID_NDK_ROOT,
# or NDK_ROOT) and CMake 3.19+.
# Usage: bash tools/build_android.sh [output dir]   (default: build-android)

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_ROOT/build-android}"
ANDROID_MIN_API=21

. "$PROJECT_ROOT/tools/read_metadata.sh"
TARGET_NAME="$PLUGIN_NAME_UNDERSCORED"

NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-${NDK_ROOT:-}}}"
if [ -z "$NDK" ] || [ ! -d "$NDK" ]; then
    echo "ERROR: Android NDK not found. Set ANDROID_NDK_HOME, ANDROID_NDK_ROOT, or NDK_ROOT."
    exit 1
fi

TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake"
if [ ! -f "$TOOLCHAIN_FILE" ]; then
    echo "ERROR: NDK CMake toolchain not found at $TOOLCHAIN_FILE"
    exit 1
fi

echo "Building lib${TARGET_NAME}.so for Android (min API $ANDROID_MIN_API)..."
echo "  NDK: $NDK"

# CMake trees nest under _cmake/ so CI's <output dir>/*/lib<name>.so upload
# glob never matches the tree-root copy of the same .so.
for ABI in armeabi-v7a arm64-v8a x86 x86_64; do
    echo "  Building for $ABI..."
    BUILD_DIR="$OUTPUT_DIR/_cmake/$ABI"

    # The NDK toolchain passes -Wl,--no-undefined by default, but Lua symbols
    # resolve at load time from the Solar2D host process.
    # c++_static is the toolchain default, pinned because it is load-bearing
    # for any C++ source: Solar2D apps ship no libc++_shared.so.
    cmake -B "$BUILD_DIR" -S "$PROJECT_ROOT" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
        -DANDROID_ABI="$ABI" \
        -DANDROID_PLATFORM="android-$ANDROID_MIN_API" \
        -DANDROID_STL=c++_static \
        -DANDROID_ALLOW_UNDEFINED_SYMBOLS=ON

    cmake --build "$BUILD_DIR" --target "$TARGET_NAME" --config Release

    mkdir -p "$OUTPUT_DIR/$ABI"
    cp "$BUILD_DIR/lib${TARGET_NAME}.so" "$OUTPUT_DIR/$ABI/lib${TARGET_NAME}.so"
    echo "    Built: $OUTPUT_DIR/$ABI/lib${TARGET_NAME}.so"
done

echo "Done."
