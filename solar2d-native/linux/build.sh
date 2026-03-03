#!/bin/bash
#
# Solar2D Hello Plugin - Linux Build Script
#
# Builds plugin_hello.so using gcc/clang.
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
OUTPUT_FILE="$OUTPUT_DIR/$TARGET_NAME.so"
CC="${CC:-gcc}"

# Determine include paths
if [ -n "$CORONA_ROOT" ] && [ -d "$CORONA_ROOT/Corona/shared/include" ]; then
    echo "Using Solar2D Native SDK headers from: $CORONA_ROOT"
    INCLUDE_FLAGS="-I$CORONA_ROOT/Corona/shared/include/Corona -I$CORONA_ROOT/Corona/shared/include/lua"
else
    echo "CORONA_ROOT not set or not found. Using bundled Lua headers."
    INCLUDE_FLAGS="-I$PROJECT_ROOT/external/lua51"
fi

echo "Building $TARGET_NAME.so..."
echo "  Compiler: $CC"
echo "  Source: $SRC_DIR"
echo "  Output: $OUTPUT_FILE"

$CC -shared -fPIC \
    -std=c99 \
    -O2 \
    -fvisibility=hidden \
    -DNDEBUG \
    $INCLUDE_FLAGS \
    "$SRC_DIR/plugin_hello.c" \
    -Wl,--allow-shlib-undefined \
    -o "$OUTPUT_FILE"

echo "Built: $OUTPUT_FILE"
file "$OUTPUT_FILE"
