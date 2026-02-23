# Character Sheet Prompt (Premium Plus)

**Source:** `StoryPromptTemplates.characterSheetPrompt(characterDescription:style:)`
**Used by:** Premium Plus pipeline — generates a reference sheet for the main character
**Tier:** Premium Plus only (gated by `PremiumTier.usesCharacterSheet`)
**Sent to:** OpenAI image generation (edit endpoint with reference photo, or standard generation without)

---

Example with characterDescription = "Luna - a small orange fox with bright green eyes and a tattered green scarf" and style = `.illustration`:

```
Character reference sheet: [Luna - a small orange fox with bright green eyes and a tattered green scarf]. Full body, front-facing pose, simple clean storybook background. [Warm watercolor textures, children's book illustration style]. No text, words, or letters.
```

---

## Style Variants

### Illustration
```
Character reference sheet: [{description}]. Full body, front-facing pose, simple clean storybook background. [Warm watercolor textures, children's book illustration style]. No text, words, or letters.
```

### Animation
```
Character reference sheet: [{description}]. Full body, front-facing pose, simple clean storybook background. [3D animated cartoon style, Pixar-inspired, soft lighting]. No text, words, or letters.
```

### Sketch
```
Character reference sheet: [{description}]. Full body, front-facing pose, simple clean storybook background. [Pencil sketch style, hand-drawn, delicate linework]. No text, words, or letters.
```

---

**Notes:**
- This generates a single reference image of the main character in the book's art style.
- When a reference photo is uploaded, the edit endpoint uses it to style-transfer the photo into the illustration style.
- When no photo is uploaded, it generates from the text description alone.
- The character sheet is then passed as `characterSheetImage` to the illustration pipeline for visual consistency across pages.
- Only the first character (main protagonist) gets a sheet.
