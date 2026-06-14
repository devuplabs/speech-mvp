# Audit-log retention & append-only enforcement (DEV-25)

**Owner:** Data Protection lead (practice admin) · **Implements:** DEV-25
**Code:** `apps/api/src/services/audit.ts`, `apps/api/src/services/audit-retention.ts`,
`apps/api/drizzle/0009_audit_append_only.sql`, routes in `apps/api/src/routes/v1.ts`.

The `audit_log` table is the accountability spine for a healthcare app: it must
record **who accessed or changed which record, and when**, and it must be
**tamper-evident** and **retained** for a defined period. This document covers
the three controls added in DEV-25 and complements the DSAR runbook
(`docs/compliance/dsar-runbook.md`).

---

## 1. Read-access auditing (coverage of record views)

GDPR/HCPC require an access trail, not just a change trail. Every PHI-bearing
GET writes a `*.viewed`/`*.downloaded` access event via `writeViewAudit`
(metadata is **IDs/counts only — never PHI**):

| Endpoint | Action | Actor |
|---|---|---|
| `GET /v1/cases/:caseId` | `case.viewed` (was DEV-5; now de-duped) | clinician |
| `GET /v1/tenants/:tenantId/intake-submissions` | `intake.viewed` | clinician |
| `GET /v1/cases/:caseId/clinical-report` | `clinical_report.viewed` | clinician |
| `GET /v1/cases/:caseId/clinical-report.pdf` | `clinical_report.downloaded` | clinician |
| `GET /v1/cases/:caseId/parent-summary` | `parent_summary.viewed` | parent |
| `GET /v1/portal/:token` | `portal.viewed` (was DEV-6; now de-duped) | parent |

### De-dupe / sampling choice

Read auditing is noisy (one record open can issue several reads; a clinician may
refresh repeatedly). Recording one row per HTTP GET would bury the signal and
bloat the trail. **Choice:** collapse repeated identical accesses to **one event
per `(actor, caseId, action)` per 5-minute window** (`VIEW_AUDIT_DEDUPE_WINDOW_MS`
in `services/audit.ts`). Tenant-scoped list views (no single case) de-dupe on
`(tenant, actor, action)`. This still answers "did actor X access record Y around
time T" while keeping volume sane — a continuous viewing session yields a
heartbeat of one row every 5 minutes, not one per click. **Mutations are never
de-duped**; only `*.viewed`/`*.downloaded` access events use the guard.

---

## 2. Append-only enforcement

`audit_log` is append-only at the **database** layer (migration
`0009_audit_append_only.sql`), with two complementary layers of defence:

1. **A `BEFORE UPDATE OR DELETE` trigger** (`audit_log_append_only`) that
   `RAISE`s an exception — the **authoritative** control. A trigger fires even
   for the table owner and a superuser, so it holds regardless of how the app
   role is provisioned. This is the layer that governs `sona_app` (which owns the
   schema in Cloud SQL) and is what the integration test proves.
2. **`REVOKE UPDATE, DELETE ON audit_log FROM PUBLIC`** — a privilege-level
   backstop for every **non-owner** role (e.g. a future read-only
   reporting/analytics role). We deliberately do **not** revoke from the owner
   `sona_app`: PostgreSQL checks table privileges *before* firing the trigger, so
   revoking from the owner would raise "permission denied" and **block the
   legitimate escape-hatch UPDATE/DELETE** that DSAR erasure and retention need.
   The trigger governs the owner; the REVOKE governs everyone else.

`INSERT` is never restricted — the app keeps writing audit events normally.

### Reconciling append-only with DSAR erasure (the key design call)

DSAR right-to-erasure (DEV-24) **must** scrub PHI from `audit_log.metadata` and
detach `case_id` on the retained accountability rows (it UPDATEs them). A blanket
UPDATE block would break erasure. We chose **option (b): a narrow, audited escape
hatch in the trigger** rather than running erasure as a higher-privileged role:

- The trigger allows an `UPDATE` only when the transaction has set
  `SET LOCAL sona.audit_scrub = 'on'`, and a `DELETE` only when
  `SET LOCAL sona.audit_retention = 'on'`.
- `SET LOCAL` is **transaction-scoped**, so the escape hatch cannot leak onto a
  pooled connection after commit, and only two code paths ever set it:
  `scrubCaseAuditMetadata` (DSAR erasure, `services/dsar.ts`) and
  `purgeExpiredAuditRows` (retention, `services/audit-retention.ts`).

This keeps erasure working (its tests still pass) while everything else — any
stray app UPDATE/DELETE, or an attacker with the app role — is blocked.

---

## 3. Retention (7 years)

**Policy:** audit rows are retained for **7 years** (`AUDIT_RETENTION_YEARS`),
then deleted. Seven years is the conservative retention for this PHI-free
accountability trail. Note this is distinct from clinical *record* retention
(HCPC: typically a child's record until their 25th/26th birthday) — that longer
duty is enforced on the **case** via the legal-hold mechanism (DEV-24), not here.

**Mechanism:** `purgeExpiredAuditRows(db, { dryRun })` in
`services/audit-retention.ts` deletes rows with `created_at` older than the
cutoff, using the `sona.audit_retention` escape hatch (§2). It **defaults to a
dry run** (count only) so the destructive path must be opted into. It is exposed
as `POST /v1/admin/audit-log/retention-purge` (`?apply=true` to delete; the
purge is itself audited as `audit_log.retention_purged`).

**Automated vs runbooked (v1):**

- **Automated:** the deletion *mechanism* (the guarded routine + endpoint) and
  its tests.
- **Runbooked (not yet auto-scheduled):** the periodic invocation. For v1, run
  the purge on a documented cadence (quarterly is ample for a 7-year window):
  1. Dry run: `POST /v1/admin/audit-log/retention-purge` → review the `deleted`
     count and `cutoff`.
  2. (Optional) archive rows older than the cutoff to cold storage (BigQuery /
     GCS) before deletion if long-term cold retention is later required.
  3. Apply: `POST /v1/admin/audit-log/retention-purge?apply=true`.

  When ready to automate, point a **Cloud Scheduler** job at the endpoint with
  the scheduler's service identity (and complete the `TODO(DEV-31/auth)` gate so
  the endpoint requires that identity). No new infrastructure is required beyond
  the scheduler job.
