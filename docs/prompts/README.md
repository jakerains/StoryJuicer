# StoryFox Prompt Reference

Every prompt the app sends to an LLM, organized by tier and pipeline step.

All prompts live in `Shared/Generation/StoryPromptTemplates.swift`. Image style suffixes are in `Shared/Generation/CloudImageGenerator.swift`.

## Pipeline Overview

StoryFox uses a **two-pass** generation pipeline:

1. **Pass 1 (Text)** — Generate story text + character descriptions (no image prompts)
2. **Pass 2 (Image Prompts)** — Feed the complete story back to generate illustration prompts

Premium tiers get enhanced versions of both passes.

## File Index

### System Prompts
| File | Used By | Tier |
|------|---------|------|
| [01-system-instructions-kid.md](01-system-instructions-kid.md) | All generators | All |
| [02-system-instructions-adult.md](02-system-instructions-adult.md) | All generators (adult audience) | All |
| [03-system-json-mode.md](03-system-json-mode.md) | MLX, Cloud, Remote | Free |
| [04-system-premium-json-mode.md](04-system-premium-json-mode.md) | Cloud (OpenAI proxy) | Premium / Premium Plus |

### Pass 1 — Text Generation
| File | Used By | Tier |
|------|---------|------|
| [05-free-pass1-text-json.md](05-free-pass1-text-json.md) | Cloud / MLX (two-pass) | Free |
| [06-premium-pass1-text-json.md](06-premium-pass1-text-json.md) | Cloud (OpenAI proxy) | Premium |
| [07-premium-plus-pass1-text-json.md](07-premium-plus-pass1-text-json.md) | Cloud (OpenAI proxy) | Premium Plus (with photos) |
| [08-foundation-pass1-structured.md](08-foundation-pass1-structured.md) | Apple Foundation Models | Free (on-device) |
| [09-foundation-pass1-text-only.md](09-foundation-pass1-text-only.md) | Apple Foundation Models (two-pass) | Free (on-device) |

### Pass 2 — Image Prompt Generation
| File | Used By | Tier |
|------|---------|------|
| [10-free-pass2-image-prompts-json.md](10-free-pass2-image-prompts-json.md) | Cloud / MLX | Free |
| [11-premium-pass2-image-prompts-json.md](11-premium-pass2-image-prompts-json.md) | Cloud (OpenAI proxy) | Premium / Premium Plus |
| [12-foundation-pass2-image-prompts.md](12-foundation-pass2-image-prompts.md) | Apple Foundation Models | Free (on-device) |
| [13-pass2-system-prompt.md](13-pass2-system-prompt.md) | Cloud (both tiers) | All |

### Image Generation
| File | Used By | Tier |
|------|---------|------|
| [14-image-style-suffixes.md](14-image-style-suffixes.md) | CloudImageGenerator | All |
| [15-character-sheet-prompt.md](15-character-sheet-prompt.md) | Premium Plus pipeline | Premium Plus |

### Legacy (Single-Pass)
| File | Used By | Tier |
|------|---------|------|
| [16-legacy-single-pass-json.md](16-legacy-single-pass-json.md) | MLX / Cloud / Remote (old path) | Free |

## How Tier Routing Works

```
squeezeStory()
  └─ generateCloudStory()
       └─ CloudTextGenerator.generateStory()
            ├─ premiumTier == .off
            │    ├─ Pass 1: textOnlyJSONPrompt           (file 05)
            │    └─ Pass 2: imagePromptJSONPrompt         (file 10)
            ├─ premiumTier == .premium
            │    ├─ Pass 1: premiumTextOnlyJSONPrompt     (file 06)
            │    └─ Pass 2: premiumImagePromptJSONPrompt  (file 11)
            └─ premiumTier == .premiumPlus
                 ├─ Pass 1 (with photos): premiumPlusTextOnlyJSONPrompt  (file 07)
                 ├─ Pass 1 (no photos):   premiumTextOnlyJSONPrompt      (file 06)
                 └─ Pass 2: premiumImagePromptJSONPrompt                 (file 11)
```
