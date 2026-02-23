# Foundation Models — Pass 1: Text Only (Structured Output)

**Source:** `StoryPromptTemplates.textOnlyPrompt(concept:pageCount:)`
**Used by:** Apple Foundation Models (on-device) in the two-pass path
**Tier:** Free (on-device only)
**Role:** `user`
**System prompt:** [01-system-instructions-kid.md](01-system-instructions-kid.md) (via `@Generable` session)

---

Example with concept = "a brave little fox who learns to share" and pageCount = 8:

```
Story concept: "a brave little fox who learns to share".
Create a 8-page children's storybook based on that concept. Generate exactly 8 pages, numbered 1 to 8. Focus ONLY on the story text — do NOT write image prompts. Each page should have 2-4 sentences of vivid, age-appropriate prose. For characterDescriptions, list each character on one line: name - species or breed, colors, clothing, one distinguishing feature. Use the species from the concept — do not substitute a different animal. Build a complete narrative arc with a clear beginning, middle, and end. Keep the story warm, comforting, and suitable for ages 3-8.
```

---

**Notes:**
- Two-pass variant for Foundation Models — text only, no image prompts.
- Like file 08 but explicitly says "Focus ONLY on the story text — do NOT write image prompts."
- The corresponding Pass 2 is [12-foundation-pass2-image-prompts.md](12-foundation-pass2-image-prompts.md).
