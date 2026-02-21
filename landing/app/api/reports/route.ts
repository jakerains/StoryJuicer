import { NextResponse } from "next/server";
import { put } from "@vercel/blob";
import { neon } from "@neondatabase/serverless";

const MAX_ZIP_SIZE = 5 * 1024 * 1024; // 5 MB

// Simple in-memory rate limit: one report per IP per 5 minutes.
// Resets on cold start (acceptable for serverless).
const rateLimitMap = new Map<string, number>();
const RATE_LIMIT_MS = 5 * 60 * 1000;

interface ReportMetadata {
  bookTitle: string;
  pageCount: number;
  missingIndices: number[];
  format: string;
  style: string;
  textProvider: string;
  imageProvider: string;
  userNotes?: string;
  appVersion: string;
  osVersion: string;
  deviceModel: string;
}

export async function POST(request: Request) {
  try {
    // Rate limit by IP
    const ip =
      request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
      "unknown";
    const lastRequest = rateLimitMap.get(ip);
    if (lastRequest && Date.now() - lastRequest < RATE_LIMIT_MS) {
      return NextResponse.json(
        { error: "Please wait a few minutes before submitting another report." },
        { status: 429 }
      );
    }

    const formData = await request.formData();

    // Parse metadata
    const metadataRaw = formData.get("metadata");
    if (!metadataRaw || typeof metadataRaw !== "string") {
      // metadata could be a File if sent with filename
      let metadataStr: string;
      if (metadataRaw instanceof File) {
        metadataStr = await metadataRaw.text();
      } else {
        return NextResponse.json(
          { error: "Missing metadata field." },
          { status: 400 }
        );
      }
      return await processReport(metadataStr, formData, ip);
    }

    return await processReport(metadataRaw, formData, ip);
  } catch (err) {
    console.error("Report submission error:", err);
    return NextResponse.json(
      { error: "Something went wrong. Please try again." },
      { status: 500 }
    );
  }
}

async function processReport(
  metadataStr: string,
  formData: FormData,
  ip: string
) {
  let metadata: ReportMetadata;
  try {
    metadata = JSON.parse(metadataStr);
  } catch {
    return NextResponse.json(
      { error: "Invalid metadata JSON." },
      { status: 400 }
    );
  }

  // Validate required fields
  if (
    !metadata.bookTitle ||
    metadata.pageCount == null ||
    !metadata.missingIndices ||
    !metadata.format ||
    !metadata.style ||
    !metadata.textProvider ||
    !metadata.imageProvider ||
    !metadata.appVersion
  ) {
    return NextResponse.json(
      { error: "Missing required metadata fields." },
      { status: 400 }
    );
  }

  // Parse zip file
  const zipFile = formData.get("report");
  if (!zipFile || !(zipFile instanceof File)) {
    return NextResponse.json(
      { error: "Missing report zip file." },
      { status: 400 }
    );
  }

  // Size guard
  if (zipFile.size > MAX_ZIP_SIZE) {
    return NextResponse.json(
      { error: `Report zip exceeds ${MAX_ZIP_SIZE / 1024 / 1024} MB limit.` },
      { status: 400 }
    );
  }

  // Generate a unique blob path
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const shortId = crypto.randomUUID().slice(0, 8);
  const blobPath = `reports/${timestamp}-${shortId}.zip`;

  // Upload to Vercel Blob
  const blob = await put(blobPath, zipFile, {
    access: "public",
    contentType: "application/zip",
  });

  // Insert metadata into Neon
  const sql = neon(process.env.DATABASE_URL!);

  // Format missing_indices as a Postgres array literal
  const missingArrayLiteral = `{${metadata.missingIndices.join(",")}}`;

  await sql`
    INSERT INTO storybook_reports (
      book_title, page_count, missing_indices, format, style,
      text_provider, image_provider, user_notes,
      blob_url, blob_size_bytes,
      app_version, os_version, device_model
    ) VALUES (
      ${metadata.bookTitle},
      ${metadata.pageCount},
      ${missingArrayLiteral}::int[],
      ${metadata.format},
      ${metadata.style},
      ${metadata.textProvider},
      ${metadata.imageProvider},
      ${metadata.userNotes ?? null},
      ${blob.url},
      ${zipFile.size},
      ${metadata.appVersion},
      ${metadata.osVersion ?? null},
      ${metadata.deviceModel ?? null}
    )
  `;

  // Record rate limit
  rateLimitMap.set(ip, Date.now());

  return NextResponse.json({ success: true });
}
