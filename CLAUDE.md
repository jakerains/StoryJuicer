# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## iOS Development — On Hold

The iOS target (`StoryFox-iOS`) exists in the codebase but is **not actively being developed** right now. Until iOS development resumes:

- **Do not mention iOS** in changelogs, release notes, or user-facing copy
- **Do not prioritize iOS-specific fixes** or UI changes unless explicitly asked
- **Shared code** (`Shared/`) still compiles for both platforms, so avoid breaking the iOS build, but don't spend time on iOS-only polish
- The macOS target is the sole focus for features, releases, and testing

## Build System

This project uses **XcodeGen** (`project.yml`) to generate `StoryFox.xcodeproj`. The Xcode project file is not checked in — it's generated.

```bash
# Regenerate the Xcode project (required after adding/moving/renaming Swift files)
xcodegen generate

# Build from command line
xcodebuild -project StoryFox.xcodeproj -scheme StoryFox -destination 'platform=macOS' build

# Build and run (uses scripts/build.sh + scripts/run.sh)
make run

# Build a signed, notarized DMG for distribution
make dmg
```

**Important:** XcodeGen overwrites `Resources/StoryFox.entitlements` on each run. If the entitlements file has custom sandbox permissions, back it up before regenerating and restore after.

There are no tests, no linter, and no package dependencies beyond Apple platform frameworks and the HuggingFace Swift SDK.

## What This App Does

StoryFox generates illustrated children's storybooks using a combination of on-device and cloud AI. The user enters a story concept, picks page count/format/style, and the app produces a complete storybook with text and illustrations.

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
StoryFoxApp.swift                 ← App entry + MainView (NavigationSplitView routing)
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
                                    StoryJuicerTypography, ReportIssueSheet, SafetyInfoSheet
  Utilities/
    ModelSelectionStore.swift     ← Persists ModelSelectionSettings to JSON file
    CloudCredentialStore.swift    ← Keychain storage for API keys + OAuth tokens
    HFTokenStore.swift           ← Keychain storage for Hugging Face tokens
    HuggingFaceOAuth.swift       ← OAuth device flow for Hugging Face login
    CloudModelListCache.swift    ← Caches available model lists from cloud providers
    GenerationDiagnosticsLogger  ← Structured logging for generation pipeline
    IssueReportService.swift     ← Zip builder + uploader for missing-image reports
    ContentSafetyPolicy.swift    ← Content safety guardrails
    GenerationOptions+Defaults   ← Default generation config values
    DiffusersRuntimeManager.swift ← Local Diffusers model management (hidden)
    PlatformImage.swift          ← Cross-platform image typealias
macOS/
  Views/
    MacCreationView.swift        ← Story creation: hero image, gradient title, concept input, book setup popover
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

### Post-Release Verification (IMPORTANT)

**ALWAYS verify after every release.** The release script has historically failed silently (see "BSD sed" note below), shipping DMGs with stale versions. After `release.sh` finishes, run these checks before walking away:

```bash
# 1. Mount the DMG and verify the embedded version matches what you released
hdiutil attach dist/StoryFox.dmg -nobrowse -quiet
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "/Volumes/StoryFox/StoryFox.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "/Volumes/StoryFox/StoryFox.app/Contents/Info.plist"
hdiutil detach "/Volumes/StoryFox" -quiet

# 2. Verify the live appcast advertises the new version
curl -s "https://raw.githubusercontent.com/jakerains/StoryFox/main/appcast.xml" | grep -A4 '<item>' | head -5

# 3. Verify generate_appcast said "Wrote 1 new update" (NOT "updated 1 existing")
```

If the DMG version is wrong or the appcast still shows the old version, the version bump didn't take effect. Fix `project.yml` manually, rebuild with `make dmg`, regenerate appcast, and re-upload.

**BSD sed pitfall:** macOS ships BSD sed, which does NOT support GNU sed's `0,/pattern/` address syntax. Commands using `0,` fail silently — no error, no change. The release script now uses `awk` for first-occurrence replacement and includes a post-bump verification step. If you ever need to do first-occurrence replacement in a shell script on macOS, use `awk` instead of `sed`.

### Every Commit That Changes App Behavior

**IMPORTANT:** Any commit that adds features, fixes bugs, or changes user-facing behavior MUST include these steps. Do NOT defer — do them all before considering the work "done."

1. **Bump the patch version** in `project.yml` → `MARKETING_VERSION` (e.g., `1.1.0` → `1.1.1`) and increment `CURRENT_PROJECT_VERSION`
2. **Update `landing/lib/changelog.ts`** — add or update the entry for the new version with a description of what changed (tagged as `added`, `fixed`, `changed`, or `removed`)
3. **Update `softwareVersion`** in `landing/app/page.tsx` structured data to match the new version
4. **Build and release the new version** — run `./scripts/release.sh <version>` to build the DMG, generate the appcast, create the GitHub release, and push. **Bumping the version in `project.yml` alone does NOT make it available to users.** The appcast only updates when a new DMG is built and `generate_appcast` runs against it. Without this step, Sparkle will say "no update available."
5. **Verify the release** — follow the Post-Release Verification steps above. Do NOT skip this.
6. **Landing page deploys automatically** — Vercel is git-connected, so pushing to main triggers a deploy. No manual `vercel --prod` needed.

**Why step 4 matters:** Sparkle compares the installed app's version against `appcast.xml` on GitHub. If you bump `project.yml` but don't rebuild the DMG and regenerate the appcast, the appcast still advertises the old version and users see "no update." The release script handles everything atomically.

**Manual release steps** (if not using the script):
1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` (macOS target only — iOS version is independent)
2. `make dmg` — build, sign, notarize, package
3. **Verify DMG version** — mount the DMG and check `CFBundleShortVersionString` matches (see verification steps above)
4. `make appcast` — regenerate `appcast.xml` with EdDSA signatures
5. If appcast is missing `sparkle:edSignature`, run `make sign-update DMG=dist/StoryFox.dmg` and add it manually
6. `gh release create v<version> dist/StoryFox.dmg` — upload to GitHub Releases
7. Commit `project.yml`, `appcast.xml`, and `project.pbxproj`, then push to main

### Auto-Update (Sparkle 2)

StoryFox uses [Sparkle 2](https://sparkle-project.org/) for auto-updates (macOS only, not iOS).

**Key files:**
- `macOS/SoftwareUpdateManager.swift` — `@Observable` wrapper around `SPUStandardUpdaterController`
- `Resources/StoryFox-Info.plist` — contains `SUPublicEDKey` (Ed25519 public key for signature verification)
- `appcast.xml` — RSS feed at repo root listing available versions with download URLs and EdDSA signatures

**Architecture:**
- Feed URL is set programmatically via `SPUUpdaterDelegate.feedURLString(for:)` in `SoftwareUpdateManager` (XcodeGen can't inject custom Info.plist keys via `INFOPLIST_KEY_` — that only works for Apple-registered keys)
- Public key MUST be in Info.plist (not programmatic — Sparkle enforces this for security). We use `INFOPLIST_FILE: Resources/StoryFox-Info.plist` as a template, and Xcode merges it with auto-generated keys since `GENERATE_INFOPLIST_FILE: YES`
- EdDSA private key is stored in the developer's macOS Keychain (created by `make sparkle-setup`)
- Appcast is hosted at `https://raw.githubusercontent.com/jakerains/StoryFox/main/appcast.xml`
- DMGs are hosted as GitHub Release assets

**Important:** Do NOT delete `Resources/StoryFox-Info.plist` — it carries the `SUPublicEDKey`. Without it, update signature validation fails.

### DMG Build (`make dmg`)
Produces a signed, notarized DMG at `dist/StoryFox.dmg`. Pipeline:
1. `xcodegen generate` — regenerate project
2. Restore entitlements (XcodeGen overwrites them)
3. `xcodebuild archive` — Release archive with Developer ID signing
4. `xcodebuild -exportArchive` — export signed `.app`
5. `xcrun notarytool submit` — notarize with Apple
6. `xcrun stapler staple` — staple notarization ticket
7. `hdiutil create` — package into DMG, notarize + staple the DMG itself

**Signing identity:** `Developer ID Application: Jacob RAINS (47347VQHQV)`
**Notarization profile:** `StoryFox-Notarize` (stored in Keychain via `xcrun notarytool store-credentials`)

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

**AccentColor** is set to `sjCoral` in `Resources/Assets.xcassets/AccentColor.colorset` (light: `#B4543A`, dark: `#D98A73`). This controls system-level accent colors like focus rings, toggles, and default buttons. However, it does **NOT** control macOS sidebar List selection highlights — see macOS Sidebar Gotchas below.

## UI Components

Glass-morphism design system defined in `SettingsPanelStyle.swift`:
- `SettingsPanelCard` — frosted glass card container
- `SettingsSectionHeader` — title + subtitle + icon header
- `SettingsControlRow` — label + control layout
- `.settingsFieldChrome()` modifier — consistent field styling
- `.glass` / `.glassProminent` button styles
- `StoryJuicerGlassTokens` — spacing, radius, tint constants
- `StoryJuicerTypography` — font presets for settings UI

Glass chip modifier in `View+StoryJuicerGlass.swift`:
- `.sjGlassCard(tint:interactive:cornerRadius:)` — glass effect card
- `.sjGlassChip(selected:interactive:)` — compact pill/chip styling
- `.sjGlassToolbarItem(prominent:)` — toolbar button styling

## Creation View Design (`MacCreationView.swift`)

The creation screen uses an **open, cardless layout** — no glass card containers around the main content. Typography and spacing establish visual hierarchy.

**Layout (top to bottom):**
1. **Hero image** — `StoryFoxHero` asset (fox on open book illustration), centered, 220pt max height, 85% opacity, animated entrance
2. **Title** — `"What story shall we create?"` in `sectionHero` (34pt bold serif) with coral→gold gradient text. Two small breathing sparkle SF Symbol accents on corners.
3. **TextEditor** — Sits directly on the gradient background with field chrome (rounded rect + border). No enclosing card, no label.
4. **Controls row** — `CreationModeToggle` (Quick/Guided pills) on the left, book setup chip on the right, same line.
5. **Book setup chip** — Content-hugging pill with wand icon + summary text (`"8 pages · Standard Square · Illustration"`). Opens a **popover** (420pt wide) with full settings: page count stepper, format grid, style picker.
6. **Squeeze button** — Full-width primary CTA.
7. **Q&A flow** — Appears between controls row and squeeze button when guided mode is active.

**Key implementation details:**
- Use `.contentShape(Rectangle())` on buttons with `.buttonStyle(.plain)` to ensure full-area tappability
- The book setup chip uses `.fixedSize()` to hug content rather than stretching
- Hero image uses `Image("StoryFoxHero")` from the asset catalog (`Resources/Assets.xcassets/StoryFoxHero.imageset/`)
- **Do NOT use GeometryReader** for decorative overlays on the title — it causes layout instability and makes the text slide around
- **Do NOT use animated gradient stops** (shimmer) on the title text — SwiftUI re-lays out the text during animation, causing visible jitter

## Hero Image (`StoryFoxHero`)

The fox-on-book hero illustration is stored at `Resources/Assets.xcassets/StoryFoxHero.imageset/storyfox-hero.png`. It's used in two places:
1. **Creation screen** — centered above the title, decorative
2. **About panel** — replaces the standard app icon in `StoryFoxApp.swift`'s `aboutPanelOptions`

## Sidebar

The sidebar in `MainView` (in `StoryFoxApp.swift`) has **no header** — the "New Story" button is the first element. The StoryFox name/icon was removed to keep it clean.

**Selection highlight fix:** macOS sidebar `List` selection uses the user's system accent color (typically blue). `.tint()`, `.accentColor()`, and even the AccentColor asset catalog entry do NOT override this. The fix is to use `.listRowBackground()` with an **opaque** background that paints over the system highlight. We use `sidebarRowBackground` (a `LinearGradient` matching the sidebar background) so the system blue is never visible. The rows' own `.sjGlassCard()` styling with coral tint provides the selection state feedback.

## macOS UI Gotchas

- **System blue selection:** `.tint()` and `.accentColor()` on a `List` do NOT change the sidebar selection highlight on macOS. The system draws it via AppKit using `NSColor.controlAccentColor`. Use opaque `.listRowBackground()` to cover it.
- **`.buttonStyle(.plain)` hit targets:** On macOS, plain buttons only respond to clicks on visible content (text, icons), not transparent areas like `Spacer`. Add `.contentShape(Rectangle())` before glass modifiers to make the full area tappable.
- **AccentColor in asset catalog:** Controls focus rings, toggles, and some system chrome, but NOT sidebar List selection. Still worth setting to `sjCoral` for consistency across other UI elements.
- **Toolbar button glass styles ignored:** On macOS 26, `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` are overridden by the system for `Button` inside `ToolbarItemGroup`. The system applies its own toolbar button chrome (coral-filled pills). `Menu` is unaffected and renders `.glassProminent` correctly. **Fix:** Use `.buttonStyle(.plain)` on the `Button` and apply `.glassEffect(.regular, in: .capsule)` directly on the label's `Image`. This gives a uniform dark glass capsule matching the `Menu` appearance. See the `toolbarButton()` helper in `MacBookReaderView.swift`.

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

# Deploy to Vercel (git-connected — auto-deploys on push to main)
# No manual deploy needed
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

## Neon Database

**Project:** `shiny-brook-55652171` (name: `neon-green-pocket`)
**Branch:** `main` (ID: `br-broad-truth-aiagt0cl`)
**Database:** `neondb`
**Connection:** `DATABASE_URL` env var (pooled connection string via `@neondatabase/serverless`)

### Environment Variables

- **Local dev:** Root `.env.local` contains all Neon/Postgres vars (created by Vercel CLI). The `landing/` directory symlinks to it (`landing/.env.local → ../.env.local`). Both are gitignored.
- **Production:** Vercel injects `DATABASE_URL` automatically (Project Settings → Environment Variables).

### Driver

Uses `@neondatabase/serverless` — the `neon()` HTTP query function (tagged template literals for parameterized queries). No connection pool, no `pg` native bindings. Ideal for Vercel serverless/edge.

### Tables

**`public.feedback`** — Visitor feedback submitted from the landing page modal

| Column | Type | Notes |
|--------|------|-------|
| `id` | `SERIAL PRIMARY KEY` | Auto-increment |
| `category` | `TEXT NOT NULL` | One of: `suggestion`, `bug`, `complaint`, `other` (default: `suggestion`) |
| `message` | `TEXT NOT NULL` | Feedback body (max 2000 chars, enforced by API route) |
| `email` | `TEXT` | Optional contact email for follow-up |
| `created_at` | `TIMESTAMPTZ NOT NULL` | Auto-set to `now()` |

Indexes: `idx_feedback_created_at` (DESC), `idx_feedback_category`

**`public.storybook_reports`** — Issue reports for storybooks with missing illustrations

| Column | Type | Notes |
|--------|------|-------|
| `id` | `UUID PRIMARY KEY` | Auto-generated via `gen_random_uuid()` |
| `created_at` | `TIMESTAMPTZ NOT NULL` | Auto-set to `now()` |
| `book_title` | `TEXT NOT NULL` | Story title |
| `page_count` | `INT NOT NULL` | Number of story pages |
| `missing_indices` | `INT[] NOT NULL` | Postgres array of page indices missing images |
| `format` | `TEXT NOT NULL` | `BookFormat.rawValue` (e.g., `standard`, `landscape`) |
| `style` | `TEXT NOT NULL` | `IllustrationStyle.rawValue` (e.g., `illustration`, `animation`) |
| `text_provider` | `TEXT NOT NULL` | `StoryTextProvider.rawValue` |
| `image_provider` | `TEXT NOT NULL` | `StoryImageProvider.rawValue` |
| `user_notes` | `TEXT` | Optional free-text from the user |
| `blob_url` | `TEXT NOT NULL` | Vercel Blob URL to the report zip |
| `blob_size_bytes` | `INT NOT NULL` | Size of the uploaded zip |
| `status` | `TEXT NOT NULL` | Triage status: `new` (default), `reviewing`, `resolved`, `wont_fix` |
| `app_version` | `TEXT NOT NULL` | App version at time of report |
| `os_version` | `TEXT` | macOS version string |
| `device_model` | `TEXT` | Hardware model identifier |

Indexes: `idx_reports_status`, `idx_reports_created` (DESC)

### Vercel Blob

Used to store report zip files uploaded from the macOS app. Each zip contains `story.json`, `images/*.jpg`, and `diagnostics.jsonl`.

- **Package:** `@vercel/blob` (installed in `landing/`)
- **Store:** Must be connected in Vercel dashboard (Storage → Create → Blob) — auto-provisions `BLOB_READ_WRITE_TOKEN`
- **Naming:** `reports/{ISO-timestamp}-{short-uuid}.zip`
- **Access:** `public` (reports contain story text + illustrations, not sensitive data)
- **Size limit:** 5 MB per zip (enforced by API route)

### API Routes

- **`POST /api/feedback`** (`landing/app/api/feedback/route.ts`) — Validates and inserts a feedback row. Body: `{ category, message, email? }`. Returns `{ success: true }` or `{ error: "..." }` with status codes 400/500.
- **`POST /api/reports`** (`landing/app/api/reports/route.ts`) — Receives multipart form data with `metadata` (JSON) and `report` (zip). Uploads zip to Vercel Blob, inserts metadata into `storybook_reports`. Rate-limited to one report per IP per 5 minutes. Returns `{ success: true }` or `{ error: "..." }` with status codes 400/429/500.

### Feedback UI

The feedback form is a **modal** (`landing/components/FeedbackModal.tsx`), not an inline page section. It's triggered by a "Share Feedback" pill button in the **Footer** (`landing/components/Footer.tsx`), positioned after the Changelog chip. The modal has category pills (Suggestion, Bug Report, Complaint, Other), a message textarea, an optional email field, and shows a success/error state after submission.

### Issue Reports (macOS App)

When Image Playground fails to generate all illustrations (common with Apple's safety filters), a "Report Issue" button appears in the reader toolbar. The button is **only visible when images are missing** (`viewModel.missingImageIndices.isEmpty == false`).

**Flow:** User clicks "Report Issue" → confirm sheet (`ReportIssueSheet`) shows what will be sent → user optionally adds notes → submit → `IssueReportService` builds a zip (story.json + images/ + diagnostics.jsonl), uploads it to Vercel Blob via `POST /api/reports`, and metadata is stored in `storybook_reports`.

**Key files:**
- `Shared/Utilities/IssueReportService.swift` — `buildReportZip()` (NSFileCoordinator zip) + `submitReport()` (multipart upload)
- `Shared/Views/Components/ReportIssueSheet.swift` — Confirm sheet UI
- `macOS/Views/MacBookReaderView.swift` — Toolbar button + `.reportIssue` sheet case

### Querying Data

To read submitted feedback or reports, use the Neon MCP tools or direct SQL:

```sql
-- All feedback, newest first
SELECT * FROM public.feedback ORDER BY created_at DESC;

-- Filter by category
SELECT * FROM public.feedback WHERE category = 'bug' ORDER BY created_at DESC;

-- Count by category
SELECT category, COUNT(*) FROM public.feedback GROUP BY category;

-- All storybook reports, newest first
SELECT id, book_title, missing_indices, status, created_at FROM public.storybook_reports ORDER BY created_at DESC;

-- Reports by status
SELECT * FROM public.storybook_reports WHERE status = 'new' ORDER BY created_at DESC;

-- Find common missing-image patterns
SELECT missing_indices, COUNT(*) as occurrences FROM public.storybook_reports GROUP BY missing_indices ORDER BY occurrences DESC;
```

There is **no admin UI or dashboard** for reading feedback or reports yet. Data lives in `public.feedback` and `public.storybook_reports` on the `neondb` database in Neon project `shiny-brook-55652171`.

## Model Names

Never change model names during debugging. If a model name is unfamiliar, assume it is valid.

## Test Harness Workflow

The test harness (`Debug > Test Character Harness`, Cmd+Shift+T) has a **Copy Results** button that exports all test data as JSON for pasting into a Claude conversation. This enables an iterative debugging loop:

**Workflow:** Run tests → Copy Results → Paste into Claude → Analyze → Fix code → Repeat

### Interpreting Pasted JSON

The export has four top-level sections:

**`metadata`** — Test context: concept, expected species, text provider, app version, timestamp.

**`llmTest`** (always present) — Character consistency evaluation of the LLM-generated story.
- `scores`: Five metrics from 0.0–1.0:
  - `overall` — Weighted average (species 35%, appearance 25%, description 20%, name 20%)
  - `characterDescription` — Does `characterDescriptions` field contain species + visual detail?
  - `speciesInPrompts` — Fraction of enriched imagePrompts containing the expected species word
  - `appearanceInPrompts` — Fraction containing appearance keywords from characterDescriptions
  - `nameConsistency` — Fraction mentioning the character by name
- `verdict`: `"pass"` (≥0.75), `"marginal"` (≥0.50), `"fail"` (<0.50)
- `characterDescriptions`: Raw LLM output — check for correct "Name - species, details" format
- `pages[]`: Per-page raw vs enriched imagePrompts with boolean checks

**`promptTest`** (null if not run) — Variant fallback chain inspection.
- Each page shows the original prompt, enriched prompt, and all fallback variants
- `variants[]`: Each has `label` (sanitized → llmRewritten → shortened → highReliability → fallback → ultraSafe), full `text`, `charCount`, and `exceedsLimit` flag
- Watch for: all variants exceeding the limit (means even ultraSafe is too long), early variants with `exceedsLimit: true` (character descriptions may be too verbose)

**`imageTest`** (null if not run) — Image generation pipeline results.
- `successCount`/`totalCount` — How many images ImagePlayground successfully generated
- `totalDurationSeconds` — Wall-clock time for the full image batch
- `variantWins` — Which fallback variant succeeded for each image. Ideal: most wins at `"sanitized"`. If wins cluster at `"fallback"` or `"ultraSafe"`, the sanitization is too aggressive or prompts are too long

### What to Look For

| Symptom | Likely Cause | Where to Fix |
|---------|-------------|--------------|
| Low `speciesInPrompts` score | LLM not embedding species in imagePrompts | `StoryPromptTemplates` (strengthen the prompt instruction) |
| `characterDescriptions` malformed | LLM not following "Name - details" format | `StoryBook.characterDescriptions` `@Guide` description |
| Raw ≠ Enriched on many pages | Enricher is working hard (LLM prompts are weak) | `StoryPromptTemplates` or `ImagePromptEnricher` heuristics |
| All prompt variants `exceedsLimit` | Character descriptions too verbose | `ImagePromptEnricher.buildInjectionPhrase` or `ContentSafetyPolicy` limits |
| Image wins at `fallback`/`ultraSafe` | ImagePlayground rejecting detailed prompts | `IllustrationGenerator` variant chain or `ContentSafetyPolicy` sanitization |
| Low `successCount` | Apple safety filters blocking generation | Check prompts for flagged words; review `ContentSafetyPolicy` |
