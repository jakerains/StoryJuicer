# Premium Plus — Pass 1: Text Generation with Character Names (JSON)

**Source:** `StoryPromptTemplates.premiumPlusTextOnlyJSONPrompt(concept:pageCount:characterNames:)`
**Used by:** Cloud (OpenAI proxy) — Premium Plus tier when character photos are uploaded
**Tier:** Premium Plus (with photos)
**Role:** `user`
**System prompt:** [04-system-premium-json-mode.md](04-system-premium-json-mode.md)

---

Example with concept = "a brave little fox who learns to share", pageCount = 8, characterNames = ["Luna", "Max"]:

```
Create a 8-page children's storybook from this concept: "a brave little fox who learns to share".
The story features these characters as the protagonists: Luna, Max.
Write vivid physical descriptions so illustrations match their real-world likeness.
Focus ONLY on the story text — do NOT write image prompts.
Return JSON with this exact shape:
{
  "title": "string",
  "authorLine": "string",
  "moral": "string",
  "characterDescriptions": "One line per character: name - detailed visual description including hair/fur color, eye color, build, clothing, and one signature visual detail.",
  "pages": [
    {
      "pageNumber": 1,
      "text": "3-5 sentences of vivid, age-appropriate prose featuring the named characters"
    }
  ]
}
Requirements:
- Exactly 8 pages, numbered 1...8.
- characterDescriptions: One line per character — name, detailed visual description (hair/fur color, eye color, build, clothing), personality hint, and a signature visual detail.
- IMPORTANT: Every page must describe each character's physical appearance naturally within the prose, so illustrations accurately depict them.
- Build a complete narrative arc: a compelling hook, rising tension, a meaningful climax, and a satisfying resolution.
- Create an emotional arc alongside the plot — let characters feel wonder, doubt, courage, and joy.
- Use "show don't tell" moments: instead of saying a character is scared, describe their trembling paws or wide eyes.
- Weave in multi-sensory details: the crunch of autumn leaves, the warmth of sunlight, the smell of fresh-baked pie.
- Vary sentence rhythm — mix short, punchy sentences with longer, flowing ones for read-aloud musicality.
- Include at least one moment of gentle humor or surprise.
- Keep language warm, gentle, and easy to read aloud.
```

---

**Differences from Premium (file 06):**
- Opens with character name list: "The story features these characters as the protagonists: Luna, Max."
- Adds "Write vivid physical descriptions so illustrations match their real-world likeness."
- Character descriptions ask for more detail: hair/fur color, eye color, build, clothing (to match reference photos)
- Pages mention "featuring the named characters"
- Adds: "Every page must describe each character's physical appearance naturally within the prose"

**When this is NOT used:**
- If Premium Plus is active but no photos are uploaded, the app falls back to [06-premium-pass1-text-json.md](06-premium-pass1-text-json.md) instead.
