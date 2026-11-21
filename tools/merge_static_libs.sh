#!/bin/bash
#
# Prelinks every static archive in a one-architecture build tree into a single
# relocatable object that exports only _luaopen_* and archives it, so the
# Solar2D app link needs one staticLibs entry and the plugin's other symbols
# cannot collide with another plugin's. Fails if any other global symbol stays
# defined, or if any input object needs a newer OS than the min version.
# The platform, min version and SDK version stamp the prelinked object's LC_BUILD_VERSION.
# Usage: bash merge_static_libs.sh <build dir> <output archive> <arch> <ld platform> <min version> <sdk version>

set -e

BUILD_DIR="$1"
OUTPUT="$2"
ARCH="$3"
LD_PLATFORM="$4"
MIN_VERSION="$5"
SDK_VERSION="$6"

if [ -z "$BUILD_DIR" ] || [ -z "$OUTPUT" ] || [ -z "$ARCH" ] || [ -z "$LD_PLATFORM" ] || [ -z "$MIN_VERSION" ] || [ -z "$SDK_VERSION" ]; then
    echo "ERROR: usage: merge_static_libs.sh <build dir> <output archive> <arch> <ld platform> <min version> <sdk version>"
    exit 1
fi

# Discovered, not hardcoded, so a bundled dependency's archive is never left out.
archives=()
while IFS= read -r archive; do
    archives+=("$archive")
done < <(find "$BUILD_DIR" -name '*.a' -not -name "$(basename "$OUTPUT")")

if [ "${#archives[@]}" -eq 0 ]; then
    echo "ERROR: no static archives found under $BUILD_DIR"
    exit 1
fi

workDir=$(mktemp -d)
trap 'rm -rf "$workDir"' EXIT

# ld -r only warns when a member was built for a newer OS than the stamp, so each
# member's own minos (LC_VERSION_MIN_* version on older objects) is checked.
for archive in "${archives[@]}"; do
    xcrun otool -l "$archive" >> "$workDir/members.otool"
done

if ! awk -v minimum="$MIN_VERSION" '
    function isNewer(version, limit,    parts, limitParts, i) {
        split(version, parts, ".")
        split(limit, limitParts, ".")

        for (i = 1; i <= 3; i++) {
            if (parts[i] + 0 != limitParts[i] + 0) {
                return parts[i] + 0 > limitParts[i] + 0
            }
        }

        return 0
    }

    /^[^ ].*\(.*\):$/ { member = $0; next }
    /^Load command/ { command = ""; next }
    $1 == "cmd" { command = $2; next }

    # LC_BUILD_VERSION also lists tool versions, so only minos counts there.
    (command == "LC_BUILD_VERSION" && $1 == "minos") || (command ~ /^LC_VERSION_MIN_/ && $1 == "version") {
        checked++

        if (isNewer($2, minimum)) {
            newer++
            if (newer <= 20) {
                print "    " member " needs " $2
            }
        }
    }

    END {
        if (checked == 0) {
            print "ERROR: no minimum OS version found in any archive member"
            exit 1
        }

        if (newer > 0) {
            print "ERROR: " newer " archive member(s) need a newer OS than " minimum
            exit 1
        }
    }
' "$workDir/members.otool"; then
    exit 1
fi

# -r leaves archive members unloaded unless something references them, hence
# -all_load; the export list hides every other global and -r then makes it local.
echo "    Prelinking ${#archives[@]} archive(s) for $ARCH ($LD_PLATFORM $MIN_VERSION, SDK $SDK_VERSION)..."
echo '_luaopen_*' > "$workDir/exports"
xcrun ld -r -arch "$ARCH" -platform_version "$LD_PLATFORM" "$MIN_VERSION" "$SDK_VERSION" \
    -all_load -exported_symbols_list "$workDir/exports" \
    -o "$workDir/prelinked.o" "${archives[@]}"

rm -f "$OUTPUT"
libtool -static -o "$OUTPUT" "$workDir/prelinked.o"

# Separate nm and filter steps so an nm failure aborts under set -e. The filter
# drops the blank and "archive(member):" header lines nm prints for archives.
xcrun nm -g -U -j "$OUTPUT" > "$workDir/exported.raw"
grep -v -e '^$' -e ':$' "$workDir/exported.raw" | sort -u > "$workDir/exported"
leaked=$(grep -v '^_luaopen_' "$workDir/exported" | head -20)

if [ -n "$leaked" ]; then
    echo "ERROR: prelinked archive still defines global symbols other than _luaopen_*:"
    echo "$leaked"
    exit 1
fi
