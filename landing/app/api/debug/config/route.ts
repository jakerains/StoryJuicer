import { NextResponse } from "next/server";
import { hasDevBypass } from "@/lib/dev-bypass";

/** GET — return whether the debug panel is enabled. */
export async function GET(request: Request) {
  const enabled =
    process.env.DEBUG_ENABLED === "true" || hasDevBypass(request);
  return NextResponse.json({ enabled });
}
