# Foundation Models — Structured Output Prompt

**Source:** `StoryPromptTemplates.structuredOutputPrompt(concept:pageCount:)`
**Used by:** Apple Foundation Models (on-device ~3B LLM) via `@Generable` structured output
**Tier:** Free (on-device only)
**Role:** `user`
**System prompt:** [01-system-instructions-kid.md](01-system-instructions-kid.md) (via `@Generable` session)

---

Example with concept = "a brave little fox who learns to share" and pageCount = 8:

```
Story concept: "a brave little fox who learns to share".
Create a 8-page children's storybook based on that concept. Generate exactly 8 pages. Number them from 1 to 8. Each page should have 2-4 sentences of story text and a detailed illustration prompt. For characterDescriptions, list each character on one line with their name, species, colors, clothing, and one unique feature. CRITICAL: In each imagePrompt, describe the character by their species and visual appearance — not just their name. An image model cannot look up character names. Always include the character's species or breed, color, and clothing in every imagePrompt. Keep the story warm, comforting, and suitable for ages 3-8.
```

---

**Notes:**
- This is a **single-pass** prompt — it generates text AND image prompts in one shot.
- No JSON schema in the prompt — the `@Generable` macro on `StoryBook` and `@Guide` annotations on each field provide the schema to Foundation Models automatically.
- This is the only prompt that asks for `imagePrompt` alongside `text` in a single pass.
- Used when the text provider is `.appleFoundation` and the device has Apple Intelligence.
