#!/bin/bash
set -euo pipefail

# ── StoryFox Release Script ──────────────────────────────────────
# Automates the full release pipeline:
#   1. Bump version in project.yml
#   2. Build, sign, notarize, and package DMG
#   3. Generate appcast with EdDSA signatures
#   4. Create GitHub release with DMG
#   5. Commit and push appcast + version changes
#
# Usage:
#   ./scripts/release.sh <version> [--notes "Release notes"]
#
# Examples:
#   ./scripts/release.sh 1.1.0
#   ./scripts/release.sh 1.0.3 --notes "Fixed a bug with PDF export"
# ─────────────────────────────────────────────────────────────────────

VERSION="${1:-}"
NOTES=""

# Parse args
shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --notes) NOTES="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    echo "Usage: ./scripts/release.sh <version> [--notes \"Release notes\"]"
    echo ""
    echo "Examples:"
    echo "  ./scripts/release.sh 1.1.0"
    echo "  ./scripts/release.sh 1.0.3 --notes \"Fixed a bug with PDF export\""
    exit 1
fi

# Validate version format (semver-ish)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: Version must be in format X.Y or X.Y.Z (got: $VERSION)"
    exit 1
fi

# Check for clean working tree (allow untracked files)
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Error: Working tree has uncommitted changes. Commit or stash first."
    exit 1
fi

echo "═══════════════════════════════════════════════════════"
echo "  StoryFox Release v${VERSION}"
echo "═══════════════════════════════════════════════════════"
echo ""

# ── Step 1: Bump version ────────────────────────────────────────────

echo "──── 1/6  Bumping version to ${VERSION} ────"

# Read current build number from project.yml, increment it
CURRENT_BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION:' project.yml | sed 's/.*"\([0-9]*\)".*/\1/')
NEW_BUILD=$((CURRENT_BUILD + 1))

# Update macOS target version (first occurrence)
sed -i '' "0,/MARKETING_VERSION: \"[^\"]*\"/s//MARKETING_VERSION: \"${VERSION}\"/" project.yml
sed -i '' "0,/CURRENT_PROJECT_VERSION: \"[0-9]*\"/s//CURRENT_PROJECT_VERSION: \"${NEW_BUILD}\"/" project.yml

echo "    Version: ${VERSION} (build ${NEW_BUILD})"
echo ""

# ── Step 2: Build DMG ───────────────────────────────────────────────

echo "──── 2/6  Building signed & notarized DMG ────"
echo "    (This takes several minutes)"
echo ""
make dmg
echo ""

# ── Step 3: Sign and generate appcast ───────────────────────────────

echo "──── 3/6  Generating appcast with EdDSA signatures ────"

SPARKLE_BIN_DIR=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Sparkle/bin" -type d 2>/dev/null | head -1)
if [[ -z "$SPARKLE_BIN_DIR" ]]; then
    echo "Error: Sparkle bin directory not found. Run 'make build' first."
    exit 1
fi

"${SPARKLE_BIN_DIR}/generate_appcast" \
    --download-url-prefix "https://github.com/jakerains/StoryFox/releases/download/v${VERSION}/" \
    -o appcast.xml \
    dist

# Verify signature was added
if ! grep -q 'sparkle:edSignature' appcast.xml; then
    echo "Warning: EdDSA signature missing from appcast. Adding manually..."
    SIGNATURE=$("${SPARKLE_BIN_DIR}/sign_update" dist/StoryFox.dmg | grep -o 'sparkle:edSignature="[^"]*"')
    sed -i '' "s|url=\"https://github.com/jakerains/StoryFox/releases/download/v${VERSION}/StoryFox.dmg\"|url=\"https://github.com/jakerains/StoryFox/releases/download/v${VERSION}/StoryFox.dmg\" ${SIGNATURE}|" appcast.xml
fi

echo "    Appcast updated with v${VERSION} entry"
echo ""

# ── Step 4: Create GitHub release ───────────────────────────────────

echo "──── 4/6  Creating GitHub release v${VERSION} ────"

DEFAULT_NOTES="## StoryFox v${VERSION}

Download the DMG, mount it, and drag StoryFox to Applications.
Existing users will be prompted to update automatically."

gh release create "v${VERSION}" dist/StoryFox.dmg \
    --title "StoryFox v${VERSION}" \
    --notes "${NOTES:-$DEFAULT_NOTES}"

echo ""

# ── Step 5: Commit version + appcast ────────────────────────────────

echo "──── 5/6  Committing version bump and appcast ────"

git add project.yml appcast.xml StoryFox.xcodeproj/project.pbxproj
git commit -m "Release v${VERSION}

- Bump to ${VERSION} (build ${NEW_BUILD})
- Update appcast with signed DMG entry"

echo ""

# ── Step 6: Push ────────────────────────────────────────────────────

echo "──── 6/6  Pushing to origin/main ────"
git push origin main

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✅ Release v${VERSION} complete!"
echo ""
echo "  DMG:     dist/StoryFox.dmg"
echo "  Release: https://github.com/jakerains/StoryFox/releases/tag/v${VERSION}"
echo "  Appcast: https://raw.githubusercontent.com/jakerains/StoryFox/main/appcast.xml"
echo ""
echo "  Users on older versions will see the update automatically."
echo "═══════════════════════════════════════════════════════"
