#!/bin/bash
set -euo pipefail

# ── Inject Release Notes into appcast.xml ────────────────────────────
# Reads HTML snippets from release-notes/{version}.html and injects
# them as <description><![CDATA[...]]></description> into the matching
# <item> in appcast.xml (matched by <sparkle:shortVersionString>).
#
# Safe to run repeatedly — removes existing <description> blocks first.
#
# Usage:
#   ./scripts/inject-release-notes.sh [appcast-path]
#
# Default appcast path: appcast.xml in the repo root.
# ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APPCAST="${1:-${REPO_ROOT}/appcast.xml}"
NOTES_DIR="${REPO_ROOT}/release-notes"

if [[ ! -f "$APPCAST" ]]; then
    echo "Error: appcast.xml not found at $APPCAST"
    exit 1
fi

if [[ ! -d "$NOTES_DIR" ]]; then
    echo "Error: release-notes/ directory not found at $NOTES_DIR"
    exit 1
fi

# Count how many notes we inject
INJECTED=0

for NOTES_FILE in "$NOTES_DIR"/*.html; do
    [[ -f "$NOTES_FILE" ]] || continue

    # Extract version from filename (e.g., 1.7.3.html -> 1.7.3)
    FILENAME=$(basename "$NOTES_FILE")
    VERSION="${FILENAME%.html}"

    # Check if this version exists in the appcast
    if ! grep -q "<sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>" "$APPCAST"; then
        echo "  Skip: v${VERSION} (not found in appcast)"
        continue
    fi

    # Use awk to:
    # 1. Find the <item> block containing this version's shortVersionString
    # 2. Remove any existing <description>...</description> in that block
    # 3. Insert a new <description> with CDATA-wrapped HTML right after the <title> line
    #
    # NOTE: We pass the notes file path (not content) to awk via -v, then
    # read it inside awk with getline. This avoids BSD awk's inability to
    # handle multi-line strings in -v variable assignments.
    awk -v version="$VERSION" -v notes_file="$NOTES_FILE" '
    BEGIN {
        in_target_item = 0
        description_injected = 0
        skip_description = 0

        # Read the entire HTML file into a variable
        html = ""
        while ((getline line < notes_file) > 0) {
            if (html != "") html = html "\n"
            html = html line
        }
        close(notes_file)
    }

    # Track when we enter an <item>
    /<item>/ {
        in_target_item = 0
        description_injected = 0
    }

    # Check if this item matches our target version
    /<sparkle:shortVersionString>/ {
        if (index($0, ">" version "<") > 0) {
            in_target_item = 1
        }
    }

    # Skip existing <description> lines in the target item (may span multiple lines)
    in_target_item && /<description>/ { skip_description = 1 }
    skip_description {
        if (/<\/description>/) { skip_description = 0 }
        next
    }

    # Inject new <description> after <sparkle:shortVersionString> in the target item.
    # We inject here (not after <title>) because shortVersionString is the line
    # that triggers in_target_item — <title> has already been printed by then.
    {
        print
        if (in_target_item && !description_injected && /<sparkle:shortVersionString>/) {
            printf "            <description><![CDATA[%s]]></description>\n", html
            description_injected = 1
        }
    }

    /<\/item>/ {
        in_target_item = 0
    }
    ' "$APPCAST" > "${APPCAST}.tmp" && mv "${APPCAST}.tmp" "$APPCAST"

    echo "  Injected: v${VERSION}"
    INJECTED=$((INJECTED + 1))
done

if [[ "$INJECTED" -eq 0 ]]; then
    echo "No release notes injected (no matching versions found)."
else
    echo ""
    echo "Done — injected release notes for ${INJECTED} version(s) into $(basename "$APPCAST")"
fi
