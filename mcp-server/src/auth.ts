import { timingSafeEqual } from "node:crypto";

/**
 * Checks an incoming `Authorization` header against the expected bearer
 * token using a constant-time comparison (`timingSafeEqual`) rather than
 * `===`, so a byte-by-byte early-exit string comparison can't be used to
 * incrementally guess the token via response-timing differences. Only
 * matters because this guards a real public HTTP endpoint (Render
 * deployment); the stdio transport used for local Claude Code/Desktop
 * usage has no equivalent network-facing auth surface.
 */
export function checkBearerToken(
  authorizationHeader: string | undefined | null,
  expectedToken: string,
): boolean {
  if (!authorizationHeader?.startsWith("Bearer ")) return false;
  const provided = authorizationHeader.slice("Bearer ".length);

  const providedBuf = Buffer.from(provided);
  const expectedBuf = Buffer.from(expectedToken);
  // timingSafeEqual throws if lengths differ, and a length mismatch is
  // itself fine to reveal quickly (it doesn't leak anything about the
  // token's content, just that it's the wrong length).
  if (providedBuf.length !== expectedBuf.length) return false;

  return timingSafeEqual(providedBuf, expectedBuf);
}
