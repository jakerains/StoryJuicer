# Image Style Suffixes

**Source:** `CloudImageGenerator.applyStyleSuffix(to:style:)`
**Used by:** All cloud image generation (HuggingFace, OpenAI proxy, OpenRouter, Together AI)
**Applied to:** Every image prompt before it's sent to the diffusion model

---

These suffixes are appended to the LLM-generated image prompt. They steer the diffusion model toward a specific art style. Every prompt also gets a universal safety suffix at the end.

## Free Tier

### Illustration
```
{image prompt}, children's book illustration style, warm watercolor textures. Absolutely no text, words, letters, or numbers in the image.
```

### Animation
```
{image prompt}, 3D animated cartoon style, Pixar-inspired, soft lighting. Absolutely no text, words, letters, or numbers in the image.
```

### Sketch
```
{image prompt}, pencil sketch style, hand-drawn, delicate linework. Absolutely no text, words, letters, or numbers in the image.
```

---

## Premium / Premium Plus

### Illustration
```
{image prompt}, award-winning children's book illustration, rich watercolor textures with visible brushstrokes, warm golden lighting, soft depth of field, hand-painted quality. Absolutely no text, words, letters, or numbers in the image.
```

### Animation
```
{image prompt}, Pixar-quality 3D animated character render, soft ambient occlusion, warm rim lighting, cinematic depth of field, premium production quality. Absolutely no text, words, letters, or numbers in the image.
```

### Sketch
```
{image prompt}, professional children's book pencil illustration, delicate crosshatching, expressive linework, subtle tonal gradation, museum-quality draftsmanship. Absolutely no text, words, letters, or numbers in the image.
```

---

**Key differences (Premium vs Free):**

| Style | Free | Premium |
|-------|------|---------|
| Illustration | "warm watercolor textures" | "rich watercolor textures with visible brushstrokes, warm golden lighting, soft depth of field, hand-painted quality" |
| Animation | "Pixar-inspired, soft lighting" | "soft ambient occlusion, warm rim lighting, cinematic depth of field, premium production quality" |
| Sketch | "hand-drawn, delicate linework" | "delicate crosshatching, expressive linework, subtle tonal gradation, museum-quality draftsmanship" |

**Notes:**
- Premium suffixes use specific art/rendering terms (ambient occlusion, crosshatching, tonal gradation) that diffusion models have strong conditioning for.
- The "no text" suffix is always appended regardless of tier — diffusion models love to add text to images otherwise.
