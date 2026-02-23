# Premium — Pass 2: Image Prompt Generation (JSON)

**Source:** `StoryPromptTemplates.premiumImagePromptJSONPrompt(characterDescriptions:pages:)`
**Used by:** Cloud (OpenAI proxy) — both Premium and Premium Plus tiers
**Tier:** Premium / Premium Plus
**Role:** `user`
**System prompt:** [13-pass2-system-prompt.md](13-pass2-system-prompt.md) (premium variant)

---

Example with a completed story:

```
You are an award-winning art director writing illustration prompts for a premium children's storybook.

CHARACTER SHEET:
Finn - a small orange fox with bright green eyes, a tattered green scarf, and a chipped left ear
Rosie - a plump brown rabbit with floppy ears, a yellow daisy tucked behind one ear, and a blue apron

COMPLETE STORY TEXT:
Page 1: Deep in the whispering woods, a little fox named Finn found three shiny acorns beneath the old oak tree. He tucked them carefully into his scarf and scurried home.
Page 2: On the forest path, Finn bumped into Rosie the rabbit. "What do you have there?" she asked, her nose twitching with curiosity.
...

Write one detailed, cinematic image prompt for each page.
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
- Use cinematic composition: rule of thirds, leading lines, depth layers (foreground/midground/background).
- Specify mood lighting: golden hour warmth, dappled forest light, cozy lamplight, moonlit silver.
- Include environmental storytelling: scattered toys, steam rising from a cup, footprints in snow.
- Describe a cohesive color palette for each scene that reinforces the emotional tone.
- Add "visual callbacks" — reference specific visual elements from earlier pages to create a connected sequence (e.g. a flower picked on page 2 appears tucked behind an ear on page 5).
- Maintain visual consistency: same character colors, clothing, and features across all pages.
- Describe expressions and body language to convey emotion (sparkling eyes, a tentative step forward, arms thrown wide).
- Do NOT include any text, words, or letters in the scene descriptions.
```

---

**Differences from free tier (file 10):**
- Opens with "award-winning art director" and "premium children's storybook" (vs generic)
- Asks for "cinematic" image prompts (vs "detailed")
- Adds cinematic composition: rule of thirds, leading lines, depth layers
- Adds mood lighting with specific examples
- Adds environmental storytelling
- Adds color palette continuity
- Adds "visual callbacks" — cross-page visual references for cohesion
- Adds expressions and body language instruction
- Same species/appearance rules as free tier
