#!/bin/bash
# CI test hook, run by the workflow's test job on Linux. Builds the plugin for
# the host and runs the Lua test against the built library. Needs CMake 3.19+,
# a C compiler, and the packages listed in test/ci_apt.txt.
# Usage: bash test/ci_test.sh
set -eo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build-test"

. "$PROJECT_ROOT/tools/read_metadata.sh"

cmake -B "$BUILD_DIR" -S "$PROJECT_ROOT" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --config Release --target "$PLUGIN_NAME_UNDERSCORED"

# Stage the library on the C loader's dots-to-directories path so
# require("<pluginName>") resolves it.
modulePath="$(echo "$PLUGIN_NAME_DOTTED" | tr '.' '/')"
mkdir -p "$BUILD_DIR/test-stage/$(dirname "$modulePath")"
cp "$BUILD_DIR/$PLUGIN_NAME_UNDERSCORED.so" "$BUILD_DIR/test-stage/$modulePath.so"

lua5.1 "$PROJECT_ROOT/test/test_plugin.lua" "$BUILD_DIR/test-stage" "$PLUGIN_NAME_DOTTED"
