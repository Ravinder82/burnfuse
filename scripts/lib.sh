#!/usr/bin/env bash
#
# Shared environment for BurnFuse build scripts.
#
# Swift build output goes to a cache directory outside the repo on purpose:
# if the project lives under Desktop/Documents, iCloud Drive writes to files
# mid-build and SwiftPM fails with "input file was modified during the build".

MACOS_DIR="${ROOT}/macos"
SWIFT_SCRATCH="${BURNFUSE_SCRATCH:-$HOME/Library/Caches/burnfuse-build}"

swift_build() {
    swift build --package-path "$MACOS_DIR" --scratch-path "$SWIFT_SCRATCH" "$@"
}

swift_bin_path() {
    swift_build --show-bin-path
}

swift_test() {
    swift test --package-path "$MACOS_DIR" --scratch-path "$SWIFT_SCRATCH" "$@"
}