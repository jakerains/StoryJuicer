# Repository Guidelines

## Project Structure & Module Organization
- `StoryJuicerApp.swift`: app entry point and top-level navigation (`MainView`, `AppRoute`).
- `Shared/`: cross-platform code split by concern:
  - `Shared/Models` for domain models and persistence types.
  - `Shared/Generation` for story/image/PDF generation pipeline.
  - `Shared/ViewModels` for UI state and orchestration.
  - `Shared/Views/Components` for reusable UI pieces.
  - `Shared/Utilities` for defaults and platform helpers.
- `macOS/`: platform-specific views and PDF renderer (`macOS/PDFRenderer+macOS.swift`).
- `Resources/`: assets and entitlements (`Resources/Assets.xcassets`, `Resources/StoryJuicer.entitlements`).
- `project.yml`: source of truth for project configuration; `StoryJuicer.xcodeproj` is generated.

## Build, Test, and Development Commands
- `xcodegen generate` regenerates `StoryJuicer.xcodeproj` after adding/moving/renaming files.
- `xcodebuild -project StoryJuicer.xcodeproj -scheme StoryJuicer -destination 'platform=macOS' build` performs a full CLI build.
- `open StoryJuicer.xcodeproj` launches Xcode for local development and previews.
- `xcodebuild -project StoryJuicer.xcodeproj -scheme StoryJuicer clean` clears stale artifacts when needed.

## Coding Style & Naming Conventions
- Use Swift 6 conventions with 4-space indentation and no tabs.
- Name types/protocols in UpperCamelCase (`IllustrationGenerator`), methods/properties in lowerCamelCase (`syncTextProgress()`).
- Keep one primary type per file and match filename to type name (for example, `CreationViewModel.swift`).
- For observable state, follow existing patterns: `@Observable` + `@MainActor` on view models and `@Bindable` in child views.
- Reuse palette colors from `Shared/Views/Components/Color+Theme.swift`; avoid new inline color literals.

## Testing Guidelines
- There is currently no XCTest target in this repository.
- Minimum pre-PR validation is a successful CLI build plus a manual smoke test:
  1. Generate a story.
  2. Confirm illustrations complete.
  3. Reopen a saved book.
  4. Export PDF.
- When adding tests, place them under `StoryJuicerTests/` and use `FeatureNameTests.swift` with `test_<behavior>()` naming.

## Commit & Pull Request Guidelines
- Git history is not present in this workspace snapshot, so use clear imperative commit messages with scope (example: `Handle guardrail retry in CreationViewModel`).
- Keep commits atomic and focused on one change.
- PRs should include: concise summary, linked issue/task (if any), manual validation notes, and screenshots for UI changes.

## Security & Configuration Tips
- `xcodegen generate` can overwrite `Resources/StoryJuicer.entitlements`; verify sandbox entries before committing.
- Do not commit generated artifacts from `build/` or temporary outputs in `output/`.
