#!/bin/bash
#
# Builds the plugin's iOS or tvOS static archives with CMake and prelinks each
# slice via merge_static_libs.sh (only _luaopen_* stays global) into:
#   <output dir>/device/lib<plugin name>.a     (arm64)
#   <output dir>/simulator/lib<plugin name>.a  (arm64 + x86_64, lipo-merged)
# Needs macOS with Xcode and CMake 3.19+.
# Usage: bash tools/build_apple.sh <ios|tvos> [output dir]   (default: build-<ios|tvos>)

set -e

PLATFORM="$1"
MIN_VERSION="15.0"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

case "$PLATFORM" in
    ios) SYSTEM_NAME="iOS"; DEVICE_SDK="iphoneos"; SIM_SDK="iphonesimulator"; DEVICE_LD_PLATFORM="ios"; SIM_LD_PLATFORM="ios-simulator" ;;
    tvos) SYSTEM_NAME="tvOS"; DEVICE_SDK="appletvos"; SIM_SDK="appletvsimulator"; DEVICE_LD_PLATFORM="tvos"; SIM_LD_PLATFORM="tvos-simulator" ;;
    *)
        echo "ERROR: usage: build_apple.sh <ios|tvos> [output dir]"
        exit 1
        ;;
esac

OUTPUT_DIR="${2:-$PROJECT_ROOT/build-$PLATFORM}"

. "$PROJECT_ROOT/tools/read_metadata.sh"
TARGET_NAME="$PLUGIN_NAME_UNDERSCORED"

# buildSlice <build dir> <arch> <sdk> <ld platform>
buildSlice() {
    local buildDir="$1"
    local arch="$2"
    local sdk="$3"
    local ldPlatform="$4"
    local sdkVersion

    echo "  Building $arch against $sdk..."
    cmake -B "$buildDir" -S "$PROJECT_ROOT" \
        -DCMAKE_SYSTEM_NAME="$SYSTEM_NAME" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_VERSION" \
        -DCMAKE_OSX_ARCHITECTURES="$arch" \
        -DCMAKE_OSX_SYSROOT="$sdk" \
        -DCMAKE_BUILD_TYPE=Release
    cmake --build "$buildDir" --target "$TARGET_NAME" --config Release

    sdkVersion=$(xcrun --sdk "$sdk" --show-sdk-version)
    bash "$SCRIPT_DIR/merge_static_libs.sh" "$buildDir" "$buildDir/merged.a" "$arch" \
        "$ldPlatform" "$MIN_VERSION" "$sdkVersion"
}

echo "Building lib${TARGET_NAME}.a for $SYSTEM_NAME (min version $MIN_VERSION)..."

buildSlice "$OUTPUT_DIR/_build-device" arm64 "$DEVICE_SDK" "$DEVICE_LD_PLATFORM"
mkdir -p "$OUTPUT_DIR/device"
cp "$OUTPUT_DIR/_build-device/merged.a" "$OUTPUT_DIR/device/lib${TARGET_NAME}.a"

buildSlice "$OUTPUT_DIR/_build-sim-arm64" arm64 "$SIM_SDK" "$SIM_LD_PLATFORM"
buildSlice "$OUTPUT_DIR/_build-sim-x86_64" x86_64 "$SIM_SDK" "$SIM_LD_PLATFORM"

mkdir -p "$OUTPUT_DIR/simulator"
lipo -create \
    "$OUTPUT_DIR/_build-sim-arm64/merged.a" \
    "$OUTPUT_DIR/_build-sim-x86_64/merged.a" \
    -output "$OUTPUT_DIR/simulator/lib${TARGET_NAME}.a"

echo "Built:"
echo "  Device:    $OUTPUT_DIR/device/lib${TARGET_NAME}.a"
echo "  Simulator: $OUTPUT_DIR/simulator/lib${TARGET_NAME}.a"
file "$OUTPUT_DIR/device/lib${TARGET_NAME}.a" "$OUTPUT_DIR/simulator/lib${TARGET_NAME}.a"
