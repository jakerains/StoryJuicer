import { NextResponse } from "next/server";
import { getPremiumConfig } from "@/lib/premium-config";
import { hasDevBypass } from "@/lib/dev-bypass";

export const maxDuration = 60;

export async function POST(request: Request) {
  try {
    // Kill switch — reject when premium is disabled (unless dev bypass is present)
    const config = await getPremiumConfig();
    if (!config.enabled && !hasDevBypass(request)) {
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

    // Translate Chat Completions format → Responses API format.
    // The Swift client sends standard chat messages; we convert here so the
    // client stays generic across all providers.
    const instructions = messages
      .filter((m: { role: string }) => m.role === "system")
      .map((m: { content: string }) => m.content)
      .join("\n\n");

    const input = messages
      .filter((m: { role: string }) => m.role !== "system")
      .map((m: { role: string; content: string }) => ({
        role: m.role,
        content: m.content,
      }));

    const responsesBody: Record<string, unknown> = {
      model: config.textModel,
      input,
    };

    // Only include temperature when explicitly provided — some models
    // (reasoning, o-series) reject it as an unsupported parameter.
    if (temperature !== undefined && temperature !== null) {
      responsesBody.temperature = temperature;
    }

    if (instructions) {
      responsesBody.instructions = instructions;
    }

    if (max_tokens) {
      responsesBody.max_output_tokens = max_tokens;
    }

    // Don't store debug/generation requests server-side
    responsesBody.store = false;

    const resp = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(responsesBody),
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

    // Translate Responses API format → Chat Completions format so the Swift
    // client's existing parser (StoryDecoding.extractTextContent) works unchanged.
    const outputText = data.output
      ?.filter((item: { type: string }) => item.type === "message")
      .flatMap((item: { content: Array<{ type: string; text: string }> }) => item.content)
      .filter((part: { type: string }) => part.type === "output_text")
      .map((part: { text: string }) => part.text)
      .join("") ?? "";

    const chatCompletionsResponse = {
      id: data.id,
      object: "chat.completion",
      created: data.created_at,
      model: data.model,
      choices: [
        {
          index: 0,
          message: {
            role: "assistant",
            content: outputText,
          },
          finish_reason: data.status === "completed" ? "stop" : "length",
        },
      ],
      usage: data.usage
        ? {
            prompt_tokens: data.usage.input_tokens,
            completion_tokens: data.usage.output_tokens,
            total_tokens: data.usage.total_tokens,
          }
        : undefined,
    };

    return NextResponse.json(chatCompletionsResponse);
  } catch (err) {
    console.error("Premium text proxy error:", err);
    return NextResponse.json(
      { error: "Something went wrong. Please try again." },
      { status: 500 }
    );
  }
}
