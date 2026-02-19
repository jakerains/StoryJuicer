# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build System

This project uses **XcodeGen** (`project.yml`) to generate `StoryJuicer.xcodeproj`. The Xcode project file is not checked in — it's generated.

```bash
# Regenerate the Xcode project (required after adding/moving/renaming Swift files)
xcodegen generate

# Build from command line
xcodebuild -project StoryJuicer.xcodeproj -scheme StoryJuicer -destination 'platform=macOS' build

# Build and run (uses scripts/build.sh + scripts/run.sh)
make run

# Build a signed, notarized DMG for distribution
make dmg
```

**Important:** XcodeGen overwrites `Resources/StoryJuicer.entitlements` on each run. If the entitlements file has custom sandbox permissions, back it up before regenerating and restore after.

There are no tests, no linter, and no package dependencies beyond Apple platform frameworks and the HuggingFace Swift SDK.

## What This App Does

StoryJuicer generates illustrated children's storybooks using a combination of on-device and cloud AI. The user enters a story concept, picks page count/format/style, and the app produces a complete storybook with text and illustrations.

**Text generation providers:**
- Apple FoundationModels (on-device ~3B LLM) with `@Generable` structs
- MLX Swift (local open-weight models via Hugging Face)
- Hugging Face Inference API (cloud)
- *(OpenRouter and Together AI exist in code but are hidden from UI)*

**Image generation providers:**
- ImagePlayground `ImageCreator` API (on-device diffusion)
- Hugging Face Inference API (cloud, e.g. FLUX.1-schnell)
- *(Diffusers local, OpenRouter, Together AI exist in code but are hidden from UI)*

**Target:** macOS 26 (Tahoe) on Apple Silicon with Apple Intelligence enabled

## Architecture

```
StoryJuicerApp.swift              ← App entry + MainView (NavigationSplitView routing)
Shared/
  Models/                         ← StoryBook (@Generable), BookFormat, IllustrationStyle, StoredStorybook (@Model)
  Generation/
    StoryGenerator.swift          ← On-device FoundationModels text generation
    MLXStoryGenerator.swift       ← Local MLX Swift text generation
    CloudTextGenerator.swift      ← Cloud text generation (HF, OpenRouter, Together AI)
    CloudImageGenerator.swift     ← Cloud image generation (HF native inference path)
    IllustrationGenerator.swift   ← On-device ImagePlayground image generation
    ImagePlaygroundImageGenerator  ← ImagePlayground wrapper implementing StoryImageGenerating
    ImageGenerationRouter.swift   ← Routes to correct image generator based on provider settings
    OpenAICompatibleClient.swift  ← Generic HTTP client for OpenAI-compatible APIs
    CloudProviderTypes.swift      ← CloudProvider enum, URLs, defaults, error types
    GenerationProviderTypes.swift ← StoryTextProvider, StoryImageProvider enums, ModelSelectionSettings
    StoryTextGenerating.swift     ← Protocol for text generators
    StoryImageGenerating.swift    ← Protocol for image generators
    StoryDecoding.swift           ← JSON response parsing helpers
    StoryPromptTemplates.swift    ← Prompt templates for story generation
    StoryProviderAvailability.swift ← Runtime availability checks
    PDFRendering.swift            ← Protocol for PDF export
    RemoteStoryGenerator.swift    ← Unified remote text generation entry point
    DiffusersImageGenerator.swift ← Local Diffusers image generation (hidden)
  ViewModels/
    CreationViewModel.swift       ← Drives creation flow
    BookReaderViewModel.swift     ← Reader + page regeneration
  Views/Components/               ← Color+Theme, SqueezeButton, FormatPreviewCard, StylePickerItem,
                                    PageThumbnail, ErrorBanner, UnavailableOverlay, SettingsPanelStyle,
                                    StoryJuicerTypography
  Utilities/
    ModelSelectionStore.swift     ← Persists ModelSelectionSettings to JSON file
    CloudCredentialStore.swift    ← Keychain storage for API keys + OAuth tokens
    HFTokenStore.swift           ← Keychain storage for Hugging Face tokens
    HuggingFaceOAuth.swift       ← OAuth device flow for Hugging Face login
    CloudModelListCache.swift    ← Caches available model lists from cloud providers
    GenerationDiagnosticsLogger  ← Structured logging for generation pipeline
    ContentSafetyPolicy.swift    ← Content safety guardrails
    GenerationOptions+Defaults   ← Default generation config values
    DiffusersRuntimeManager.swift ← Local Diffusers model management (hidden)
    PlatformImage.swift          ← Cross-platform image typealias
macOS/
  Views/
    MacCreationView.swift        ← Story concept input, format/style pickers
    MacGenerationProgressView    ← Streaming text, image progress grid
    MacBookReaderView.swift      ← Page-by-page reader with overview grid
    MacExportView.swift          ← PDF/image export
    MacModelSettingsView.swift   ← Model & provider settings panel (On-Device → Cloud → Local Models)
  SoftwareUpdateManager.swift    ← Sparkle auto-update wrapper (@Observable)
  PDFRenderer+macOS.swift        ← Core Graphics PDF rendering at 300 DPI
landing/                          ← Next.js 15 landing page (Vercel)
  app/                           ← layout.tsx, page.tsx, globals.css
  components/                    ← Hero, Features, HuggingFaceSection, StylesShowcase, etc.
  lib/                           ← motion.ts (animation variants), utils.ts
  public/images/                 ← AI-generated illustration style samples
```

### Navigation Flow

`MainView` uses a `NavigationSplitView` with sidebar (saved books) + detail area. The `route` state (`AppRoute` enum) drives which detail view is shown:

1. `.creation` → `MacCreationView` (story concept input, format/style pickers)
2. `.generating` → `MacGenerationProgressView` (streaming text, image progress grid)
3. `.reading` → `MacBookReaderView` (page-by-page reader with page overview grid)

### Generation Pipeline

Sequential: text must complete before images begin (LLM generates the image prompts).

1. `CreationViewModel.squeezeStory()` kicks off the pipeline
2. Text generator (routed by `StoryTextProvider`) streams a `StoryBook` struct
3. Image generator (routed by `StoryImageProvider`) generates images concurrently (capped at `GenerationConfig.maxConcurrentImages`)
4. On completion, a `BookReaderViewModel` is created and route switches to `.reading`
5. Book is persisted to SwiftData via `StoredStorybook`

### Key Patterns

- **`@Observable` + `@MainActor`** on all ViewModels and generators (not `ObservableObject`)
- **`@Generable` + `@Guide`** macros on `StoryBook`/`StoryPage` for structured LLM output — no JSON parsing needed
- **`GenerationPhase`** is `Equatable` (stores errors as `String`, not `Error`) so SwiftUI `.onChange` works
- **`@Bindable`** in child views (not `@ObservedObject`) since we use `@Observable`
- **Images stored as `[Int: CGImage]`** where key 0 = cover, keys 1...N = story pages by `pageNumber`
- **Dual-path cloud architecture:** HuggingFace uses native inference endpoints; OpenRouter/Together AI share `OpenAICompatibleClient`

## Cloud Provider Architecture

### Authentication
- `CloudCredentialStore.bearerToken(for:)` checks for an API key first, then falls back to an OAuth access token
- HuggingFace supports both direct API tokens and OAuth device flow login (`HuggingFaceOAuth`)
- Tokens are stored in macOS Keychain via `HFTokenStore` and `CloudCredentialStore`

### HuggingFace API Paths (IMPORTANT)

**Text (works via OpenAI-compatible layer):**
- Endpoint: `https://router.huggingface.co/v1/chat/completions`
- Uses standard OpenAI chat completion format
- Both `InferenceClient` SDK and `OpenAICompatibleClient` work

**Images (MUST use native HF Inference endpoint):**
- Working endpoint: `POST https://router.huggingface.co/hf-inference/models/{model_id}`
- Request body: `{"inputs": "prompt text", "parameters": {"width": 1024, "height": 1024}}`
- Response: raw image bytes (JPEG) — decode with `CGImageSourceCreateWithData`
- **DO NOT use** the HF Swift SDK's `textToImage()` — it posts to `/v1/images/generations` which returns 404 on `router.huggingface.co`. This is a known SDK bug.
- **DO NOT use** `api-inference.huggingface.co` — it returns 410 (deprecated)

### Hidden Providers
OpenRouter and Together AI are fully implemented in code but **hidden from the UI** in `MacModelSettingsView.swift` via `.filter { $0 != .openRouter && $0 != .togetherAI }` on the provider pickers. The "More Providers" section in settings is commented out. To re-enable, remove those filters and uncomment the section.

### Settings Test Buttons
`CloudProviderSettingsSection` has three test buttons per provider:
- **Test Connection** — fetches model list to verify API key
- **Test Text Model** — sends a real prompt and shows a response snippet
- **Test Image Model** — sends a real prompt and shows image dimensions
Error messages use `.textSelection(.enabled)` so users can copy them.

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

## Distribution

### Releasing a New Version

Use the release script for the full automated pipeline:

```bash
# Release with default notes
./scripts/release.sh 1.1.0

# Release with custom notes
./scripts/release.sh 1.0.3 --notes "Fixed a bug with PDF export"
```

The script handles everything: version bump → `make dmg` → appcast generation → GitHub release → commit → push. Users on older versions are prompted automatically via Sparkle.

### Every Commit That Changes App Behavior

**IMPORTANT:** Any commit that adds features, fixes bugs, or changes user-facing behavior MUST include:

1. **Bump the patch version** in `project.yml` → `MARKETING_VERSION` (e.g., `1.1.0` → `1.1.1`) and increment `CURRENT_PROJECT_VERSION`
2. **Update `landing/lib/changelog.ts`** — add or update the entry for the new version with a description of what changed (tagged as `added`, `fixed`, `changed`, or `removed`)
3. **Update `softwareVersion`** in `landing/app/page.tsx` structured data to match the new version

This keeps the changelog, landing page, and app binary in sync. Do NOT defer these — do them in the same commit as the feature/fix.

**Manual release steps** (if not using the script):
1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` (macOS target only — iOS version is independent)
2. `make dmg` — build, sign, notarize, package
3. `make appcast` — regenerate `appcast.xml` with EdDSA signatures
4. If appcast is missing `sparkle:edSignature`, run `make sign-update DMG=dist/StoryJuicer.dmg` and add it manually
5. `gh release create v<version> dist/StoryJuicer.dmg` — upload to GitHub Releases
6. Commit `project.yml`, `appcast.xml`, and `project.pbxproj`, then push to main

### Auto-Update (Sparkle 2)

StoryJuicer uses [Sparkle 2](https://sparkle-project.org/) for auto-updates (macOS only, not iOS).

**Key files:**
- `macOS/SoftwareUpdateManager.swift` — `@Observable` wrapper around `SPUStandardUpdaterController`
- `Resources/StoryJuicer-Info.plist` — contains `SUPublicEDKey` (Ed25519 public key for signature verification)
- `appcast.xml` — RSS feed at repo root listing available versions with download URLs and EdDSA signatures

**Architecture:**
- Feed URL is set programmatically via `SPUUpdaterDelegate.feedURLString(for:)` in `SoftwareUpdateManager` (XcodeGen can't inject custom Info.plist keys via `INFOPLIST_KEY_` — that only works for Apple-registered keys)
- Public key MUST be in Info.plist (not programmatic — Sparkle enforces this for security). We use `INFOPLIST_FILE: Resources/StoryJuicer-Info.plist` as a template, and Xcode merges it with auto-generated keys since `GENERATE_INFOPLIST_FILE: YES`
- EdDSA private key is stored in the developer's macOS Keychain (created by `make sparkle-setup`)
- Appcast is hosted at `https://raw.githubusercontent.com/jakerains/StoryJuicer/main/appcast.xml`
- DMGs are hosted as GitHub Release assets

**Important:** Do NOT delete `Resources/StoryJuicer-Info.plist` — it carries the `SUPublicEDKey`. Without it, update signature validation fails.

### DMG Build (`make dmg`)
Produces a signed, notarized DMG at `dist/StoryJuicer.dmg`. Pipeline:
1. `xcodegen generate` — regenerate project
2. Restore entitlements (XcodeGen overwrites them)
3. `xcodebuild archive` — Release archive with Developer ID signing
4. `xcodebuild -exportArchive` — export signed `.app`
5. `xcrun notarytool submit` — notarize with Apple
6. `xcrun stapler staple` — staple notarization ticket
7. `hdiutil create` — package into DMG, notarize + staple the DMG itself

**Signing identity:** `Developer ID Application: Jacob RAINS (47347VQHQV)`
**Notarization profile:** `StoryJuicer-Notarize` (stored in Keychain via `xcrun notarytool store-credentials`)

### Makefile Targets
- `make help` — list all targets
- `make doctor` — check toolchain readiness
- `make build` / `make run` — Debug build
- `make build-release` / `make run-release` — Release build
- `make dmg` — full distribution pipeline
- `make clean` — clean Xcode build artifacts
- `make purge-image-cache` — remove local Diffusers model cache
- `make sparkle-setup` — one-time EdDSA key pair generation
- `make appcast` — regenerate `appcast.xml` from DMGs in `dist/`
- `make sign-update DMG=<path>` — print EdDSA signature for a DMG

## Theme Colors

All custom colors are defined as `Color.sj*` extensions in `Color+Theme.swift` ("Warm Library at Dusk" palette). Primary accent is `sjCoral` (terracotta). Use these consistently — don't introduce new color literals.

## UI Components

Glass-morphism design system defined in `SettingsPanelStyle.swift`:
- `SettingsPanelCard` — frosted glass card container
- `SettingsSectionHeader` — title + subtitle + icon header
- `SettingsControlRow` — label + control layout
- `.settingsFieldChrome()` modifier — consistent field styling
- `.glass` / `.glassProminent` button styles
- `StoryJuicerGlassTokens` — spacing, radius, tint constants
- `StoryJuicerTypography` — font presets for settings UI

## Settings Layout Order

Settings sections are ordered for a consumer-friendly flow:

1. **On-Device** — Foundation Models (built-in, works immediately)
2. **Cloud Providers** — HuggingFace callout banner + `CloudProviderSettingsSection` (free upgrade path)
3. **Local Models** — MLX Swift (power-user feature, requires downloading model weights)

The HuggingFace sign-in button uses a custom badge-style view matching the [official HF badge](https://huggingface.co/datasets/huggingface/badges#sign-in-with-hugging-face) — yellow (#FFD21E) background with 🤗 emoji. The actual OAuth button code is in `CloudProviderSettingsSection.swift` in the `oauthRow` computed property.

## Landing Page

**Location:** `landing/` subdirectory (Next.js 15 + Tailwind CSS v4 + Framer Motion)

```bash
# Dev server
cd landing && npm run dev

# Deploy to Vercel (manual, not git-connected)
cd landing && vercel --prod
```

**Design system mirrors the native app:**
- CSS variables in `globals.css` map 1:1 to `Color+Theme.swift` tokens (light/dark)
- `GlassCard.tsx` replicates `SettingsPanelCard` from SwiftUI
- Typography: Playfair Display (serif headlines) + Nunito (rounded sans body)
- Animation variants in `lib/motion.ts` match `StoryJuicerMotion` timing

**Key sections:**
- Hero with fanned storybook illustration showcase (3 AI-generated samples)
- How It Works (4-step flow), Features (8-card grid)
- HuggingFace upgrade section (explains free cloud AI, links to huggingface.co/join)
- Illustration Styles showcase, Book Formats, Requirements, Footer

**Important notes:**
- Copy is consumer-focused — no developer jargon, no "shared codebase", no "Sparkle framework"
- GitHub link is in the footer only, not prominent
- Download button is OS-aware (macOS → DMG, other → GitHub)
- Vercel root directory must be set to `landing` in project settings
- Generated illustration samples are in `landing/public/images/`

## Model Names

Never change model names during debugging. If a model name is unfamiliar, assume it is valid.
