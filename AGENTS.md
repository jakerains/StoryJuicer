# Repository Guidelines

## Platform Focus (Critical)
- StoryFox is currently **macOS-first**. The iOS target exists but is on hold.
- Do not mention iOS in release notes, changelogs, or user-facing copy unless explicitly asked.
- Keep shared code (`Shared/`) compatible with iOS builds, but do not spend time on iOS-only polish unless requested.

## Project Structure & Module Organization
- `StoryFoxApp.swift`: app entry and top-level routing (`MainView`, `AppRoute`).
- `Shared/`
  - `Shared/Models`: domain and persistence models (`StoryBook`, `StoredStorybook`, format/style enums).
  - `Shared/Generation`: text/image/PDF generation pipeline and provider routing.
  - `Shared/ViewModels`: app orchestration (`CreationViewModel`, `BookReaderViewModel`).
  - `Shared/Views/Components`: reusable UI and design tokens (including `Color+Theme.swift`).
  - `Shared/Utilities`: persistence, credentials, diagnostics, safety policy, defaults.
- `macOS/`: macOS-specific UI, Sparkle updater wrapper, and PDF renderer.
- `landing/`: Next.js landing site + API routes for feedback/reports.
- `release-notes/`: per-version HTML snippets for Sparkle “What’s New”.
- `scripts/`: release automation and release-note injection scripts.
- `project.yml`: source of truth for project config; `StoryFox.xcodeproj` is generated.

## Build, Test, and Development Commands
- `xcodegen generate`: regenerate `StoryFox.xcodeproj` after adding/moving/renaming files.
- `xcodebuild -project StoryFox.xcodeproj -scheme StoryFox -destination 'platform=macOS' build`: full CLI build.
- `make run`: build + run via project scripts.
- `make dmg`: signed + notarized DMG pipeline.
- `open StoryFox.xcodeproj`: open Xcode.
- `xcodebuild -project StoryFox.xcodeproj -scheme StoryFox clean` or `make clean`: clear build artifacts.

## Core Architecture Notes
- Generation flow is sequential: text generation must finish before illustration generation starts.
- Illustrations generate concurrently with cap controlled by `GenerationConfig.maxConcurrentImages`.
- Cloud providers are routed through provider enums/settings (`StoryTextProvider`, `StoryImageProvider`, `ModelSelectionSettings`).
- Hidden-but-implemented providers (`OpenRouter`, `Together AI`) remain filtered out of settings UI unless explicitly re-enabled.

## Coding Style & Conventions
- Swift 6 style, 4-space indentation, no tabs.
- UpperCamelCase for types/protocols; lowerCamelCase for methods/properties.
- One primary type per file, filename matches type (for example, `CreationViewModel.swift`).
- Observable patterns:
  - Use `@Observable` + `@MainActor` for view models/generators.
  - Use `@Bindable` in child views (not `@ObservedObject` in this architecture).
- Structured LLM output relies on `@Generable` + `@Guide`; do not replace with ad-hoc JSON parsing unless required.
- Reuse palette tokens in `Shared/Views/Components/Color+Theme.swift`; avoid inline color literals.
- Do not rename models during debugging because unfamiliar model IDs may still be valid.

## Hugging Face API Rules (Critical)
- Text generation uses OpenAI-compatible chat completions:
  - `https://router.huggingface.co/v1/chat/completions`
- Image generation must use the native HF inference route:
  - `POST https://router.huggingface.co/hf-inference/models/{model_id}`
  - Body: `{"inputs":"...","parameters":{"width":1024,"height":1024}}`
  - Response is raw image bytes.
- Do not use HF SDK `textToImage()` against `router.huggingface.co` (`/v1/images/generations` path returns 404).
- Do not use `api-inference.huggingface.co` for this app path (deprecated/410 for current flow).

## UI & Design Constraints
- Use existing StoryFox design system and theme tokens; no new ad-hoc visual language.
- Creation screen (`MacCreationView`) is intentionally open/cardless.
- Avoid `GeometryReader` for decorative title overlays there (causes layout instability).
- Avoid animated gradient-stop shimmer on title text (causes text jitter/reflow).
- macOS sidebar selection highlights require opaque row backgrounds (`listRowBackground`) to suppress system accent blue.
- On macOS, `.buttonStyle(.plain)` needs `.contentShape(Rectangle())` for full hit targets.

## Sparkle & Distribution
- Sparkle 2 is macOS-only and uses:
  - `macOS/SoftwareUpdateManager.swift`
  - `Resources/StoryFox-Info.plist` (`SUPublicEDKey` required)
  - `appcast.xml`
  - `release-notes/*.html`
  - `scripts/inject-release-notes.sh`
- Do not delete `Resources/StoryFox-Info.plist`; update verification depends on it.
- Appcast feed is served from GitHub raw URL; DMGs are GitHub Release assets.

## Release Workflow (Mandatory for User-Facing Changes)
For any commit that changes app behavior, complete all steps before considering work done:
1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`.
2. Update `landing/lib/changelog.ts` with the new version entry.
3. Update `softwareVersion` in `landing/app/page.tsx` structured data.
4. Create/update `release-notes/<version>.html` with user-facing notes.
5. Run `./scripts/release.sh <version>` (or equivalent manual release flow).
6. Verify release artifacts and appcast content post-release.
7. Push to `main` (landing page deploys automatically via Vercel integration).

### Post-Release Verification (Required)
1. Mount `dist/StoryFox.dmg` and confirm `CFBundleShortVersionString` and `CFBundleVersion` in the shipped app.
2. Confirm live `appcast.xml` advertises the new version.
3. Confirm `generate_appcast` reported a new update entry (not only rewrites).
4. Confirm release notes are injected into appcast items (`<description><![CDATA[ ... ]]>`).

## Testing Guidelines
- There is currently no XCTest target.
- Minimum validation for changes:
  1. Successful CLI build.
  2. Manual smoke test: generate story, complete illustrations, reopen saved book, export PDF.
- When adding tests, use `StoryFoxTests/FeatureNameTests.swift` and `test_<behavior>()` naming.

## Landing Site, Feedback, and Reports
- Landing app lives in `landing/` (Next.js 15, Tailwind v4, Framer Motion).
- Feedback endpoint: `POST /api/feedback`.
- Report endpoint: `POST /api/reports` (multipart zip upload + metadata; rate-limited).
- Reports are uploaded to Vercel Blob; metadata stored in Neon Postgres.
- Keep copy consumer-facing on landing pages; avoid internal implementation jargon.

## Commit & Pull Request Guidelines
- Use clear imperative commit messages with scope (for example, `Handle guardrail retry in CreationViewModel`).
- Keep commits atomic and focused.
- PRs should include summary, related issue/task, validation notes, and screenshots for UI changes.

## Security & Configuration Tips
- `xcodegen generate` can overwrite `Resources/StoryFox.entitlements`; verify sandbox entries after generation.
- Do not commit generated artifacts from `build/`, `dist/`, `output/`, or local environment files.
- Prefer keychain/env-based secret handling; never commit API keys or tokens.
