export interface ChangelogChange {
  type: "added" | "fixed" | "changed" | "removed";
  description: string;
}

export interface ChangelogEntry {
  version: string;
  date: string;
  title: string;
  changes: ChangelogChange[];
}

export const changelog: ChangelogEntry[] = [
  {
    version: "1.4.1",
    date: "2026-02-20",
    title: "Auto-Check for Updates on Launch",
    changes: [
      {
        type: "fixed",
        description:
          "App now silently checks for updates 3 seconds after launch — no more waiting for the 24-hour Sparkle schedule or manually clicking 'Check for Updates'",
      },
    ],
  },
  {
    version: "1.4.0",
    date: "2026-02-20",
    title: "Redesigned Creation Screen",
    changes: [
      {
        type: "changed",
        description:
          "Creation screen redesigned with an open, cardless layout — hero illustration, gradient title with sparkle accents, and breathing room throughout",
      },
      {
        type: "added",
        description:
          "StoryFox hero illustration on the creation screen and About panel, replacing the standard app icon",
      },
      {
        type: "changed",
        description:
          "Book setup moved from a disclosure card to a compact chip that opens a popover — sits inline with Quick/Guided toggle",
      },
      {
        type: "changed",
        description:
          "Sidebar streamlined — removed header branding so New Story is the first element",
      },
      {
        type: "fixed",
        description:
          "Sidebar selection highlight now uses coral instead of system blue across all macOS accent color settings",
      },
      {
        type: "changed",
        description:
          "App accent color set to coral globally — focus rings, toggles, and system chrome all match the StoryFox palette",
      },
    ],
  },
  {
    version: "1.3.3",
    date: "2026-02-20",
    title: "Fix Cloud Image Generation Routing",
    changes: [
      {
        type: "fixed",
        description:
          "Cloud image generation now works with all listed HuggingFace models — Z-Image Turbo, HunyuanImage 3.0, SD 3.5 Medium, and HiDream I1 Fast previously returned 404 errors",
      },
      {
        type: "added",
        description:
          "Smart inference provider routing automatically resolves the correct HuggingFace backend (hf-inference, fal-ai, replicate) for each model",
      },
      {
        type: "removed",
        description:
          "Removed FLUX.1 Canny and FLUX.1 Depth from image model picker — these ControlNet models require a conditioning image and don't work with text-only prompts",
      },
    ],
  },
  {
    version: "1.3.2",
    date: "2026-02-20",
    title: "Expanded Cloud Model Selection",
    changes: [
      {
        type: "added",
        description:
          "Hugging Face text model picker now features curated top models: GPT-OSS 120B (default), GPT-OSS 20B, Qwen3 32B, DeepSeek V3, Llama 3.1 8B, and Mistral 7B",
      },
      {
        type: "added",
        description:
          "Hugging Face image model picker expanded with Z-Image Turbo, HunyuanImage 3.0, Stable Diffusion 3.5 Medium, and HiDream I1 Fast alongside FLUX.1 models",
      },
      {
        type: "changed",
        description:
          "Default Hugging Face text model changed from Llama 4 Maverick to GPT-OSS 120B for better story generation quality",
      },
    ],
  },
  {
    version: "1.3.1",
    date: "2026-02-20",
    title: "Improved Tap Targets",
    changes: [
      {
        type: "fixed",
        description:
          "Quick/Guided mode buttons now respond to taps anywhere on the chip, not just the text",
      },
      {
        type: "fixed",
        description:
          "Book Setup section can be expanded by clicking anywhere on the card, not just the label",
      },
    ],
  },
  {
    version: "1.3.0",
    date: "2026-02-20",
    title: "StoryFox Rebrand",
    changes: [
      {
        type: "changed",
        description:
          "StoryJuicer is now StoryFox — new name, new domain (storyfox.app), same great storybook experience",
      },
      {
        type: "changed",
        description:
          "Updated stamp image with StoryFox branding on every exported book",
      },
      {
        type: "changed",
        description:
          "New HuggingFace OAuth integration for seamless cloud AI sign-in",
      },
    ],
  },
  {
    version: "1.2.5",
    date: "2026-02-20",
    title: "Sidebar Favorites, OpenRouter, Collapsible Sections & Landing Polish",
    changes: [
      {
        type: "added",
        description:
          "Sidebar favorites — star any storybook to pin it in a dedicated Favorites section that floats above your library",
      },
      {
        type: "added",
        description:
          "Collapsible sidebar sections — Favorites and Your Storybooks can be expanded/collapsed, with state persisted across launches",
      },
      {
        type: "added",
        description:
          "Drag-to-reorder books within each sidebar section, with order persisted via SwiftData",
      },
      {
        type: "added",
        description:
          "OpenRouter provider — now accessible in Settings as a collapsible advanced section with curated model picks at the top",
      },
      {
        type: "added",
        description:
          "Final cover rescue pass — if the cover image is still missing after all recovery attempts, a dedicated last-resort retry runs with the safest prompt variants",
      },
      {
        type: "changed",
        description:
          "Book Setup section on creation view is now collapsible with a summary line showing current page count, format, and style",
      },
      {
        type: "changed",
        description:
          "EPUB cover image now tagged with properties=\"cover-image\" and EPUB 2 backward-compatible meta for better Kindle/older reader support",
      },
      {
        type: "changed",
        description:
          "Selected picker items now use a stronger coral tint and border for better visual contrast",
      },
      {
        type: "changed",
        description:
          "Landing page copy tightened across Hero, Features, HuggingFace, Requirements, and Safety sections for clarity and conciseness",
      },
    ],
  },
  {
    version: "1.2.4",
    date: "2026-02-19",
    title: "Show Active Model in Progress View",
    changes: [
      {
        type: "changed",
        description:
          "Generation progress now shows the actual model name (e.g., 'FLUX.1-schnell') instead of just the provider name, and reflects fallbacks in real time",
      },
    ],
  },
  {
    version: "1.2.3",
    date: "2026-02-19",
    title: "Dynamic Q&A Flow & Keyboard Navigation",
    changes: [
      {
        type: "changed",
        description:
          "Guided Q&A is now dynamic — the AI decides how many questions to ask (1-3 per round) and stops when it has enough detail, instead of always running 3 fixed rounds",
      },
      {
        type: "added",
        description:
          "Arrow key page navigation now works reliably in the book reader on both macOS and iOS (with external keyboard)",
      },
    ],
  },
  {
    version: "1.2.2",
    date: "2026-02-19",
    title: "Kid Mode Q&A — Truly Kid-Friendly",
    changes: [
      {
        type: "fixed",
        description:
          "Kid mode Q&A now generates truly kid-friendly questions and answers — uses few-shot examples to enforce kindergarten-level vocabulary across all 3 rounds",
      },
      {
        type: "changed",
        description:
          "Kid mode round headers now say 'Hero & World', 'Adventure & Problem', 'Ending & Feelings' instead of adult terms",
      },
    ],
  },
  {
    version: "1.2.1",
    date: "2026-02-19",
    title: "Kid Mode Q&A Language Fix",
    changes: [
      {
        type: "fixed",
        description:
          "Kid mode Q&A now uses truly kid-friendly language — no more adult vocabulary like 'protagonist' or 'conflict' in questions",
      },
    ],
  },
  {
    version: "1.2.0",
    date: "2026-02-19",
    title: "Guided Story Creation, Audience Mode, About Panel",
    changes: [
      {
        type: "added",
        description:
          "Guided creation mode — AI asks follow-up questions across 3 rounds (characters, plot, tone) with A/B/C suggestions to enrich your story concept before generation",
      },
      {
        type: "added",
        description:
          "Kid / Adult audience toggle in Settings — adjusts Q&A question tone and story generation language level",
      },
      {
        type: "added",
        description:
          "Custom About panel with 'Made with love by Jake Rains' credit linking to jakerains.com",
      },
      {
        type: "changed",
        description:
          "Creation view now features a Quick/Guided mode toggle below the story concept input",
      },
    ],
  },
  {
    version: "1.1.1",
    date: "2026-02-19",
    title: "Edit & Regenerate, StoryFox Stamp, Text Cleanup",
    changes: [
      {
        type: "added",
        description:
          "Edit button in reader toolbar — edit author, page text, or moral directly from the reader",
      },
      {
        type: "added",
        description:
          "Image regeneration with optional custom prompt — guide the AI to get the illustration you want",
      },
      {
        type: "added",
        description:
          "StoryFox library stamp on 'The End' page — a fox-on-book ink stamp appears in the reader, PDF, and EPUB exports",
      },
      {
        type: "fixed",
        description:
          "Text formatting cleanup — strips markdown bold/italic artifacts from cloud and MLX model outputs",
      },
      {
        type: "fixed",
        description:
          "Squeeze a Story button now clickable across the entire pill area, not just the text",
      },
      {
        type: "fixed",
        description:
          "Version numbering corrected — About screen and Sparkle updates now show the correct version",
      },
      {
        type: "changed",
        description:
          "Auto-update checks enabled on launch — no longer requires manual 'Check for Updates' click",
      },
    ],
  },
  {
    version: "1.1.0",
    date: "2026-02-19",
    title: "EPUB Export, Changelog & Analytics",
    changes: [
      {
        type: "added",
        description:
          "EPUB 3.0 Fixed Layout export — read your storybooks in Apple Books, Kindle, and other EPUB readers",
      },
      {
        type: "added",
        description:
          "Export menu in the reader toolbar with both PDF and EPUB options (macOS and iOS)",
      },
      {
        type: "added",
        description:
          "Changelog page on the landing site with version history and color-coded change types",
      },
      {
        type: "added",
        description:
          "Vercel Analytics custom event tracking for downloads, GitHub clicks, and HuggingFace signups",
      },
      {
        type: "changed",
        description:
          "Footer now shows a Changelog pill button and auto-syncs the version badge",
      },
    ],
  },
  {
    version: "1.0.3",
    date: "2026-02-19",
    title: "Landing Page & Link Previews",
    changes: [
      {
        type: "added",
        description: "Landing page at storyfox.app with full design system",
      },
      {
        type: "added",
        description: "Open Graph and Twitter Card meta tags for rich link previews",
      },
      {
        type: "added",
        description: "Vercel Web Analytics integration",
      },
      {
        type: "changed",
        description: "Footer GitHub link upgraded to pill button style",
      },
      {
        type: "fixed",
        description: "OG image URLs now use custom domain",
      },
    ],
  },
  {
    version: "1.0.2",
    date: "2026-02-15",
    title: "Sparkle Auto-Update",
    changes: [
      {
        type: "added",
        description:
          "Automatic update checking via Sparkle 2 with EdDSA signature verification",
      },
      {
        type: "added",
        description:
          'Appcast feed hosted on GitHub for seamless version delivery',
      },
      {
        type: "added",
        description: '"Check for Updates" menu item in the app menu',
      },
    ],
  },
  {
    version: "1.0.1",
    date: "2026-02-12",
    title: "Cloud & Local AI Providers",
    changes: [
      {
        type: "added",
        description:
          "Hugging Face cloud text and image generation via OAuth login",
      },
      {
        type: "added",
        description:
          "MLX Swift local model support for on-device open-weight LLMs",
      },
      {
        type: "added",
        description:
          "Settings panel with glass-morphism design and provider test buttons",
      },
      {
        type: "changed",
        description: "Image generation now routes through unified provider system",
      },
    ],
  },
  {
    version: "1.0.0",
    date: "2026-02-08",
    title: "Initial Release",
    changes: [
      {
        type: "added",
        description:
          "On-device story generation using Apple Foundation Models",
      },
      {
        type: "added",
        description:
          "On-device illustration generation using ImagePlayground",
      },
      {
        type: "added",
        description:
          "Four book formats: Standard Square, Landscape, Small Square, Portrait",
      },
      {
        type: "added",
        description: "Print-ready 300 DPI PDF export",
      },
      {
        type: "added",
        description:
          "SwiftData persistence for saving and reopening storybooks",
      },
      {
        type: "added",
        description:
          "Page-by-page reader with keyboard navigation and page overview grid",
      },
    ],
  },
];

export function latestVersion(): string {
  return changelog[0]?.version ?? "1.0.0";
}
