# STORYJUICER

### AI Kids' Storybook Generator

**Product Requirements Document & Coding Agent Implementation Prompt**

Native macOS App • SwiftUI • Apple Silicon
Foundation Models + Image Playground • Zero API Keys
February 2026

---

> **Key Value Proposition:** 100% on-device AI generation using Apple's Foundation Models framework (text) and ImagePlayground framework (illustrations). Free inference, complete privacy, works offline. No API keys required. Ships as a single native Mac app.

---

## 1. Executive Summary

StoryJuicer is a native macOS application that generates complete, illustrated children's storybooks using only Apple's on-device AI models. Users enter a simple story concept, choose their page count and book format, and the app produces a fully illustrated storybook with narrative text and matching artwork for every page — all without API keys, cloud services, or subscription fees.

### 1.1 Technical Foundation

- **Foundation Models framework** — Apple's ~3B parameter on-device LLM, available on macOS 26 (Tahoe). Generates structured story text via Swift's `@Generable` macro. Free, private, offline-capable.
- **ImagePlayground / ImageCreator API** — Apple's on-device diffusion model for image generation. Programmatic access via the `ImageCreator` class. Supports illustration, animation, and sketch styles. No UI sheet required.
- **Target Platform** — macOS 26+ (Tahoe) on Apple Silicon Macs with Apple Intelligence enabled.

---

## 2. Cross-Platform Architecture

StoryJuicer is built as a **multi-platform SwiftUI project** from day one. macOS is the primary development target, but the codebase is structured so the iOS version shares 60-70% of the code with minimal divergence.

### 2.1 Project Structure

```
StoryJuicer/
├── Shared/                          # 60-70% of codebase
│   ├── Models/
│   │   ├── StoryBook.swift          # @Generable structs (shared)
│   │   ├── BookFormat.swift         # Format enum & dimensions (shared)
│   │   └── StoredStorybook.swift    # SwiftData model (shared)
│   ├── Generation/
│   │   ├── StoryGenerator.swift     # LLM session & text generation
│   │   ├── IllustrationGenerator.swift  # ImageCreator pipeline
│   │   └── PDFRenderer.swift        # Protocol — platform-specific impl
│   ├── ViewModels/
│   │   ├── CreationViewModel.swift  # Drives the creation flow
│   │   └── BookReaderViewModel.swift
│   └── Utilities/
│       └── GenerationOptions+Defaults.swift
├── macOS/                           # macOS-specific
│   ├── Views/
│   │   ├── MacCreationView.swift    # NavigationSplitView layout
│   │   ├── MacBookReaderView.swift  # Arrow key navigation
│   │   └── MacExportView.swift      # NSSavePanel
│   ├── PDFRenderer+macOS.swift      # NSGraphicsContext / PDFKit
│   └── StoryJuicerApp+macOS.swift   # App entry point / menu bar
├── iOS/                             # iOS-specific
│   ├── Views/
│   │   ├── iOSCreationView.swift    # NavigationStack + Form
│   │   ├── iOSBookReaderView.swift  # TabView .page swipe
│   │   └── iOSExportView.swift      # ShareLink / UIActivity
│   ├── PDFRenderer+iOS.swift        # UIGraphicsPDFRenderer
│   ├── PhotosExporter.swift         # PHPhotoLibrary save
│   └── StoryJuicerApp+iOS.swift     # App entry point
└── Resources/
    └── Assets.xcassets
```

### 2.2 What's Shared vs. Platform-Specific

| Layer | Shared | macOS-Only | iOS-Only |
|---|---|---|---|
| Data Models (`StoryBook`, `StoryPage`, `BookFormat`) | ✅ | — | — |
| `@Generable` structs & `@Guide` annotations | ✅ | — | — |
| `LanguageModelSession` text generation pipeline | ✅ | — | — |
| `ImageCreator` illustration pipeline | ✅ | — | — |
| SwiftData persistence (`StoredStorybook`) | ✅ | — | — |
| View Models / state management | ✅ | — | — |
| Generation options & prompt engineering | ✅ | — | — |
| Navigation pattern | — | `NavigationSplitView` | `NavigationStack` + `TabView` |
| Page turning interaction | — | Arrow keys, click | Swipe gestures |
| PDF rendering | — | `PDFKit` / Core Graphics | `UIGraphicsPDFRenderer` |
| File export | — | `NSSavePanel` | `ShareLink` / `UIActivityViewController` |
| Image type bridging | — | `NSImage(cgImage:)` | `UIImage(cgImage:)` |
| Save to Photos | — | N/A | `PHPhotoLibrary` |
| Haptic feedback | — | N/A | `UIImpactFeedbackGenerator` |
| Concurrency limit (image gen) | — | 2-3 concurrent | 2 concurrent |

### 2.3 Compiler Directives

Use `#if os()` for the small number of platform divergences:

```swift
// Image type alias
#if os(macOS)
typealias PlatformImage = NSImage
extension NSImage {
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
#else
typealias PlatformImage = UIImage
#endif

// Concurrency limit
struct GenerationConfig {
    #if os(macOS)
    static let maxConcurrentImages = 3
    #else
    static let maxConcurrentImages = 2
    #endif
}
```

### 2.4 Build Strategy

1. **Start with macOS** — faster iteration on Apple Silicon Mac, easier debugging, more RAM for image generation.
2. **Keep all generation logic in `Shared/`** — models, view models, generation pipeline.
3. **Isolate platform UI** — each platform gets its own view layer under `macOS/` or `iOS/`.
4. **Enable the iOS target when macOS is solid** — most of the code just works. Build out touch-optimized layouts and iOS-specific features (haptics, Photos save).

---

## 3. Coding Agent Implementation Prompt

Copy the entire content of this section and paste it as the initial prompt to your coding agent. This is the primary build specification.

---

**CODING AGENT PROMPT — START**

Build a native macOS SwiftUI app called "StoryJuicer" targeting macOS 26
(Tahoe) that generates illustrated children's storybooks using ONLY
Apple's on-device AI frameworks. No API keys. No cloud services. No
third-party dependencies beyond Apple's platform SDKs.

IMPORTANT: Structure the project for cross-platform support from the
start. Place all models, view models, and generation logic in a Shared
group. Place macOS-specific views and platform code in a macOS group.
Use `#if os(macOS)` / `#if os(iOS)` compiler directives for the few
spots that diverge. See Section 2 (Cross-Platform Architecture) for
the full project structure.

```
═══════════════════════════════════════════════════════════════════
FRAMEWORKS
═══════════════════════════════════════════════════════════════════

1. FoundationModels - on-device ~3B LLM for story text generation
2. ImagePlayground  - ImageCreator API for illustration generation
3. SwiftUI          - entire UI
4. PDFKit           - PDF export

═══════════════════════════════════════════════════════════════════
DATA MODEL (using @Generable for structured LLM output)
═══════════════════════════════════════════════════════════════════

import FoundationModels

@Generable
struct StoryBook {
    @Guide(description: "A captivating title for this children's
        storybook")
    let title: String

    @Guide(description: "The author attribution line, e.g.
        'Written by StoryJuicer AI'")
    let authorLine: String

    @Guide(description: "A one-sentence summary of the story's
        moral or theme")
    let moral: String

    @Guide(description: "The story pages array - generate exactly
        the number of pages the user requested")
    let pages: [StoryPage]
}

@Generable
struct StoryPage {
    @Guide(description: "The page number, starting from 1")
    let pageNumber: Int

    @Guide(description: "2-4 sentences of story text for this page.
        Use simple vocabulary appropriate for children ages 3-8.
        Each page should advance the narrative. Use vivid, sensory
        language that paints a picture.")
    let text: String

    @Guide(description: "A detailed visual scene description for
        generating an illustration. Describe the setting, characters,
        their expressions, actions, colors, and mood. Write it as a
        children's book illustration prompt. Do NOT include any text
        or words in the image description.")
    let imagePrompt: String
}

═══════════════════════════════════════════════════════════════════
BOOK FORMAT OPTIONS (user-selectable)
═══════════════════════════════════════════════════════════════════

enum BookFormat: String, CaseIterable, Identifiable {
    case standard    // 8.5 x 8.5 inch square (classic picture book)
    case landscape   // 11 x 8.5 inch landscape
    case small       // 6 x 6 inch small square
    case portrait    // 8.5 x 11 inch portrait/tall

    var displayName: String { ... }
    var dimensions: CGSize { ... }  // in points (72 per inch)
    var description: String { ... } // e.g. "Classic square format"
}

═══════════════════════════════════════════════════════════════════
PAGE COUNT
═══════════════════════════════════════════════════════════════════

Let the user select page count via a Stepper or Picker:
  - Minimum: 4 pages
  - Maximum: 16 pages
  - Default: 8 pages
  - The page count should be passed into the LLM prompt so the
    model generates exactly that many StoryPage items.

═══════════════════════════════════════════════════════════════════
ILLUSTRATION STYLE (user-selectable)
═══════════════════════════════════════════════════════════════════

Map to ImagePlaygroundStyle options:
  - Illustration (.illustration) - default, best for storybooks
  - Animation (.animation) - Pixar/cartoon style
  - Sketch (.sketch) - hand-drawn pencil style

Check ImageCreator.availableStyles at runtime and only show
styles that are available on the user's device.

═══════════════════════════════════════════════════════════════════
GENERATION FLOW
═══════════════════════════════════════════════════════════════════

1. USER INPUT PHASE:
   - Text field for story concept (e.g. "a brave little fox who
     learns to share")
   - Page count stepper (4-16, default 8)
   - Book format picker (square/landscape/small/portrait)
   - Illustration style picker
   - "Squeeze a Story!" button

2. TEXT GENERATION PHASE:
   - Create a LanguageModelSession with these instructions:
     "You are an award-winning children's storybook author.
     You write engaging, age-appropriate stories for children
     ages 3-8. Your stories have clear beginnings, middles, and
     endings. Each page has vivid, simple prose that's fun to
     read aloud. You create detailed scene descriptions that
     would make beautiful illustrations. Stories should have
     a positive message or gentle moral."
   - Set temperature to ~1.2 for creative output
   - Call: session.respond(to: prompt, generating: StoryBook.self)
   - The prompt should incorporate the user's concept AND the
     requested page count, e.g.:
     "Create a [pageCount]-page children's storybook about
     [userConcept]. Generate exactly [pageCount] pages."
   - Use streaming (streamResponse) to show text as it generates

3. IMAGE GENERATION PHASE:
   - After text generation completes, generate illustrations
   - For each StoryPage, call ImageCreator:
     let creator = try await ImageCreator()
     let images = creator.images(
         for: [.text(page.imagePrompt)],
         style: selectedStyle,
         limit: 1
     )
   - Generate images concurrently using a TaskGroup for speed
     (but limit concurrency to 2-3 to avoid memory pressure)
   - Update UI progressively as each image completes

4. DISPLAY PHASE:
   - Show completed storybook in a page-turning reader view

═══════════════════════════════════════════════════════════════════
UI ARCHITECTURE
═══════════════════════════════════════════════════════════════════

Use a NavigationSplitView or tab-based layout with these views:

VIEW 1 - HOME / CREATION SCREEN:
  - App title "StoryJuicer" with a book/lemon icon
  - Large text field for story concept with placeholder text:
    "Describe your story... e.g., a curious cat who explores
     the ocean and makes friends with a dolphin"
  - Settings section with:
    * Page count stepper (4-16)
    * Book format picker with visual previews of each format
    * Illustration style picker
  - Large "Squeeze a Story!" button
  - Below: grid of previously generated storybooks (persist
    with SwiftData or save to Documents folder)

VIEW 2 - GENERATION PROGRESS:
  - Show current phase: "Writing your story..." / "Painting
    illustrations..."
  - For text generation: stream the story text as it generates
    so the user can read along
  - For image generation: show a progress grid with thumbnails
    appearing as each illustration completes
  - Show progress like "Illustrating page 3 of 8..."
  - Cancel button

VIEW 3 - BOOK READER:
  - Full book display with page-by-page navigation
  - First page: title page with book title, author line, and
    a hero illustration (generate one extra image for the cover
    using the story's theme)
  - Content pages: illustration on top (~60% of page height),
    story text below (~40%) with nice typography
  - Last page: "The End" with the story's moral
  - Navigation: left/right arrow keys, swipe gestures, or
    clickable arrows on the sides
  - Page indicator dots at the bottom
  - Toolbar with: Export PDF, Share, Back to Home

VIEW 4 - PDF EXPORT:
  - Use PDFKit or Core Graphics to render each page at the
    selected BookFormat dimensions
  - Each PDF page should contain:
    * The illustration scaled to fit the top portion
    * Story text typeset below with a readable serif or
      rounded font (e.g., Georgia, Avenir Rounded)
    * Page number at bottom
  - Title page as the first PDF page
  - "The End" page as the last
  - Present NSSavePanel for the user to choose save location
  - Include print-friendly margins (0.75 inch minimum)

═══════════════════════════════════════════════════════════════════
AVAILABILITY & ERROR HANDLING
═══════════════════════════════════════════════════════════════════

CRITICAL: Check availability before any generation.

For Foundation Models:
  - Check SystemLanguageModel.default.availability
  - Handle .available, .unavailable(reason) cases
  - If unavailable, show friendly message explaining Apple
    Intelligence must be enabled and models downloaded

For ImageCreator:
  - Wrap in do/catch for ImageCreator.Error.notSupported
  - Check availableStyles and only offer available ones
  - Use @Environment(\.supportsImagePlayground) in SwiftUI

Graceful degradation:
  - If image generation fails for a specific page, show a
    placeholder with the image prompt text
  - If text generation fails, show error with retry button
  - If a specific style isn't available, fall back to the
    first available style

═══════════════════════════════════════════════════════════════════
DATA PERSISTENCE (optional but nice to have)
═══════════════════════════════════════════════════════════════════

Save generated storybooks so users can revisit them:
  - Use SwiftData with a StoredStorybook model
  - Save story text, image data (as PNG Data), format settings
  - Display saved books in a grid on the home screen
  - Allow deleting saved books

═══════════════════════════════════════════════════════════════════
DESIGN & POLISH
═══════════════════════════════════════════════════════════════════

Visual Style:
  - Warm, inviting color palette (soft pastels, warm accents)
  - Use SF Symbols throughout (book.fill, wand.and.stars,
    paintbrush.fill, square.and.arrow.up, etc.)
  - Rounded corners, soft shadows, playful but clean aesthetic
  - The book reader should feel like holding a real picture book

Typography:
  - Story text in the reader: use a rounded or serif font
    at a large, readable size (think children's book text)
  - Consider Avenir Rounded or Georgia for story text
  - UI elements: system default (.body, .title, etc.)

Animations:
  - Page turn animation in the reader (or smooth cross-fade)
  - Illustrations fade in as they generate
  - Subtle loading animations during generation
  - Button press effects

═══════════════════════════════════════════════════════════════════
XCODE PROJECT SETUP
═══════════════════════════════════════════════════════════════════

  - Create a new Multi-Platform SwiftUI App project
  - Add both macOS and iOS targets from the start
  - Minimum deployment: macOS 26.0 / iOS 26.0
  - Import FoundationModels
  - Import ImagePlayground
  - Import PDFKit
  - No SPM dependencies needed - everything is Apple frameworks
  - App Sandbox: enable (standard Mac app)
  - Organize code into Shared/, macOS/, and iOS/ groups
  - Ensure the app builds and runs on Apple Silicon Mac
    running macOS Tahoe with Apple Intelligence enabled

═══════════════════════════════════════════════════════════════════
IMPORTANT IMPLEMENTATION NOTES
═══════════════════════════════════════════════════════════════════

1. The Foundation Models on-device LLM is a ~3B parameter model.
   It excels at SHORT-FORM creative text (2-4 sentences per page
   is ideal). Do NOT ask it to write lengthy paragraphs.

2. ImageCreator generates images as CGImage via AsyncSequence.
   Each image takes 15-30 seconds. Plan the UX around this.

3. ImageCreator limit is max 4 images per call, but we're doing
   1 per page so this is fine. Generate concurrently with
   TaskGroup but limit to 2-3 concurrent to avoid memory issues.

4. The Foundation Models framework is TEXT-ONLY input. No image
   input to the LLM.

5. For the PDF export, render at high resolution (300 DPI) so
   printed books look crisp. Calculate pixel dimensions from
   the BookFormat's inch dimensions x 300.

6. The @Generable macro handles all the structured output
   parsing. You do NOT need to parse JSON. The model returns
   typed Swift objects directly.

7. Use GenerationOptions with temperature ~1.2 and a reasonable
   maximumResponseTokens limit based on page count.

8. For the cover/title page illustration, create a separate
   ImageCreator call using the story title + a description
   like "children's book cover illustration for a story about
   [theme]".
```

**CODING AGENT PROMPT — END**

---

## 4. Architecture Reference

This section provides additional context for implementation. It is not part of the Coding Agent prompt but serves as a reference for understanding the technical decisions.

### 4.1 Generation Pipeline

The app follows a sequential pipeline where text generation must complete before image generation begins, since the LLM generates the image prompts that feed into ImageCreator.

1. **User provides** story concept, page count, format, and style preferences.
2. **LanguageModelSession** generates a complete `StoryBook` struct with all pages. The `@Generable` macro ensures the model produces properly typed Swift objects with no JSON parsing required.
3. **ImageCreator** generates an on-device illustration for each page's `imagePrompt`. These run concurrently (2-3 at a time) to balance speed with memory.
4. The completed storybook is **displayed** in the reader view and optionally persisted to disk.
5. User can **export to PDF** at print-ready resolution in their chosen book format.

### 4.2 Book Format Dimensions

| Format | Dimensions | PDF @ 300 DPI | Best For | Aspect Ratio |
|---|---|---|---|---|
| Standard Square | 8.5″ × 8.5″ | 2550 × 2550 px | Classic picture book | 1:1 |
| Landscape | 11″ × 8.5″ | 3300 × 2550 px | Wide illustrations | ~4:3 |
| Small Square | 6″ × 6″ | 1800 × 1800 px | Board books / mini | 1:1 |
| Portrait | 8.5″ × 11″ | 2550 × 3300 px | Standard print | ~3:4 |

> **Image Generation Timing:** Each illustration takes approximately 15-30 seconds to generate on-device. For an 8-page book plus cover, expect 2-5 minutes total for all illustrations. The UX must account for this with clear progress indicators and the ability to preview completed pages while others are still generating.

### 4.3 Key API Reference

#### Foundation Models — Text Generation

```swift
import FoundationModels

// Check availability
let model = SystemLanguageModel.default
guard model.availability == .available else { /* handle */ }

// Create session with instructions
let session = LanguageModelSession(
    instructions: "You are an award-winning children's..."
)

// Generate structured output
let options = GenerationOptions(
    temperature: 1.2,
    maximumResponseTokens: 2000
)
let book = try await session.respond(
    to: "Create an 8-page storybook about...",
    generating: StoryBook.self,
    options: options
)
// book.title, book.pages[0].text, etc. are typed properties
```

#### ImagePlayground — Image Generation

```swift
import ImagePlayground

// Create image from text prompt
let creator = try await ImageCreator()
let images = creator.images(
    for: [.text("A friendly fox sharing berries...")],
    style: .illustration,
    limit: 1
)
for try await image in images {
    let cgImage = image.cgImage  // CGImage ready to display
}
```

---

## 5. Known Limitations & Considerations

### 5.1 Model Limitations

- **3B parameter model:** The on-device LLM is powerful for its size but smaller than cloud models like Claude or GPT-4. Short-form creative text (2-4 sentences per page) is its sweet spot. Longer, more complex narratives may lose coherence.
- **Not a world-knowledge chatbot:** Apple explicitly states the model is not designed for general world knowledge. It excels at text generation, summarization, and structured output. Perfect for storybook creation.
- **Text-only input:** The Foundation Models framework only accepts text input. No image understanding, no multimodal input. This is fine for our use case.

### 5.2 Image Generation Limitations

- **Apple's illustration aesthetic:** Image Playground produces images in Apple's specific art styles. You can't get photorealistic images or highly specific art direction like you would with Midjourney or DALL-E. The available styles (illustration, animation, sketch) are all well-suited for children's books.
- **Prompt sensitivity:** Image Playground prompts work more like "concepts" than detailed instructions. Simple, descriptive prompts work best. Overly complex prompts may be partially ignored.
- **Generation time:** 15-30 seconds per image on-device. This is the biggest UX challenge and must be addressed with good progress UI.
- **Max 4 images per request:** Not an issue since we generate 1 per page, but worth knowing.

### 5.3 Device Requirements

- **Apple Silicon Mac required:** Intel Macs do not support Apple Intelligence.
- **macOS Tahoe (26) required:** Foundation Models framework is new in macOS 26. ImageCreator is available from macOS 15.4+.
- **Apple Intelligence must be enabled:** User must have opted in to Apple Intelligence in System Settings and downloaded the on-device models.
- **Image Playground models must be downloaded:** The diffusion model for image generation requires a separate download which happens when the user first opens Image Playground or an app that uses it.

---

## 6. Future Enhancement Ideas

These are not part of the initial build but represent natural extensions:

- **Character consistency:** Use the `.extracted(from:)` concept type to try to maintain character appearance across pages by providing a base image.
- **Read-aloud mode:** Use `AVSpeechSynthesizer` to read the story aloud with page auto-advance.
- **iOS companion app:** Both frameworks support iOS 26. The cross-platform architecture means flipping on the iOS target is straightforward.
- **Custom LoRA adapters:** Apple provides a Python toolkit for training adapters for the Foundation Model. Could train one specifically for children's story writing to improve quality.
- **Story continuation:** Use multi-turn sessions to let users add more pages or create sequels with the same characters.
- **Template themes:** Pre-built story templates (bedtime story, adventure, educational, etc.) with tuned system prompts for each.
- **Bookshelf view:** A 3D bookshelf displaying all saved storybooks with spine art.

---

## 7. Success Criteria

The initial build is considered complete when:

- User can enter a story concept and generate a complete illustrated storybook
- User can choose page count (4-16 pages)
- User can choose book format (square, landscape, small, portrait)
- User can choose illustration style (illustration, animation, sketch)
- Story text generates via Foundation Models with streaming progress
- Illustrations generate via ImageCreator with progressive loading
- Book reader view displays the complete storybook with page navigation
- PDF export works at print-ready resolution in the selected format
- App handles all error cases gracefully with helpful user messages
- App builds and runs on macOS Tahoe with Apple Intelligence enabled
- Project is structured for cross-platform with shared code in `Shared/`

---

*End of Document*
