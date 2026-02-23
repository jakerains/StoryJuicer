# Free Tier — Pass 2: Image Prompt Generation (JSON)

**Source:** `StoryPromptTemplates.imagePromptJSONPrompt(characterDescriptions:pages:)`
**Used by:** Cloud / MLX — free tier, two-pass pipeline
**Tier:** Free (`.off`)
**Role:** `user`
**System prompt:** [13-pass2-system-prompt.md](13-pass2-system-prompt.md) (free variant)

---

Example with a completed story:

```
You are an art director writing illustration prompts for a children's storybook.

CHARACTER SHEET:
Finn - a small orange fox with bright green eyes, a tattered green scarf, and a chipped left ear
Rosie - a plump brown rabbit with floppy ears, a yellow daisy tucked behind one ear, and a blue apron

COMPLETE STORY TEXT:
Page 1: Deep in the whispering woods, a little fox named Finn found three shiny acorns beneath the old oak tree. He tucked them carefully into his scarf and scurried home.
Page 2: On the forest path, Finn bumped into Rosie the rabbit. "What do you have there?" she asked, her nose twitching with curiosity.
...

Write one detailed image prompt for each page.
Return JSON with this exact shape:
{
  "prompts": [
    {
      "pageNumber": 1,
      "imagePrompt": "Detailed visual scene description"
    }
  ]
}
Generate exactly 8 prompts, one per page.

CRITICAL RULES:
- Describe every character by their SPECIES and VISUAL APPEARANCE — never by name alone. Image models cannot look up character names.
- Always state WHAT the character is (species/type), their COLOR, and what they WEAR.
- Include setting, action, expressions, mood, and lighting.
- Maintain visual consistency: same character colors, clothing, and features across all pages.
- Reference earlier and later scenes to ensure the illustrations tell a cohesive visual story.
- Do NOT include any text, words, or letters in the scene descriptions.
```

---

**Notes:**
- This receives the **full story text** from Pass 1, so the LLM knows the complete narrative before writing image prompts.
- The CHARACTER SHEET is the `characterDescriptions` field from the Pass 1 response.
- The COMPLETE STORY TEXT is every page's `text` field from Pass 1.
- The critical rules emphasize species/appearance over names — because image models can't look up names.
