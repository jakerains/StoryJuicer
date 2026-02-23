# Free Tier — Pass 1: Text Generation (JSON)

**Source:** `StoryPromptTemplates.textOnlyJSONPrompt(concept:pageCount:)`
**Used by:** Cloud (HuggingFace, OpenRouter, Together AI) and MLX — free tier, two-pass pipeline
**Tier:** Free (`.off`)
**Role:** `user`
**System prompt:** [03-system-json-mode.md](03-system-json-mode.md)

---

Example with concept = "a brave little fox who learns to share" and pageCount = 8:

```
Create a 8-page children's storybook from this concept: "a brave little fox who learns to share".
Focus ONLY on the story text — do NOT write image prompts.
Return JSON with this exact shape:
{
  "title": "string",
  "authorLine": "string",
  "moral": "string",
  "characterDescriptions": "One line per character: name - species or breed, colors, clothing, unique feature. Use the species from the concept — do not substitute a different animal.",
  "pages": [
    {
      "pageNumber": 1,
      "text": "2-4 child-friendly sentences"
    }
  ]
}
Requirements:
- Exactly 8 pages, numbered 1...8.
- characterDescriptions: One line per character — name, species, colors, clothing, one unique feature.
- Build a complete narrative arc with a clear beginning, middle, and end.
- Keep language warm, gentle, and easy to read aloud.
```

---

**Notes:**
- This is the first pass of the two-pass pipeline — text only, no `imagePrompt` fields.
- The LLM focuses entirely on narrative without splitting attention on visual descriptions.
- Pages use "2-4 sentences" — shorter than the premium variant's "3-5 sentences".
- Character descriptions ask for: name, species, colors, clothing, one unique feature.
