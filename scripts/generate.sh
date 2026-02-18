#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
    printf '[ERROR] xcodegen is required. Install it and retry.\n'
    exit 1
fi

printf '[INFO] Generating StoryJuicer.xcodeproj from project.yml...\n'
xcodegen generate --spec project.yml
printf '[OK] Project generated.\n'
