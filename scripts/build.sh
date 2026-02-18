#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

configuration="Debug"
clean_first=0
skip_generate=0

usage() {
    cat <<'EOF'
Usage: ./scripts/build.sh [options]

Options:
  --release         Build using Release configuration
  --debug           Build using Debug configuration (default)
  --clean           Run clean before build
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
        --clean)
            clean_first=1
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

if (( skip_generate == 0 )); then
    "$ROOT_DIR/scripts/generate.sh"
fi

build_cmd=(
    xcodebuild
    -project StoryJuicer.xcodeproj
    -scheme StoryJuicer
    -configuration "$configuration"
    -destination "platform=macOS"
)

if (( clean_first == 1 )); then
    printf '[INFO] Cleaning build artifacts...\n'
    "${build_cmd[@]}" clean
fi

printf '[INFO] Building StoryJuicer (%s)...\n' "$configuration"
"${build_cmd[@]}" build
printf '[OK] Build completed.\n'
