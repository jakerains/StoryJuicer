#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

issues=0

check_command() {
    local name="$1"
    if command -v "$name" >/dev/null 2>&1; then
        printf '[OK] %s found\n' "$name"
    else
        printf '[FAIL] %s is not installed or not in PATH\n' "$name"
        issues=$((issues + 1))
    fi
}

check_command xcodebuild
check_command xcodegen
check_command swift

if command -v xcodebuild >/dev/null 2>&1; then
    xcode_version="$(xcodebuild -version | sed -n '1s/^Xcode //p')"
    printf '[INFO] Xcode version: %s\n' "$xcode_version"

    sdk_output="$(xcodebuild -showsdks 2>/dev/null || true)"
    if grep -q 'macosx26' <<< "$sdk_output"; then
        printf '[OK] macOS 26 SDK is available\n'
    else
        printf '[FAIL] macOS 26 SDK not found. Install the current Xcode toolchain.\n'
        issues=$((issues + 1))
    fi
fi

printf '[INFO] StoryJuicer is an Xcode app target. Use make build/make run (not swift run).\n'

if [[ -f StoryJuicer.xcodeproj/project.pbxproj ]]; then
    printf '[OK] StoryJuicer.xcodeproj exists\n'
else
    printf '[WARN] StoryJuicer.xcodeproj is missing. Run ./scripts/generate.sh\n'
fi

if (( issues > 0 )); then
    printf '\n[ERROR] Environment check failed with %d issue(s).\n' "$issues"
    printf '[NEXT] Install missing tools, then run: ./scripts/doctor.sh\n'
    exit 1
fi

printf '\n[OK] Environment looks ready for StoryJuicer.\n'
printf '[NEXT] Run ./scripts/build.sh to build the app.\n'
