# ADR 005 — Portal-first parent summary (Epic/MyChart model)

**Status:** Accepted  
**Date:** 2026-05-20  
**Supersedes:** Postmark / third-party ESP for parent summary body content

## Context

- Parent summaries contain health-related content (special category data UK; PHI US).
- GCP has no transactional email API under the Cloud BAA.
- Postmark will not sign a HIPAA BAA.
- Industry norm (Epic MyChart, Cerner patient portal, banking alerts): **notify optionally; deliver content in authenticated portal**.

## Decision

1. **Publish** parent summary to the app/API (DB draft + optional GCS export later).
2. **GET** `/v1/cases/:caseId/parent-summary` returns HTML for parent view after `summary_sent`.
3. **No third-party ESP** in MVP demo path.
4. Email/SMS (notification-only, no clinical body) may be added later behind a separate ADR.

## Consequences

- Clinician **Publish** replaces **Send email** in UX.
- Demo uses case ID as parent access token (real magic links in a later auth ADR).
- Deferred: Postmark credentials, GCS signed URLs, FCM push nudges.

## Related

- [`docs/mvp-brief.md`](../mvp-brief.md) — parent summary capability
- [`docs/architecture-gcp-hipaa.md`](../architecture-gcp-hipaa.md) §4.5 email row (update when ESP chosen)

## Update (2026-06-07) — email is notification-only, permanently

Two clarifications that **strengthen** this ADR:

1. **Provider:** the repo's **transactional** email provider (clinician invites — no
   PHI) is now **Mailgun (Sinch)**, wired in `apps/api/src/services/mailgun.ts` and
   Terraform. The original "Postmark will not sign a HIPAA BAA" rationale is kept as the
   historical record.
2. **Hard design rule (not a temporary workaround):** **PHI / clinical content is never
   sent by email, regardless of any BAA/DPA the provider signs.** Email is always
   *notification-only* — e.g. "a report is ready" + a sign-in link — and the content is
   rendered only in the authenticated portal. So item 4 above ("Email/SMS notification-
   only, no clinical body") is the **permanent** stance, not something that relaxes once
   a DPA is executed. A BAA/DPA remains preferred for email **metadata** (recipient
   address, timing), but is not a gate to ever putting clinical content in email — that
   simply never happens.

Enforced in code: `apps/api/src/services/email.ts` exposes only notification-style
senders (the clinician invite); there is no function that emails an arbitrary clinical
body. Any future notification email ships behind its own ADR following this rule.
