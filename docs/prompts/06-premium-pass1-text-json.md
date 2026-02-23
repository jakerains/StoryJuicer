# Premium — Pass 1: Text Generation (JSON)

**Source:** `StoryPromptTemplates.premiumTextOnlyJSONPrompt(concept:pageCount:)`
**Used by:** Cloud (OpenAI proxy) — Premium tier, and Premium Plus without photos
**Tier:** Premium / Premium Plus (fallback when no photos uploaded)
**Role:** `user`
**System prompt:** [04-system-premium-json-mode.md](04-system-premium-json-mode.md)

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
  "characterDescriptions": "One line per character: name - species or breed, 2-3 physical traits (color, size, distinguishing marks), personality hint, one signature visual detail (e.g. a chipped ear, a sparkly bow, mismatched socks).",
  "pages": [
    {
      "pageNumber": 1,
      "text": "3-5 sentences of vivid, age-appropriate prose"
    }
  ]
}
Requirements:
- Exactly 8 pages, numbered 1...8.
- characterDescriptions: One line per character — name, species, 2-3 physical traits, personality hint, and a signature visual detail. Use the species from the concept — do not substitute a different animal.
- Build a complete narrative arc: a compelling hook, rising tension, a meaningful climax, and a satisfying resolution.
- Create an emotional arc alongside the plot — let characters feel wonder, doubt, courage, and joy.
- Use "show don't tell" moments: instead of saying a character is scared, describe their trembling paws or wide eyes.
- Weave in multi-sensory details: the crunch of autumn leaves, the warmth of sunlight, the smell of fresh-baked pie.
- Vary sentence rhythm — mix short, punchy sentences with longer, flowing ones for read-aloud musicality.
- Include at least one moment of gentle humor or surprise.
- Keep language warm, gentle, and easy to read aloud.
```

---

**Differences from free tier (file 05):**
- Pages ask for "3-5 sentences" (vs free's "2-4")
- Character descriptions require: 2-3 physical traits, personality hint, signature visual detail (vs free's simpler format)
- Narrative arc guidance is more specific: "compelling hook, rising tension, meaningful climax, satisfying resolution"
- Adds emotional arc instruction
- Adds "show don't tell" with concrete examples
- Adds multi-sensory detail instruction with examples
- Adds sentence rhythm variation
- Adds gentle humor requirement
