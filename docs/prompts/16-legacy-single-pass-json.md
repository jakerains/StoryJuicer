# Legacy — Single-Pass JSON Prompt

**Source:** `StoryPromptTemplates.userPrompt(concept:pageCount:)`
**Used by:** MLX / Cloud / Remote generators in the **old single-pass** pipeline
**Tier:** Free
**Role:** `user`
**System prompt:** [03-system-json-mode.md](03-system-json-mode.md)

---

Example with concept = "a brave little fox who learns to share" and pageCount = 8:

```
Create a 8-page children's storybook from this concept: "a brave little fox who learns to share".
Return JSON with this exact shape:
{
  "title": "string",
  "authorLine": "string",
  "moral": "string",
  "characterDescriptions": "One line per character: name - species or breed, colors, clothing, unique feature. Use the species from the concept — do not substitute a different animal.",
  "pages": [
    {
      "pageNumber": 1,
      "text": "2-4 child-friendly sentences",
      "imagePrompt": "Describe character by species and visual appearance (not just name), then action, setting, mood, colors. No text overlays."
    }
  ]
}
Requirements:
- Exactly 8 pages, numbered 1...8.
- characterDescriptions: One line per character — name, species, colors, clothing, one unique feature.
- CRITICAL for imagePrompt: Every imagePrompt MUST describe the character by species and appearance — not just their name. Image models cannot look up names.
  BAD: A character name alone with no visual description.
  GOOD: The character's species or breed, their color, what they wear, their action, and the setting.
  Always state WHAT the character is (species/type), their COLOR, and what they WEAR.
- Keep language warm, gentle, and easy to read aloud.
```

---

**Notes:**
- This is the **old single-pass** approach where text AND image prompts are generated in one shot.
- The two-pass pipeline (files 05/10 for free, 06-07/11 for premium) replaced this as the default for cloud generators.
- Still exists in code and may be used as a fallback or by older code paths.
- Generates both `text` and `imagePrompt` per page, which splits the LLM's attention.
