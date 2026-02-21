import { NextResponse } from "next/server";
import { neon } from "@neondatabase/serverless";

const VALID_CATEGORIES = ["suggestion", "bug", "complaint", "other"] as const;

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { category, message, email } = body;

    // Validate message
    if (!message || typeof message !== "string" || message.trim().length === 0) {
      return NextResponse.json(
        { error: "Message is required." },
        { status: 400 }
      );
    }

    if (message.length > 2000) {
      return NextResponse.json(
        { error: "Message must be 2000 characters or fewer." },
        { status: 400 }
      );
    }

    // Validate category
    const cat = category ?? "suggestion";
    if (!VALID_CATEGORIES.includes(cat)) {
      return NextResponse.json(
        { error: `Category must be one of: ${VALID_CATEGORIES.join(", ")}` },
        { status: 400 }
      );
    }

    // Validate email (optional, but if provided must look reasonable)
    const trimmedEmail = email?.trim() || null;
    if (trimmedEmail && !trimmedEmail.includes("@")) {
      return NextResponse.json(
        { error: "Please provide a valid email address." },
        { status: 400 }
      );
    }

    const sql = neon(process.env.DATABASE_URL!);

    await sql`
      INSERT INTO feedback (category, message, email)
      VALUES (${cat}, ${message.trim()}, ${trimmedEmail})
    `;

    return NextResponse.json({ success: true });
  } catch (err) {
    console.error("Feedback submission error:", err);
    return NextResponse.json(
      { error: "Something went wrong. Please try again." },
      { status: 500 }
    );
  }
}
