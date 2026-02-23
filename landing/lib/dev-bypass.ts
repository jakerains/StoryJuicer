/**
 * Checks if a request carries a valid dev bypass secret.
 *
 * When `PREMIUM_ENABLED=false` (or `DEBUG_ENABLED=false`) on production,
 * the developer can still use these features by sending the bypass secret
 * in an `X-Dev-Bypass` header. The secret is set as `DEV_BYPASS_SECRET`
 * in both Vercel env vars and `.env.local`.
 */
export function hasDevBypass(request: Request): boolean {
  const secret = process.env.DEV_BYPASS_SECRET;
  if (!secret) return false;

  const header = request.headers.get("x-dev-bypass") ?? "";
  return header === secret;
}
