import { neon } from "@neondatabase/serverless";

export interface PremiumConfig {
  enabled: boolean;
  textModel: string;
  textModelPlus: string;
  imageModel: string;
  imageQuality: string;
  imageModelPlus: string;
  imageQualityPlus: string;
}

const DEFAULTS: Omit<PremiumConfig, "enabled"> = {
  textModel: "gpt-5-mini",
  textModelPlus: "gpt-5.2",
  imageModel: "gpt-image-1-mini",
  imageQuality: "low",
  imageModelPlus: "gpt-image-1.5",
  imageQualityPlus: "medium",
};

/**
 * Whether the premium feature is enabled at the infrastructure level.
 * Controlled by the `PREMIUM_ENABLED` env var (defaults to true).
 */
function isPremiumEnabled(): boolean {
  return process.env.PREMIUM_ENABLED !== "false";
}

/**
 * Resolve the active premium config.
 *
 * Resolution order:
 *   1. `premium_config` table in Neon (singleton row, updated by admin UI)
 *   2. `PREMIUM_CONFIG` env var (JSON string — set in Vercel dashboard)
 *   3. Static defaults
 *
 * The `enabled` field always comes from the `PREMIUM_ENABLED` env var.
 */
export async function getPremiumConfig(): Promise<PremiumConfig> {
  const enabled = isPremiumEnabled();

  // 1. Try Neon DB
  try {
    if (process.env.DATABASE_URL) {
      const sql = neon(process.env.DATABASE_URL);
      const rows = await sql`
        SELECT
          text_model,
          COALESCE(text_model_plus, ${DEFAULTS.textModelPlus}) AS text_model_plus,
          image_model,
          image_quality,
          COALESCE(image_model_plus, ${DEFAULTS.imageModelPlus}) AS image_model_plus,
          COALESCE(image_quality_plus, ${DEFAULTS.imageQualityPlus}) AS image_quality_plus
        FROM premium_config WHERE id = 1
      `;
      if (rows.length > 0) {
        return {
          enabled,
          textModel: rows[0].text_model,
          textModelPlus: rows[0].text_model_plus,
          imageModel: rows[0].image_model,
          imageQuality: rows[0].image_quality,
          imageModelPlus: rows[0].image_model_plus,
          imageQualityPlus: rows[0].image_quality_plus,
        };
      }
    }
  } catch {
    // Fall through to env var / defaults
  }

  // 2. Try env var override
  if (process.env.PREMIUM_CONFIG) {
    try {
      const parsed = JSON.parse(process.env.PREMIUM_CONFIG) as Partial<PremiumConfig>;
      return { enabled, ...DEFAULTS, ...parsed };
    } catch {
      // Malformed JSON — fall through
    }
  }

  // 3. Static defaults
  return { enabled, ...DEFAULTS };
}

/**
 * Persist a new premium config to Neon.
 * Used by the admin config POST endpoint.
 */
export async function setPremiumConfig(
  config: Omit<PremiumConfig, "enabled">
): Promise<void> {
  const sql = neon(process.env.DATABASE_URL!);
  await sql`
    UPDATE premium_config
    SET text_model = ${config.textModel},
        text_model_plus = ${config.textModelPlus},
        image_model = ${config.imageModel},
        image_quality = ${config.imageQuality},
        image_model_plus = ${config.imageModelPlus},
        image_quality_plus = ${config.imageQualityPlus},
        updated_at = now()
    WHERE id = 1
  `;
}

/** Available model choices for the admin UI. */
export const TEXT_MODELS = ["gpt-5-mini", "gpt-5.2"] as const;
export const IMAGE_MODELS = ["gpt-image-1-mini", "gpt-image-1.5"] as const;
export const IMAGE_QUALITIES = ["low", "medium", "high"] as const;
