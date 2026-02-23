import { NextResponse } from "next/server";
import {
  getPremiumConfig,
  setPremiumConfig,
  TEXT_MODELS,
  IMAGE_MODELS,
  IMAGE_QUALITIES,
} from "@/lib/premium-config";

/** GET — return current config (public, no auth needed). */
export async function GET() {
  try {
    const config = await getPremiumConfig();
    return NextResponse.json(config);
  } catch (err) {
    console.error("Premium config GET error:", err);
    return NextResponse.json(
      { error: "Failed to load config." },
      { status: 500 }
    );
  }
}

/** POST — update config (admin-secret protected). */
export async function POST(request: Request) {
  try {
    const adminSecret = process.env.ADMIN_SECRET;
    if (!adminSecret) {
      return NextResponse.json(
        { error: "Admin endpoint is not configured." },
        { status: 503 }
      );
    }

    // Check auth
    const authHeader = request.headers.get("authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (token !== adminSecret) {
      return NextResponse.json(
        { error: "Unauthorized." },
        { status: 401 }
      );
    }

    const body = await request.json();
    const { textModel, imageModel, imageQuality, imageModelPlus, imageQualityPlus } = body;

    // Validate values
    if (textModel && !TEXT_MODELS.includes(textModel)) {
      return NextResponse.json(
        { error: `textModel must be one of: ${TEXT_MODELS.join(", ")}` },
        { status: 400 }
      );
    }
    if (imageModel && !IMAGE_MODELS.includes(imageModel)) {
      return NextResponse.json(
        { error: `imageModel must be one of: ${IMAGE_MODELS.join(", ")}` },
        { status: 400 }
      );
    }
    if (imageQuality && !IMAGE_QUALITIES.includes(imageQuality)) {
      return NextResponse.json(
        { error: `imageQuality must be one of: ${IMAGE_QUALITIES.join(", ")}` },
        { status: 400 }
      );
    }
    if (imageModelPlus && !IMAGE_MODELS.includes(imageModelPlus)) {
      return NextResponse.json(
        { error: `imageModelPlus must be one of: ${IMAGE_MODELS.join(", ")}` },
        { status: 400 }
      );
    }
    if (imageQualityPlus && !IMAGE_QUALITIES.includes(imageQualityPlus)) {
      return NextResponse.json(
        { error: `imageQualityPlus must be one of: ${IMAGE_QUALITIES.join(", ")}` },
        { status: 400 }
      );
    }

    // Merge with current config (partial updates allowed)
    const current = await getPremiumConfig();
    const updated = {
      textModel: textModel ?? current.textModel,
      imageModel: imageModel ?? current.imageModel,
      imageQuality: imageQuality ?? current.imageQuality,
      imageModelPlus: imageModelPlus ?? current.imageModelPlus,
      imageQualityPlus: imageQualityPlus ?? current.imageQualityPlus,
    };

    await setPremiumConfig(updated);

    return NextResponse.json({ success: true, config: { ...updated, enabled: current.enabled } });
  } catch (err) {
    console.error("Premium config POST error:", err);
    return NextResponse.json(
      { error: "Failed to update config." },
      { status: 500 }
    );
  }
}
