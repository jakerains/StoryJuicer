#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

configuration="Debug"
skip_generate=0

usage() {
    cat <<'EOF'
Usage: ./scripts/run.sh [options]

Options:
  --release         Build and run Release app bundle
  --debug           Build and run Debug app bundle (default)
  --skip-generate   Skip xcodegen generation
  -h, --help        Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --release)
            configuration="Release"
            ;;
        --debug)
            configuration="Debug"
            ;;
        --skip-generate)
            skip_generate=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf '[ERROR] Unknown option: %s\n' "$1"
            usage
            exit 1
            ;;
    esac
    shift
done

build_args=()
if (( skip_generate == 1 )); then
    build_args+=(--skip-generate)
fi

if [[ "$configuration" == "Release" ]]; then
    build_args+=(--release)
fi

"$ROOT_DIR/scripts/build.sh" "${build_args[@]}"

app_path="$(xcodebuild \
    -project "$ROOT_DIR/StoryJuicer.xcodeproj" \
    -scheme StoryJuicer \
    -configuration "$configuration" \
    -destination 'platform=macOS' \
    -showBuildSettings | awk -F' = ' '
        /TARGET_BUILD_DIR = / { target=$2 }
        /WRAPPER_NAME = / { wrapper=$2 }
        END { if (target != "" && wrapper != "") print target "/" wrapper }
    ')"

if [[ -z "$app_path" ]]; then
    printf '[ERROR] Failed to resolve built app path.\n'
    exit 1
fi

printf '[INFO] Launching %s\n' "$app_path"
open "$app_path"
