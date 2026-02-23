import { NextResponse } from "next/server";
import { getPremiumConfig } from "@/lib/premium-config";

export const maxDuration = 60;

export async function POST(request: Request) {
  try {
    const config = await getPremiumConfig();

    // Kill switch — reject when premium is disabled at the infrastructure level
    if (!config.enabled) {
      return NextResponse.json(
        { error: "Premium is currently disabled." },
        { status: 503 }
      );
    }

    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      return NextResponse.json(
        { error: "Premium service is not configured." },
        { status: 503 }
      );
    }

    const contentType = request.headers.get("content-type") ?? "";

    // Multipart = edit with reference photos (always Premium Plus tier)
    if (contentType.includes("multipart/form-data")) {
      return await handleImageEdit(request, apiKey, config);
    }

    // JSON = standard generation (tier determined by request body)
    return await handleImageGeneration(request, apiKey, config);
  } catch (err) {
    console.error("Premium image proxy error:", err);
    return NextResponse.json(
      { error: "Something went wrong. Please try again." },
      { status: 500 }
    );
  }
}

/** Standard image generation (no reference photos). */
async function handleImageGeneration(
  request: Request,
  apiKey: string,
  config: Awaited<ReturnType<typeof getPremiumConfig>>
) {
  const body = await request.json();
  const { prompt, size, tier } = body;

  if (!prompt || typeof prompt !== "string") {
    return NextResponse.json(
      { error: "prompt is required." },
      { status: 400 }
    );
  }

  // Route model/quality based on tier
  const isPlus = tier === "plus";
  const model = isPlus ? config.imageModelPlus : config.imageModel;
  const quality = isPlus ? config.imageQualityPlus : config.imageQuality;

  const openaiBody = {
    model,
    prompt,
    size: size ?? "1024x1024",
    quality,
    n: 1,
    output_format: "png",
  };

  const resp = await fetch("https://api.openai.com/v1/images/generations", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(openaiBody),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    console.error(`OpenAI image gen error (${resp.status}):`, errText.slice(0, 500));
    return NextResponse.json(
      { error: `OpenAI request failed (${resp.status})`, detail: errText.slice(0, 500) },
      { status: resp.status }
    );
  }

  const data = await resp.json();
  return NextResponse.json(data);
}

/** Image edit with reference photos (multipart pass-through). Always uses Plus tier models. */
async function handleImageEdit(
  request: Request,
  apiKey: string,
  config: Awaited<ReturnType<typeof getPremiumConfig>>
) {
  const incoming = await request.formData();

  // Edit endpoint always uses Plus tier models (only Plus sends multipart)
  const outgoing = new FormData();
  outgoing.set("model", config.imageModelPlus);
  outgoing.set("quality", config.imageQualityPlus);
  outgoing.set("output_format", "jpeg");
  outgoing.set("n", "1");
  outgoing.set("input_fidelity", "high");

  // Pass through client-provided fields
  const prompt = incoming.get("prompt");
  if (prompt) outgoing.set("prompt", prompt);

  const size = incoming.get("size");
  if (size) outgoing.set("size", size);

  // Pass through all image[] files
  for (const [key, value] of incoming.entries()) {
    if (key === "image[]" && value instanceof File) {
      outgoing.append("image[]", value, value.name);
    }
  }

  const resp = await fetch("https://api.openai.com/v1/images/edits", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
    body: outgoing,
  });

  if (!resp.ok) {
    const errText = await resp.text();
    console.error(`OpenAI image edit error (${resp.status}):`, errText.slice(0, 500));
    return NextResponse.json(
      { error: `OpenAI request failed (${resp.status})`, detail: errText.slice(0, 500) },
      { status: resp.status }
    );
  }

  const data = await resp.json();
  return NextResponse.json(data);
}
