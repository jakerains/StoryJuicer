import { NextResponse } from "next/server";

/** GET — return whether the debug panel is enabled (public, no auth needed). */
export async function GET() {
  const enabled = process.env.DEBUG_ENABLED === "true";
  return NextResponse.json({ enabled });
}
