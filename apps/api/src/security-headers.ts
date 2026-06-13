import type { MiddlewareHandler } from "hono";
import type { Env } from "./config.js";

/**
 * App-wide security response headers for the API.
 *
 * The API serves JSON (and a couple of binary/HTML responses for PDFs and the
 * parent-summary view). These headers harden those responses. The browser
 * single-page app (Flutter web) is served separately by its own static host,
 * so the *web bundle* CSP belongs in that hosting config (e.g. Firebase
 * Hosting `headers` / a Cloud Run static server), NOT here. See
 * docs/security/hardening-checklist.md.
 *
 * Care is taken not to interfere with CORS: none of these headers touch the
 * `Access-Control-*` family, which the cors() middleware owns.
 */
export function securityHeaders(env: Env): MiddlewareHandler {
  const isProd = env.NODE_ENV === "production";

  // A restrictive CSP for API responses. The API does not serve an HTML app,
  // so we lock everything down to 'none' and forbid framing. `frame-ancestors
  // 'none'` is the modern replacement for X-Frame-Options (kept for older
  // browsers). This does not constrain the separately-hosted web bundle.
  const csp = [
    "default-src 'none'",
    "frame-ancestors 'none'",
    "base-uri 'none'",
    "form-action 'none'",
  ].join("; ");

  return async (c, next) => {
    await next();

    c.header("X-Content-Type-Options", "nosniff");
    c.header("X-Frame-Options", "DENY");
    c.header("Referrer-Policy", "no-referrer");
    c.header("Content-Security-Policy", csp);
    c.header("Cross-Origin-Resource-Policy", "same-origin");

    // HSTS only in production: forcing HTTPS upgrades on http://localhost during
    // development would break local testing. Cloud Run terminates TLS so the
    // edge is always HTTPS in prod.
    if (isProd) {
      c.header(
        "Strict-Transport-Security",
        "max-age=31536000; includeSubDomains; preload",
      );
    }
  };
}
