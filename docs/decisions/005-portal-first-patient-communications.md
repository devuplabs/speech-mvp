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
