import { NextResponse } from "next/server";
import { getPremiumConfig } from "@/lib/premium-config";

export const maxDuration = 60;

export async function POST(request: Request) {
  try {
    // Kill switch — reject when premium is disabled at the infrastructure level
    const config = await getPremiumConfig();
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

    const body = await request.json();
    const { messages, temperature, max_tokens } = body;

    if (!messages || !Array.isArray(messages)) {
      return NextResponse.json(
        { error: "messages array is required." },
        { status: 400 }
      );
    }

    // Forward to OpenAI with server-controlled model
    const openaiBody = {
      model: config.textModel,
      messages,
      temperature: temperature ?? 0.7,
      max_completion_tokens: max_tokens ?? 4096,
    };

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(openaiBody),
    });

    if (!resp.ok) {
      const errText = await resp.text();
      console.error(`OpenAI text error (${resp.status}):`, errText.slice(0, 500));
      return NextResponse.json(
        { error: `OpenAI request failed (${resp.status})`, detail: errText.slice(0, 500) },
        { status: resp.status }
      );
    }

    const data = await resp.json();
    return NextResponse.json(data);
  } catch (err) {
    console.error("Premium text proxy error:", err);
    return NextResponse.json(
      { error: "Something went wrong. Please try again." },
      { status: 500 }
    );
  }
}
