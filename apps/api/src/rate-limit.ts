import type { MiddlewareHandler } from "hono";
import type { Env } from "./config.js";
import { logger } from "./logger.js";

/**
 * In-memory per-IP fixed-window rate limiter for the unauthenticated
 * magic-link token endpoints.
 *
 * SCOPE / PRODUCTION CAVEAT
 * -------------------------
 * This counter lives in process memory, so it only protects a single
 * instance. Cloud Run can run many instances behind one URL, and the counter
 * resets on cold start / redeploy. That is acceptable for v1 / dev as a first
 * line of defence against trivial brute-force and accidental loops, but the
 * production story is an edge limiter (Cloud Armor rate-based rules) and/or a
 * distributed limiter backed by a shared store. We deliberately do NOT add a
 * Redis dependency for this. See docs/security/hardening-checklist.md.
 *
 * CLIENT IP / SPOOFING CAVEAT
 * ---------------------------
 * Behind Cloud Run the original client IP is the FIRST hop of
 * `x-forwarded-for` (Google's front end appends/normalises this header). A
 * client can forge `x-forwarded-for` before it reaches Google's edge, but
 * Google overwrites/normalises the chain such that the left-most entry is the
 * real client for direct requests; we read the left-most entry. This is good
 * enough for coarse abuse mitigation, NOT for authn/z decisions. A determined
 * attacker behind the trusted proxy boundary cannot be perfectly attributed by
 * IP alone — the real defence in depth is the high-entropy 256-bit tokens
 * themselves plus the edge limiter above.
 */

type Bucket = { count: number; resetAt: number };

export type RateLimiterOptions = {
  /** Max requests permitted per IP within the window. */
  max: number;
  /** Window length in milliseconds. */
  windowMs: number;
  /** Logical name used in 429 logs (no PHI, no token). */
  name: string;
};

export type RateLimiter = {
  middleware: MiddlewareHandler;
  /** Exposed for deterministic unit tests. */
  check: (ip: string, now?: number) => { allowed: boolean; retryAfterSeconds: number };
  /** Test seam to reset internal state. */
  reset: () => void;
};

/** Extract the best-effort client IP. See module doc for the spoofing caveat. */
export function clientIpFromHeaders(headers: {
  "x-forwarded-for"?: string | null;
  "x-real-ip"?: string | null;
}): string {
  const xff = headers["x-forwarded-for"];
  if (xff) {
    // Left-most hop is the original client behind Cloud Run / Google front end.
    const first = xff.split(",")[0]?.trim();
    if (first) return first;
  }
  const realIp = headers["x-real-ip"];
  if (realIp && realIp.trim()) return realIp.trim();
  return "unknown";
}

/**
 * Create a fixed-window rate limiter. Buckets are pruned lazily on access and
 * periodically swept to bound memory under churn of distinct IPs.
 */
export function createRateLimiter(options: RateLimiterOptions): RateLimiter {
  const { max, windowMs, name } = options;
  const buckets = new Map<string, Bucket>();
  let lastSweep = 0;

  function sweep(now: number): void {
    // Cheap amortised cleanup: at most once per window.
    if (now - lastSweep < windowMs) return;
    lastSweep = now;
    for (const [ip, bucket] of buckets) {
      if (bucket.resetAt <= now) buckets.delete(ip);
    }
  }

  function check(ip: string, now: number = Date.now()) {
    sweep(now);
    let bucket = buckets.get(ip);
    if (!bucket || bucket.resetAt <= now) {
      bucket = { count: 0, resetAt: now + windowMs };
      buckets.set(ip, bucket);
    }
    bucket.count += 1;
    const allowed = bucket.count <= max;
    const retryAfterSeconds = Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
    return { allowed, retryAfterSeconds };
  }

  const middleware: MiddlewareHandler = async (c, next) => {
    const ip = clientIpFromHeaders({
      "x-forwarded-for": c.req.header("x-forwarded-for") ?? null,
      "x-real-ip": c.req.header("x-real-ip") ?? null,
    });
    const { allowed, retryAfterSeconds } = check(ip);
    if (!allowed) {
      // Never log the IP (could be PII) or the token (in the URL) — just the
      // limiter name and matched route pattern.
      logger.warn("rate_limit.exceeded", {
        kind: name,
        route: c.req.routePath,
        requestId: c.get("requestId"),
      });
      c.header("Retry-After", String(retryAfterSeconds));
      return c.json(
        {
          error: "rate_limited",
          message: "Too many requests. Please slow down and try again shortly.",
          retryAfterSeconds,
        },
        429,
      );
    }
    await next();
  };

  return { middleware, check, reset: () => buckets.clear() };
}

/** Build the token-endpoint limiter from env config. */
export function createTokenRateLimiter(env: Env): RateLimiter {
  return createRateLimiter({
    max: env.RATE_LIMIT_TOKEN_MAX,
    windowMs: env.RATE_LIMIT_TOKEN_WINDOW_MS,
    name: "token_endpoint",
  });
}
