# DSAR & Right-to-Erasure Runbook (UK GDPR Art. 15 / Art. 17)

**Owner:** Data Protection lead (practice admin) · **Implements:** DEV-24
**Code:** `apps/api/src/services/phi-registry.ts`, `apps/api/src/services/dsar.ts`,
routes in `apps/api/src/routes/v1.ts`.

This runbook covers how Sona handles two data-subject rights for a **case** (the
data subject is the family of one case — the child and their parent/carer):

- **Subject Access Request (DSAR)** — UK GDPR **Article 15** (right of access).
- **Right to erasure** ("right to be forgotten") — UK GDPR **Article 17**.

> **SLA:** Both requests must be actioned **within one calendar month** of
> receipt (UK GDPR). The month may be extended by up to two further months for
> complex/numerous requests — if you extend, you must tell the requester within
> the first month and explain why. Record the receipt date and the action date
> in the case file.

---

## 1. The PHI registry — single source of truth

`apps/api/src/services/phi-registry.ts` classifies **every** table in
`db/schema.ts`. Both the export and the erasure routine are driven by it, and a
unit test (`__tests__/phi-registry.test.ts`) **fails CI** if any schema table is
left unclassified. This is the control that stops a future PHI table from
silently escaping export/erasure.

Classifications:

| Classification | Export behaviour | Erasure behaviour | Tables |
|---|---|---|---|
| `case_phi` | exported in full | hard-deleted | `cases`, `intake_submissions`, `triage_records`, `ai_drafts`, `carryover_resources`, `progress_entries` |
| `case_access_credential` | exported **without token values** (existence/expiry/revocation only) | hard-deleted | `case_intake_links`, `case_portal_links` |
| `case_audit` | exported (entries naming the subject) | **retained**, PHI scrubbed, `case_id` detached | `audit_log` |
| `practice_excluded` | **excluded** (not the subject's personal data) | untouched | `tenants`, `users`, `clinician_availability` |

**Aligned with the FHIR ADR (`docs/decisions/006-fhir-r4-uk-core-alignment.md`).**
The DSAR export is *broader* than the FHIR export (it includes everything the
subject is entitled to, including unreviewed AI drafts and the audit trail) but
shares the hard rules: **secret token values are never disclosed**, and other
tenants' data is never included.

---

## 2. Handling a Subject Access Request (Art. 15)

1. **Verify identity** of the requester (parent/carer) out of band before
   releasing any data. Do not action a request you cannot attribute.
2. **Locate the case** (`caseId`).
3. **Generate the bundle:**
   `GET /v1/cases/:caseId/dsar-export` → a complete JSON bundle:
   - `meta` — caseId, tenantId, generated timestamp, the list of excluded
     sections **with reasons**, and explanatory notes.
   - `sections` — `case`, `intakeSubmissions`, `triageRecords`, `aiDrafts`
     (including the published parent summary), `carryoverResources`,
     `progressEntries`, the access-credential links (token-redacted), and the
     `auditLog` entries for the case.
4. **Deliver** the bundle to the verified requester via a secure channel.
5. The export is itself audited (`dsar.exported`).

**What is excluded and why** (also stated in the bundle's `meta.excluded`):
- `tenants` / `users` / `clinician_availability` — practice/clinician/scheduling
  records, **not** the data subject's personal data.
- **Magic-link token values** (intake & portal) — secret credentials. The links
  are represented by existence, expiry and revocation state; disclosing the raw
  token would be a security defect (and would let anyone impersonate the family).

**Printable artefacts:** the existing clinical-report PDF
(`GET /v1/cases/:caseId/clinical-report.pdf`) can accompany the JSON where a
report exists; JSON is the authoritative, complete export.

---

## 3. Handling a Right-to-Erasure request (Art. 17)

Erasure is **two-step** and **admin-only** (operationally; see auth note below):

1. **Check for a hold first** (see §4). If the case is under a retention/legal
   hold, erasure is refused — explain the exemption to the requester.
2. **Request:** `POST /v1/cases/:caseId/erasure/request`
   - Refuses with `409 legal_hold` (and the reason) if a hold is in place.
   - Otherwise returns a short-lived (`60 min`) confirmation **token**.
3. **Confirm:** `POST /v1/cases/:caseId/erasure/confirm` with `{ "token": "…" }`
   - Re-checks the hold (defence in depth).
   - Validates the token (matched by fingerprint against the outstanding
     `erasure.requested` audit event; expired/unknown tokens are rejected `400`).
   - **Hard-deletes** all `case_phi` and `case_access_credential` rows for the
     case across the registry, then deletes the `cases` row.
   - **Retains** the audit trail (see §5) and writes an anonymised
     `case.erased` tombstone (actor + timestamp + deletion counts, **no PHI**).
4. **Confirm to the requester** that erasure is complete. After erasure, the case
   is not retrievable via any case or portal endpoint (verified by the e2e spec).

The whole flow is heavily audited: `erasure.requested`, `erasure.confirm_failed`,
`erasure.refused_legal_hold`, and the `case.erased` tombstone.

---

## 4. Retention / legal hold (HCPC duty & exemptions)

UK GDPR Art. 17(3) does **not** require erasure where processing is necessary for
compliance with a legal obligation or for the establishment/exercise/defence of
legal claims. For an SLT practice the most common reasons to refuse are:

- **HCPC clinical-record retention** — registrants must keep clinical records for
  the period required by their professional standards / employer policy
  (children's records are typically kept until the patient's 25th birthday, or
  26th if the last entry was made at 17; follow your retention schedule).
- An **open complaint, claim or litigation** touching the case.

**Mechanism:** the `cases.legal_hold` boolean (+ `legal_hold_reason`), set via
`POST /v1/cases/:caseId/legal-hold` `{ "hold": true, "reason": "…" }`. While a
hold is set, **both erasure steps refuse with a clear `legal_hold` error and the
reason** — never a silent no-op. Lift the hold (`{ "hold": false }`) only when the
retention duty has genuinely expired, then erasure may proceed.

Document, in the case file, the basis for any refusal and the date the hold may be
reviewed.

---

## 5. Audit retention vs. erasure — the decision

**We retain the audit trail after erasure (with PHI removed), rather than deleting
it.**

- **Why retain:** UK GDPR Art. 5(2) (accountability) and our security/incident
  obligations require us to be able to demonstrate *what processing happened* —
  including *that* an erasure was carried out, by whom and when. A minimal,
  PHI-free record of processing is itself a lawful basis to keep the audit rows;
  deleting the audit trail would defeat accountability and the erasure tombstone.
- **What we remove:** on confirm we **scrub `audit_log.metadata`** down to an
  allowlist of non-PHI keys (status/outcome/kind/ids/counts/etc.), set
  `phiScrubbed: true`, and **detach the row from the case** (`case_id → NULL`,
  original id preserved as `erasedCaseId` in metadata so the trail remains
  coherent without re-linking to deleted PHI). The `actor`/`action`/timestamp
  spine is never altered.
- **The tombstone:** a single anonymised `case.erased` audit row records the
  actor, timestamp and per-table deletion counts — **no PHI**.

**Net position:** the subject's *personal data* is genuinely gone (no name,
contact details, intake answers, drafts, summaries, progress notes, or tokens
remain anywhere), while an honest, minimal, PHI-free record that processing —
and erasure — occurred is preserved. This balances Art. 17 against Art. 5(2).

---

## 6. Auth note (MVP posture)

The case API is currently **unauthenticated-by-design** for the MVP (same posture
as triage/carryover). The DSAR/erasure/legal-hold routes match that posture and
are tagged `TODO(DEV-31/auth)`. Before these endpoints are exposed beyond the
demo environment they **must** be gated: export → admin/clinician; erasure and
legal-hold → admin-only. The export and every erasure step are audited so actions
remain attributable in the interim.
