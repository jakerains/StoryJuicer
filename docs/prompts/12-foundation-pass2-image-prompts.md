# Foundation Models — Pass 2: Image Prompt Generation

**Source:** `StoryPromptTemplates.imagePromptPassPrompt(characterDescriptions:pages:)`
**Used by:** Apple Foundation Models (on-device) in the two-pass path
**Tier:** Free (on-device only)
**Role:** `user`
**System prompt:** [01-system-instructions-kid.md](01-system-instructions-kid.md)

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

Write one detailed image prompt for each page. Generate exactly 8 prompts, one per page.

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
- Same content as file 10 but **without the JSON schema wrapper**.
- Foundation Models use `@Generable` structured output, so the output shape is defined by Swift type annotations, not by a JSON schema in the prompt.
- This is the on-device equivalent of the cloud Pass 2.
