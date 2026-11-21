#!/bin/bash
# Installs the pinned CMake for the Linux CI job, whose Ubuntu 20.04 container
# ships a CMake older than the 3.19 this project needs. The version matches the
# one local_build.bat bootstraps. Verifies the download against the hash pinned
# here and prepends the CMake bin directory to GITHUB_PATH.
set -euo pipefail

CMAKE_VERSION="4.4.3"
# Pinned here so a replaced release asset cannot vouch for itself; a version bump also updates local_build.bat's version and zip hash.
CMAKE_SHA256="d6c83076c575bc00b823522ac974bda66d0af05d6ddc30e739c12385cf32c6cc"

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo "ERROR: pin_cmake.sh carries the Linux x86_64 CMake only; this host is $(uname -s) $(uname -m)"
    exit 1
fi

ARCHIVE="cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz"
BIN_SUBDIR="cmake-${CMAKE_VERSION}-linux-x86_64/bin"
URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${ARCHIVE}"

DEST="${RUNNER_TEMP:-/tmp}/pinned-cmake"
mkdir -p "$DEST"
cd "$DEST"

curl -fsSLO "$URL"

ACTUAL_SHA256="$(sha256sum "$ARCHIVE" | cut -d ' ' -f 1)"
if [ "$ACTUAL_SHA256" != "$CMAKE_SHA256" ]; then
    echo "ERROR: ${ARCHIVE} SHA-256 mismatch: expected ${CMAKE_SHA256}, got ${ACTUAL_SHA256}"
    rm -f "$ARCHIVE"
    exit 1
fi

tar -xzf "$ARCHIVE"

# In Actions, prepend the pinned bin to the job PATH; outside it, print where it is.
if [ -n "${GITHUB_PATH:-}" ]; then
    echo "${DEST}/${BIN_SUBDIR}" >> "$GITHUB_PATH"
else
    echo "Pinned CMake available at ${DEST}/${BIN_SUBDIR}"
fi
"${DEST}/${BIN_SUBDIR}/cmake" --version
