# Security hardening — threat-surface checklist

Linear: **DEV-31 — Security hardening: rate limiting, headers, token lifecycle,
dependency audit.**

Status legend: **done** · **deferred** (with reason) · **human-action** (needs
repo-admin / infra access this agent does not have).

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Rate limiting on token endpoints | **done** | Per-IP fixed-window limiter (`src/rate-limit.ts`) applied to `GET /v1/intake-links/:token`, `GET /v1/portal/:token`, `POST /v1/portal/:token/progress`. Returns `429` with `{error:"rate_limited", retryAfterSeconds}` + `Retry-After`. Configurable via `RATE_LIMIT_TOKEN_MAX` (30), `RATE_LIMIT_TOKEN_WINDOW_MS` (60000), `RATE_LIMIT_ENABLED`. |
| 1a | Distributed / prod-grade rate limiting | **deferred** | In-memory limiter only protects a single Cloud Run instance and resets on cold start. Prod story = **Cloud Armor** rate-based rules at the edge and/or a shared-store limiter. Deliberately **no Redis dependency** added for v1. |
| 1b | Client-IP extraction behind Cloud Run | **done** | Left-most `x-forwarded-for` hop (`clientIpFromHeaders`), fallback `x-real-ip`. Spoofing caveat documented in `src/rate-limit.ts`: good for coarse abuse mitigation, not for authz. |
| 2 | Constant-time token comparison | **done (no code change — by design)** | Tokens are matched by indexed SQL equality, not in-code string compare, so there is no JS timing oracle and nothing to convert to `crypto.timingSafeEqual`. 256-bit token entropy is the real control. Full rationale in `token-lifecycle.md`. |
| 3 | Security response headers (API) | **done** | `src/security-headers.ts`, app-wide in `index.ts`: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`, restrictive `Content-Security-Policy` (`default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'`), `Cross-Origin-Resource-Policy: same-origin`, and **HSTS in production only**. Does not touch `Access-Control-*` (CORS unaffected). |
| 3a | Web-bundle CSP (Flutter SPA) | **human-action** | The browser app is served by a **separate static host**, so its CSP belongs in that hosting config (Firebase Hosting `headers` / static server in front of `apps/sona/build/web`), not in the API. The API CSP above does not constrain it. Owner: web hosting / infra. |
| 4 | CORS tightening | **done** | Confirmed `CORS_ALLOW_LOCALHOST` only applies when `NODE_ENV=development`; prod origins come solely from `CORS_ORIGINS`. Never reflects arbitrary origins. New tests in `__tests__/cors.test.ts` cover dev-localhost-allowed, prod-origin-allowed/denied, and the prod-localhost-denied invariant. |
| 5 | Token lifecycle review | **done** | `docs/security/token-lifecycle.md`: intake-link 14d TTL (reusable, `usedAt` = first-touch, not single-use — rationale documented), portal-link 90d TTL + explicit revocation. |
| 5a | Failed-token-resolve audit events | **done** | Added `intake_link.resolve_failed` and `portal_link.resolve_failed` audit events (reason in metadata; token never logged). Previously only successful resolves were audited. |
| 6 | Dependabot config | **done** | `.github/dependabot.yml`: npm (`apps/api`, `e2e`), pub (`apps/sona`), github-actions; weekly. |
| 6a | `npm audit` CI gate | **done** | New `npm-audit` job in `.github/workflows/ci.yml` running `npm audit --omit=dev --audit-level=high` for `apps/api` and `e2e` (fails on high/critical in **runtime** deps — what ships to Cloud Run). |
| 6a-i | Existing runtime advisories cleared | **done** | `shell-quote` (critical) fixed via non-breaking `npm audit fix`; `drizzle-orm` (high — SQL injection via improperly escaped identifiers) fixed by bumping `drizzle-orm` 0.40→0.45 and `drizzle-kit` 0.30→0.31. Typecheck + all unit tests pass on the new versions; runtime migrations use a hand-rolled SQL runner unaffected by the drizzle-kit bump. |
| 6a-ii | Dev-toolchain advisories | **deferred** | Remaining high advisories are in dev-only tooling (`vitest`/`vite`/`esbuild`), needing a vitest 4 major bump. They never ship to prod, so they are intentionally excluded from the blocking gate (`--omit=dev`) and left to Dependabot to PR. |
| 6b | GitHub secret-scanning + push protection | **human-action** | Repo-admin only — cannot be enabled from a code change. Enable in repo Settings → Code security & analysis → *Secret scanning* and *Push protection*. |
| 6c | Dependabot security updates / alerts | **human-action** | The `dependabot.yml` covers version updates; **security alerts** + Dependabot security updates are a repo-admin toggle (Settings → Code security & analysis). |
| 7 | Threat-surface checklist | **done** | This document. |

## Residual risks / follow-ups (human / infra)

- **Edge rate limiting (Cloud Armor):** wire up rate-based rules for the public
  API once it is fronted by a load balancer; the in-memory limiter is a stopgap.
- **Secret scanning / push protection:** enable in repo settings (6b).
- **Dependabot security alerts:** enable in repo settings (6c).
- **Web-bundle CSP:** add to the Flutter web hosting config (3a).
- **WAF / bot management** for the parent-facing endpoints is out of scope for
  v1 and tracked separately.
