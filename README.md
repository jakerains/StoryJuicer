<p align="center">
  <img src=".github/app-icon.png" width="128" height="128" alt="StoryFox app icon" />
</p>

<h1 align="center">StoryFox</h1>

<p align="center">
  <strong>AI-powered illustrated children's storybooks — on your device.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.3.1-D4654A" alt="Version" />
  <img src="https://img.shields.io/badge/platform-macOS%2026%20%7C%20iOS%2026-blue" alt="Platform" />
  <img src="https://img.shields.io/badge/swift-6.2-F05138" alt="Swift" />
  <img src="https://img.shields.io/badge/Apple%20Intelligence-required-black?logo=apple" alt="Apple Intelligence" />
</p>

<p align="center">
  <a href="https://github.com/jakerains/StoryFox/releases/latest/download/StoryFox.dmg">
    <img src="https://img.shields.io/badge/%E2%AC%87%EF%B8%8F_Download_for_Mac-StoryFox.dmg-D4654A?style=for-the-badge&logo=apple&logoColor=white" alt="Download for Mac" />
  </a>
</p>
<p align="center">
  <sub>Signed &amp; notarized &bull; Requires macOS 26 on Apple Silicon &bull; <a href="https://github.com/jakerains/StoryFox/releases/latest">All releases</a></sub>
</p>

---

StoryFox generates complete illustrated children's storybooks using a blend of on-device and cloud AI. Type a story idea, pick a style, and get a fully illustrated book with text, cover art, and print-ready PDF export — all in minutes.

## How It Works

```
  Your idea          AI text generation         AI image generation        Finished book
 +-----------+      +------------------+      +-----------------------+   +-------------+
 | "A brave  | ---> | FoundationModels | ---> | ImagePlayground       |   |  Title page |
 |  little   |      | MLX Swift        |      | Hugging Face FLUX     |   |  10 pages   |
 |  robot"   |      | Hugging Face     |      |                       |-->|  Cover art  |
 +-----------+      +------------------+      +-----------------------+   |  PDF export |
                                                                         +-------------+
```

1. **Describe your story** — a concept, theme, or opening line
2. **Choose your settings** — page count (4-20), book format, illustration style
3. **Watch it generate** — text streams in real-time, then illustrations render concurrently
4. **Read and export** — flip through pages, then export as a 300 DPI print-ready PDF

## Features

### Text Generation
| Provider | Type | Description |
|----------|------|-------------|
| **Apple FoundationModels** | On-device | Apple's ~3B parameter LLM via `@Generable` structured output — no API key needed |
| **MLX Swift** | On-device | Run open-weight models locally (Qwen3, LFM2.5) via Hugging Face Hub |
| **Hugging Face Inference** | Cloud | Access larger cloud models through HF's inference API |

### Image Generation
| Provider | Type | Description |
|----------|------|-------------|
| **Image Playground** | On-device | Apple's built-in diffusion model — illustration, animation, and sketch styles |
| **Hugging Face Inference** | Cloud | FLUX.1-schnell and other models via HF's native inference endpoint |

### Book Formats
| Format | Size | Best For |
|--------|------|----------|
| Standard Square | 8.5" x 8.5" | Classic picture books |
| Landscape | 11" x 8.5" | Panoramic illustrations |
| Portrait | 8.5" x 11" | Tall storybooks |
| Small Square | 6" x 6" | Mini board books |

### Illustration Styles
- **Illustration** — classic children's book art with painterly details and soft shading
- **Animation** — Pixar-inspired cartoon style with rounded shapes and cinematic lighting
- **Sketch** — hand-drawn pencil lines with gentle watercolor fill

### Export
- 300 DPI print-ready PDF with embedded cover page, story pages, and end page
- macOS: Save anywhere via system file picker
- iOS: Share via system share sheet (AirDrop, Files, Print, etc.)

## Requirements

- **macOS 26** (Tahoe) or **iOS 26** on Apple Silicon
- **Apple Intelligence** enabled on your device
- **Xcode 26** with macOS 26 SDK / iOS 26 SDK (to build from source)
- **XcodeGen** — `brew install xcodegen`

Cloud features (optional):
- Hugging Face account for cloud text/image generation
- Supports both API tokens and OAuth device flow login

## Quick Start

### Download (macOS)

Grab the latest signed & notarized DMG from [Releases](https://github.com/jakerains/StoryFox/releases/latest), mount it, and drag StoryFox to Applications.

### Build from Source

```bash
# Clone
git clone https://github.com/jakerains/StoryFox.git
cd StoryFox

# Check your toolchain
make doctor

# Build and run (macOS)
make run

# Build and run (iOS Simulator)
make run-ios
```

## Make Commands

| Command | Description |
|---------|-------------|
| `make help` | List all available targets |
| `make doctor` | Check toolchain and SDK readiness |
| `make generate` | Regenerate Xcode project from `project.yml` |
| `make build` | Build Debug for macOS |
| `make run` | Build and launch Debug app (macOS) |
| `make build-release` | Build Release for macOS |
| `make run-release` | Build and launch Release app (macOS) |
| `make build-ios` | Build Debug for iOS Simulator |
| `make run-ios` | Build and launch in iOS Simulator |
| `make dmg` | Full distribution pipeline: sign, notarize, staple, package DMG |
| `make clean` | Clean Xcode build artifacts |
| `make app-path` | Print the built .app bundle path |
| `make purge-image-cache` | Remove cached Diffusers model data |

## Architecture

```
StoryFoxApp.swift                       App entry point + NavigationSplitView routing
+-- Shared/
|   +-- Models/                         StoryBook (@Generable), BookFormat, IllustrationStyle
|   +-- Generation/                     Text & image generators, PDF renderer, prompts
|   +-- ViewModels/                     CreationViewModel, BookReaderViewModel
|   +-- Views/Components/              Theme colors, glass-morphism UI, shared controls
|   +-- Utilities/                      Keychain, OAuth, settings persistence, diagnostics
+-- macOS/
|   +-- Views/                          Mac-specific creation, reader, settings, export views
|   +-- PDFRenderer+macOS.swift         Platform typealias
+-- iOS/
    +-- Views/                          iOS-specific views with responsive size class layouts
```

**~95% shared code** between macOS and iOS. Only the view layer is platform-specific.

### Key Patterns

- **`@Observable`** classes with **`@MainActor`** isolation (not `ObservableObject`)
- **`@Generable` + `@Guide`** macros for structured LLM output — no JSON parsing
- **`@Bindable`** in child views (not `@ObservedObject`)
- **Sequential pipeline**: text completes first (generates image prompts), then images render concurrently
- **Dual-path cloud**: Hugging Face uses native inference endpoints; other providers use an OpenAI-compatible client

### Navigation Flow

```
.creation  -->  .generating  -->  .reading
   |                |                 |
   |  Story idea    |  Streaming      |  Page-by-page reader
   |  Format pick   |  text + images  |  PDF export
   |  Style pick    |  Progress grid  |  Page regeneration
```

## Signing & Distribution

The `make dmg` target produces a fully signed and notarized DMG:

1. Regenerate project with XcodeGen
2. Archive with Developer ID signing + hardened runtime
3. Export signed `.app`
4. Notarize with Apple (`notarytool submit --wait`)
5. Staple notarization ticket
6. Package DMG with Applications symlink
7. Notarize and staple the DMG itself

## License

This project is not currently published under an open-source license. All rights reserved.

---

<p align="center">
  Built with SwiftUI, FoundationModels, ImagePlayground, and MLX Swift.<br/>
  <sub>macOS 26 + iOS 26 &bull; Apple Silicon</sub>
</p>
