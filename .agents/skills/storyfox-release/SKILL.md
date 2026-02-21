---
name: storyfox-release
description: >
  End-to-end StoryFox release workflow — version bump, changelog update,
  landing page version sync, commit, build signed+notarized DMG, run
  release.sh, and post-release verification. Use when the user says
  "release", "ship it", "cut a release", "new version", "push a release",
  "do a release", or asks to release StoryFox. Also use when they ask
  about the release process or how to ship a new version.
---

# StoryFox Release Skill

Complete release pipeline for StoryFox macOS app. Handles everything from
version bump through post-release verification, incorporating all lessons
learned from past incidents.

## Required Information

Ask the user for:
1. **Version number** (semver: `X.Y.Z`) — e.g., `1.8.0`
2. **What changed** — brief description for changelog entry (ask what type: `added`, `fixed`, `changed`, or `removed`)

The agent automatically generates `release-notes/{version}.html` from the changelog entry
(Phase 2d). No need to ask the user for separate release notes — they come from the changelog.

## Release Pipeline (7 Phases)

### Phase 1: Pre-Flight Checks

Before anything else, verify the environment is ready:

```bash
# Working tree must be clean (no uncommitted changes)
git diff --quiet && git diff --cached --quiet

# Verify we're on main
git branch --show-current  # must be "main"

# Verify signing identity exists
security find-identity -v -p codesigning | grep "Developer ID Application: Jacob RAINS"

# Verify notarization profile
xcrun notarytool history --keychain-profile "StoryFox-Notarize" 2>&1 | head -3
```

If the working tree is dirty, tell the user they need to commit or stash first.
The release script (`release.sh`) enforces this check too and will abort.

### Phase 2: Update Version, Changelog & Release Notes

Four files must be updated BEFORE committing:

#### 2a. `project.yml` — Version Bump

**DO NOT bump `project.yml` manually.** The release script (`release.sh`) handles
the version bump internally using `awk` (not `sed` — see Gotchas). Pre-bumping
causes a double-increment on the build number.

However, you DO need to know the current version to validate:
```bash
grep -m1 'MARKETING_VERSION:' project.yml
grep -m1 'CURRENT_PROJECT_VERSION:' project.yml
```

#### 2b. `landing/lib/changelog.ts` — Changelog Entry

Add a new entry at the TOP of the `changelog` array:

```typescript
{
  version: "X.Y.Z",
  date: "YYYY-MM-DD",       // today's date
  title: "Short Title",
  changes: [
    { type: "added", description: "..." },
    { type: "fixed", description: "..." },
    // etc.
  ],
},
```

Valid change types: `added`, `fixed`, `changed`, `removed`.

#### 2c. `landing/app/page.tsx` — Structured Data Version

Update the `softwareVersion` field in the JSON-LD structured data:

```typescript
softwareVersion: "X.Y.Z",
```

This is near the top of the file inside the `<script type="application/ld+json">` block.

#### 2d. `release-notes/{version}.html` — Sparkle "What's New" Dialog

Create an HTML snippet from the changelog entry you just wrote in 2b. **Write it for
normal users, not developers** — no jargon, no technical details, just plain language
about what they'll notice.

**Rules for writing release notes:**
- Use the changelog entry's `title` as the `<h2>` heading: `Version X.Y.Z — Title`
- Convert each changelog `description` into a plain-language `<li>` bullet
- Simplify technical descriptions: "Refactored generation pipeline" → "Faster story generation"
- Drop internal-only changes users won't see (code cleanup, refactoring, test changes)
- Use **New:** / **Improved:** / **Fixed:** prefixes (not `added`/`changed`/`fixed`)
- Keep it short — users scan this in a small dialog window

Example — given this changelog entry:
```typescript
{ type: "added", description: "Author Mode — write your own story text page-by-page, then StoryFox generates beautiful illustrations using the full AI image pipeline" },
{ type: "changed", description: "Creation mode toggle and book setup controls promoted above content for easier mode switching" },
```

Write this HTML:
```html
<h2>Version 1.7.4 — Author Mode</h2>
<ul>
  <li><strong>New:</strong> Author Mode — write your own story, then get AI-generated illustrations for every page</li>
  <li><strong>Improved:</strong> Easier access to creation mode and book setup controls</li>
</ul>
```

The release script will detect this file and use it as-is (it only auto-generates a
placeholder if no file exists).

### Phase 3: Commit Pre-Release Changes

All four file changes from Phase 2 MUST be committed before running the release
script. The script checks for a clean working tree and will abort if there are
uncommitted changes.

```bash
git add landing/lib/changelog.ts landing/app/page.tsx release-notes/
git commit -m "Update changelog, landing page, and release notes for vX.Y.Z"
```

Do NOT add `project.yml` here — the release script modifies and commits it.

### Phase 4: Run the Release Script

```bash
./scripts/release.sh X.Y.Z --notes "Release notes here"
```

Or without custom notes (uses default template):
```bash
./scripts/release.sh X.Y.Z
```

The script performs 8 steps internally:
1. Bumps `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` (using `awk`)
2. Runs `make dmg` (xcodegen, entitlements restore, archive, sign, notarize, staple, package)
3. Generates `appcast.xml` with EdDSA signatures via Sparkle's `generate_appcast`
4. Generates `release-notes/{version}.html` from `--notes` (semicolons → bullet points) or a default placeholder
5. Runs `scripts/inject-release-notes.sh` to inject all release notes HTML into appcast `<description>` elements
6. Creates a GitHub release with the DMG attached via `gh release create`
7. Commits `project.yml`, `appcast.xml`, `project.pbxproj`, and `release-notes/`
8. Pushes to `origin/main`

**Release notes tip:** Use semicolons in `--notes` to create separate bullet points in the
Sparkle "What's New" dialog. Example: `--notes "Added dark mode; Fixed export crash"`

**This step takes several minutes** — the notarization round-trips to Apple's servers.

### Phase 5: Post-Release Verification

**NEVER skip this.** The v1.7.1 incident shipped a DMG with a stale version because
the version bump silently failed (BSD sed bug).

```bash
# 1. Verify DMG has correct version
hdiutil attach dist/StoryFox.dmg -nobrowse -quiet
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "/Volumes/StoryFox/StoryFox.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "/Volumes/StoryFox/StoryFox.app/Contents/Info.plist"
hdiutil detach "/Volumes/StoryFox" -quiet

# 2. Verify appcast advertises the new version
grep -A4 'sparkle:version' appcast.xml | head -5

# 3. Verify project.yml was bumped
grep -m1 'MARKETING_VERSION:' project.yml
```

```bash
# 4. Verify release notes were injected into appcast
grep -c '<description><!\[CDATA' appcast.xml  # should match number of <item> elements
```

**What to check:**
- DMG's `CFBundleShortVersionString` matches the released version
- Appcast XML contains the new version with `sparkle:edSignature`
- Appcast XML has `<description><![CDATA[...]]>` for the new version (Sparkle "What's New" dialog)
- `release-notes/{version}.html` exists with correct content
- `project.yml` shows the new version

**Red flag:** If `generate_appcast` said "updated 1 existing" instead of
"Wrote 1 new update", the DMG's embedded version matches a prior release.
The bump failed — do NOT proceed, fix it.

### Phase 6: Verify Landing Page

The landing page auto-deploys via Vercel when changes are pushed to main.
No manual deploy needed. But confirm the push included the changelog update:

```bash
git log --oneline -3
```

Should show both the pre-release commit (changelog + page.tsx) and the
release commit (project.yml + appcast.xml).

### Phase 7: Release Recap

After all verification passes, present a summary to the user:

```
===================================================
  StoryFox vX.Y.Z is LIVE
===================================================

  Version:      X.Y.Z (build NN)
  DMG:          dist/StoryFox.dmg
  Release:      https://github.com/jakerains/StoryFox/releases/tag/vX.Y.Z
  Appcast:      https://raw.githubusercontent.com/jakerains/StoryFox/main/appcast.xml
  Release Notes: release-notes/X.Y.Z.html (injected into appcast)
  Landing:      Auto-deploying via Vercel (changelog updated)

  Existing users will see the update prompt with "What's New" via Sparkle.
===================================================
```

## Critical Gotchas (Learned the Hard Way)

### BSD sed Silent Failure
macOS ships BSD sed. The GNU-only `0,/pattern/` address does NOTHING on BSD —
no error, no change. The release script uses `awk` for first-occurrence
replacement. If you ever need to do first-occurrence replacement in a shell
script on macOS, use `awk`, never `sed`.

### XcodeGen Overwrites Entitlements
Every `xcodegen generate` silently replaces `Resources/StoryFox.entitlements`
with an empty `<dict/>`, stripping custom sandbox permissions (network client,
JIT, unsigned executable memory). The `make dmg` pipeline restores them
automatically via PlistBuddy, but manual `xcodegen generate` runs will lose them.
Always check entitlements after regenerating if doing a manual build.

### Don't Pre-Bump project.yml
The release script bumps the version internally. If you manually bump
`project.yml` before running the script, the build number gets double-incremented.
Commit your code changes first, then let the script handle versioning.

### "updated 1 existing" from generate_appcast = BAD
`generate_appcast` should say "Wrote 1 new update". If it says "updated 1
existing", the DMG's embedded version matches a prior release — meaning the
version bump didn't take effect. The appcast will point to the new DMG but
Sparkle will see the same version and tell users "no update available."

### Always Verify the DMG
Don't trust the script output alone. Mount the actual DMG and check
`CFBundleShortVersionString` via PlistBuddy. The appcast version comes from
the DMG's embedded Info.plist — if the version in the binary is wrong,
everything downstream is wrong.

### Signing Identity & Notarization
- Signing identity: `Developer ID Application: Jacob RAINS (47347VQHQV)`
- Notarization profile: `StoryFox-Notarize` (stored in Keychain)
- Both must be present in the developer's Keychain or the build fails

### Landing Page Deploys Automatically
Vercel is git-connected to main. Pushing to main triggers a deploy.
No `vercel --prod` needed. Just make sure the changelog and page.tsx
changes are committed and pushed.

## Recovery: If Something Goes Wrong

### Version bump failed (DMG has wrong version)
1. Fix `MARKETING_VERSION` in `project.yml` manually
2. Rebuild: `make dmg`
3. Regenerate appcast: `make appcast`
4. Delete the bad GitHub release: `gh release delete vX.Y.Z --yes`
5. Delete the tag: `git push origin :refs/tags/vX.Y.Z && git tag -d vX.Y.Z`
6. Re-run from Phase 4 with the corrected project.yml

### Notarization failed
Check the log: `xcrun notarytool log <submission-id> --keychain-profile StoryFox-Notarize`
Common causes: expired credentials, hardened runtime flags missing, unsigned frameworks.

### Appcast missing EdDSA signature
```bash
make sign-update DMG=dist/StoryFox.dmg
```
Copy the signature into `appcast.xml` manually, commit, and push.

### Appcast missing release notes (`<description>`)
The release script auto-generates and injects release notes, but if they're missing:
1. Create `release-notes/{version}.html` with the desired HTML content
2. Run `scripts/inject-release-notes.sh` to inject all notes into `appcast.xml`
3. Commit and push the updated `appcast.xml` and `release-notes/`

### GitHub release already exists for this tag
```bash
gh release delete vX.Y.Z --yes
git push origin :refs/tags/vX.Y.Z
git tag -d vX.Y.Z
```
Then re-run the release script.
