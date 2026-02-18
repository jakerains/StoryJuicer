# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build System

This project uses **XcodeGen** (`project.yml`) to generate `StoryJuicer.xcodeproj`. The Xcode project file is not checked in — it's generated.

```bash
# Regenerate the Xcode project (required after adding/moving/renaming Swift files)
xcodegen generate

# Build from command line
xcodebuild -project StoryJuicer.xcodeproj -scheme StoryJuicer -destination 'platform=macOS' build
```

**Important:** XcodeGen overwrites `Resources/StoryJuicer.entitlements` on each run. If the entitlements file has custom sandbox permissions, back it up before regenerating and restore after.

There are no tests, no linter, and no package dependencies. The project uses only Apple platform frameworks.

## What This App Does

StoryJuicer generates illustrated children's storybooks entirely on-device using Apple AI. The user enters a story concept, picks page count/format/style, and the app produces a complete storybook with text and illustrations — no API keys, no cloud, no external dependencies.

- **Text generation:** FoundationModels framework (on-device ~3B LLM) with `@Generable` structs for typed output
- **Image generation:** ImagePlayground `ImageCreator` API (on-device diffusion model)
- **Target:** macOS 26 (Tahoe) on Apple Silicon with Apple Intelligence enabled

## Architecture

```
StoryJuicerApp.swift          ← App entry + MainView (NavigationSplitView routing)
Shared/                       ← All cross-platform code (~70% of codebase)
  Models/                     ← StoryBook (@Generable), BookFormat, IllustrationStyle, StoredStorybook (@Model)
  Generation/                 ← StoryGenerator (LLM), IllustrationGenerator (ImageCreator), PDFRendering protocol
  ViewModels/                 ← CreationViewModel (drives creation flow), BookReaderViewModel (reader + regeneration)
  Views/Components/           ← Reusable UI: Color+Theme, PageThumbnail, PageOverviewGrid, SqueezeButton, etc.
  Utilities/                  ← GenerationConfig, PlatformImage typealias
macOS/                        ← Platform-specific views and PDF renderer
  Views/                      ← MacCreationView, MacGenerationProgressView, MacBookReaderView, MacExportView
  PDFRenderer+macOS.swift     ← Core Graphics PDF rendering at 300 DPI
```

### Navigation Flow

`MainView` uses a `NavigationSplitView` with sidebar (saved books) + detail area. The `route` state (`AppRoute` enum) drives which detail view is shown:

1. `.creation` → `MacCreationView` (story concept input, format/style pickers)
2. `.generating` → `MacGenerationProgressView` (streaming text, image progress grid)
3. `.reading` → `MacBookReaderView` (page-by-page reader with page overview grid)

### Generation Pipeline

Sequential: text must complete before images begin (LLM generates the image prompts).

1. `CreationViewModel.squeezeStory()` kicks off the pipeline
2. `StoryGenerator` streams a `StoryBook` struct via `LanguageModelSession.streamResponse()`
3. `IllustrationGenerator` generates images concurrently (capped at `GenerationConfig.maxConcurrentImages`)
4. On completion, a `BookReaderViewModel` is created and route switches to `.reading`
5. Book is persisted to SwiftData via `StoredStorybook`

### Key Patterns

- **`@Observable` + `@MainActor`** on all ViewModels and generators (not `ObservableObject`)
- **`@Generable` + `@Guide`** macros on `StoryBook`/`StoryPage` for structured LLM output — no JSON parsing needed
- **`GenerationPhase`** is `Equatable` (stores errors as `String`, not `Error`) so SwiftUI `.onChange` works
- **`@Bindable`** in child views (not `@ObservedObject`) since we use `@Observable`
- **Images stored as `[Int: CGImage]`** where key 0 = cover, keys 1...N = story pages by `pageNumber`

## Apple Framework API Notes

### FoundationModels (Text)
- `streamResponse()` returns `ResponseStream<T>` — an `AsyncSequence`
- Each snapshot has `.content` (type `T.PartiallyGenerated`) — NOT `.partialResult`/`.result`
- Use `stream.collect()` to get final `Response<T>` with `.content: T`
- Snapshots are full accumulated state, not deltas

### ImagePlayground (Illustrations)
- `ImageCreator()` init is `async throws` — checks device capability
- `creator.images(for:style:limit:)` returns an `AsyncSequence` of images with `.cgImage`
- Each image takes ~15-30 seconds on-device
- Three styles: `.illustration`, `.animation`, `.sketch` — mapped via `IllustrationStyle.playgroundStyle`

## Theme Colors

All custom colors are defined as `Color.sj*` extensions in `Color+Theme.swift` ("Warm Library at Dusk" palette). Primary accent is `sjCoral` (terracotta). Use these consistently — don't introduce new color literals.

## Model Names

Never change model names during debugging. If a model name is unfamiliar, assume it is valid.
