# Magic-link token lifecycle

Linear: **DEV-31 — Security hardening**.

The API exposes two families of unauthenticated, capability-bearing URLs
("magic links"). The token *is* the credential — possession grants access to
the associated case — so this document records how each is minted, validated,
expired and revoked, and the rationale for the single-use / reusable choices.

## Token generation

Both token types are generated with `crypto.randomBytes(32).toString("base64url")`
— 256 bits of entropy, URL-safe. This is the primary defence: the keyspace is
far too large to brute-force, which is why the rate limiter (see the hardening
checklist) is defence-in-depth rather than the main control.

- `services/register-patient.ts` → `newToken()` (intake links)
- `services/portal-links.ts` → `newPortalToken()` (portal links)

Insertion retries up to 3x on a unique-constraint collision (astronomically
unlikely, but handled).

## Intake links (`case_intake_links`)

- **Purpose:** let a parent open and submit the intake form for one case.
- **TTL:** 14 days (`LINK_TTL_DAYS`). `expiresAt = createdAt + 14d`.
- **Resolution:** `resolveIntakeLinkToken(db, token)` does an indexed lookup by
  token, then a pure expiry check (`resolveIntakeLinkState`).
- **Revocation:** `revokeIntakeLinks` sets `expiresAt = now`, so a revoked link
  surfaces as `expired` (410) by design — there is no separate `revoked` state
  for intake links.
- **`usedAt` semantics — NOT single-use.** On first successful resolve we stamp
  `usedAt` if it is null, but we do **not** reject subsequent resolves while the
  link is still within its TTL. Rationale: the intake flow is multi-visit — a
  parent saves a draft, closes the tab, and returns later (possibly from a
  different device) to finish. Enforcing single-use would lock them out
  mid-form. `usedAt` is therefore a *first-touch timestamp* for analytics/audit,
  not an access gate. The real bound on the link's validity is the 14-day TTL
  plus explicit revocation. Idempotency of the underlying writes (draft upsert,
  submission state machine) is what protects against replay, not single-use of
  the link.

## Portal links (`case_portal_links`)

- **Purpose:** family carryover portal — view the published summary, resources
  and progress log, and post progress updates.
- **TTL:** 90 days (`PORTAL_LINK_TTL_DAYS`). Longer than intake because the
  portal is a durable, ongoing artefact for the family.
- **Resolution:** `resolvePortalLink(db, token)` — indexed lookup by token, then
  `resolvePortalLinkState`.
- **Revocation:** explicit. `revokePortalLinks` sets `revokedAt = now`. The
  state check returns `revoked` (410) and revocation **wins over** expiry so the
  family sees the more meaningful reason.
- **Reusable until expiry/revocation** — by design, the same link is used across
  many visits over the 90-day window.

## Constant-time comparison — reviewed, no change needed

The task asked to add `crypto.timingSafeEqual` where appropriate. After review:

- Both tokens are matched by a **parameterised, indexed SQL equality lookup**
  (`WHERE token = $1`). This is **not** a per-byte string comparison in
  application code, so it is not the classic JS `===` timing oracle. The compare
  happens inside Postgres against a B-tree index; it does not leak a usable
  byte-by-byte timing signal to a remote attacker, and the 256-bit keyspace
  makes a timing side-channel infeasible regardless.
- There is **no in-code secret string comparison** anywhere on the token path
  (e.g. no `if (provided === stored)`), so there is nothing to convert to
  `timingSafeEqual`. Adding it here would be cargo-culting — `timingSafeEqual`
  protects in-process byte comparisons, not DB index lookups.
- **Conclusion:** the token comparison is already safe; no code change. If a
  future change introduces an in-process compare of a secret (e.g. an HMAC of a
  webhook payload, a static API key), use `crypto.timingSafeEqual` there.

## Audit coverage (added in DEV-31)

Successful resolves were already audited (`portal.viewed`). Failed resolves were
silent. Added:

- `intake_link.resolve_failed` (metadata `{ reason: not_found | expired }`)
- `portal_link.resolve_failed` (metadata `{ reason: not_found | revoked | expired }`)

The token is **never** written to the audit log (it is the secret). For unknown
tokens there is no tenant/case context, so the event is recorded without those
IDs. These events make brute-force / scanning attempts visible in the audit
trail and feed any future alerting.
