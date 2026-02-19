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
    version: "1.1.1",
    date: "2026-02-19",
    title: "Edit & Regenerate, StoryJuicer Stamp, Text Cleanup",
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
          "StoryJuicer library stamp on 'The End' page — a fox-on-book ink stamp appears in the reader, PDF, and EPUB exports",
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
        description: "Landing page at storyjuicer.app with full design system",
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
