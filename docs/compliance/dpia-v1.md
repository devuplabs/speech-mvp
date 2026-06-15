# Data Protection Impact Assessment (DPIA) — Sona v1 pilot

**Status:** DRAFT — awaiting human sign-off (see §6). Produced for DEV-32.
**Version:** v1.0-draft · **Date drafted:** 2026-06-15
**Regime:** UK GDPR Article 35 / DPA 2018. ICO "Data protection impact assessment" template structure.
**Scope:** Sona ("the product") v1 — the intake → first-session co-pilot described in
[`docs/mvp-brief.md`](../mvp-brief.md). UK jurisdiction stack only (ADR-001). The pilot is a
single solo private-practice SLT (the design partner) with real, consented families.

> **This is a draft for review, not an approved DPIA.** It is honest about residual risk,
> about decisions a human must still make, and about controls that are not yet live. Real
> family data MUST NOT be processed until the open items in §7 are closed and §6 is signed.
> This DPIA must be revisited if processing changes materially (new subprocessor, new data
> category, new purpose, audio/ASR, multi-tenant scale-out, or any change to the AI path).

---

## 1. Screening — is a DPIA required?

**Yes. A DPIA is mandatory.** Under UK GDPR Art. 35(3) and the ICO's list of processing
"likely to result in high risk", Sona triggers *multiple* mandatory criteria, any one of
which alone would require a DPIA:

| Trigger | Present in Sona? | Why |
|---|---|---|
| **Special-category data** (Art. 9 — health) | **Yes** | Clinical intake about a child's speech, language, feeding, development, SEN/EHCP status, hearing/vision. |
| **Data about children / vulnerable subjects** | **Yes** | The data subject receiving care is a child; the cohort is by definition vulnerable. |
| **Innovative technology / AI** | **Yes** | Generative AI (Vertex Gemini) drafts clinical artefacts from the child's PHI (ADR-007). |
| **Large-scale or systematic processing** | Pilot = small scale | Volume is low at pilot, but the *nature* (children's health + AI) already crosses the threshold; scale is not the deciding factor here. |
| **Matching / combining datasets** | No | No profiling-for-decisions, no dataset matching. AI output is advisory only. |

Additional risk factors specific to Sona:

- **Capability-bearing magic links** (the token *is* the credential) for unauthenticated
  parent access to a child's record — interception/enumeration is a real attack surface
  ([`docs/security/token-lifecycle.md`](../security/token-lifecycle.md)).
- **A third party (Google/Vertex) processes the children's PHI** as our processor — not the
  air-gap posture originally envisaged in ADR-003 (ADR-007 accepts this trade-off knowingly).

**Conclusion:** DPIA required and produced (this document). Given children's special-category
data + AI, an **ICO prior-consultation** (Art. 36) is *not* expected to be required provided
the residual risks below are reduced to acceptable by the listed mitigations — but the DPO
must confirm this judgement at sign-off (§6, §7).

---

## 2. Description of the processing

### 2.1 Data subjects

| Subject | Role | Notes |
|---|---|---|
| **The child** | Primary data subject — the patient receiving SLT care. | Special-category (health) data. The child does not interact with the product (Principle #3: no screen time for children). |
| **Parent / carer** | Completes intake, receives the summary, consents on the child's behalf. | Their own contact data + the fact of the relationship. The "data subject" of a case in the DSAR runbook is treated as *the family* (child + parent/carer). |
| **Clinician (and practice admin)** | The treating SLT (design partner) and any practice seat. | Professional data (name, email, role, future HCPC number). Controller-side, not patient data; excluded from DSAR export as the subject's personal data. |

### 2.2 Data categories

| Category | Examples | Class | Where |
|---|---|---|---|
| **Child clinical / intake answers** | Presenting concern, developmental history, milestones, feeding/sensory profile, hearing/vision, languages, SEN/EHCP status, free-text notes | **Special category (Art. 9 health)** | `intake_submissions.answers` (JSONB) |
| **Child identifiers** | Name, date of birth | Personal (identifying a child) | `cases.child_display_name`; DOB is collected in intake answers and (per ADR-006 §5) is a planned structured field |
| **Parent/carer contact** | Email, phone | Personal | `cases.parent_email`, `cases.parent_phone` |
| **Referral / scheduling** | Referral source, consult datetime | Personal (low sensitivity) | `cases.referral_source`, `cases.consult_at` |
| **AI-drafted clinical artefacts** | Prep brief, session plan, parent summary, clinical report | **Derived special category** — clinical content about the child | `ai_drafts.content` (JSONB), gated by `reviewed_at` |
| **Triage decision** | Outcome + free-text reason | Special category (clinical) | `triage_records` |
| **Carryover / progress** | Home-practice resources, parent/clinician progress notes + ratings | Special category (clinical) | `carryover_resources`, `progress_entries` |
| **Consent record** | Consent version captured at intake | Personal (accountability) | `intake_submissions.consent_version` |
| **Access credentials** | Intake & portal magic-link tokens | Secret credential — **never** disclosed/logged/exported as a value | `case_intake_links.token`, `case_portal_links.token` |
| **Audit trail** | Who accessed/changed which record, when | Accountability data (PHI-free by design) | `audit_log` (metadata is IDs/counts only) |

### 2.3 End-to-end data flow

```
Clinician creates a case (referral)
   │   POST /v1/clinicians/me/patients · /v1/cases
   ▼
Magic-link intake invite to parent  ── email is NOTIFICATION-ONLY (link, no PHI) ──► Mailgun
   │   case_intake_links.token (256-bit, 14-day TTL, reusable, rate-limited)
   ▼
Parent opens link, completes branching intake, consents
   │   GET /v1/intake-links/:token · POST /v1/cases/:caseId/intake
   ▼
Postgres (Cloud SQL, europe-west2, UK stack only — ADR-001)   ◄── encrypted at rest/in transit
   │
   ▼   async AI generation (Cloud Tasks → worker)
DATA-MINIMISED prompt built (DEV-53 / apps/api/src/llm/redact.ts):
   names, DOB→age band, address, postcode, email, phone, NHS no. stripped/pseudonymised;
   child name replaced with [CHILD] placeholder, re-inserted in OUR layer after generation
   │
   ▼   Private networking, region-pinned
Vertex AI Gemini (Google = data PROCESSOR) — europe-west2, ZDR, no-training
   │   returns draft; inference logging records model/case/latency only — NO content (ADR-007 §8/§11)
   ▼
ai_drafts.content (DRAFT — clinician must review; reviewed_at gates "record" status)
   │
   ▼   Clinician reviews / edits / signs off (clinician-in-the-loop — AI never autonomous)
Portal-first delivery (ADR-005): summary/report rendered ONLY in the authenticated portal/app
   │   GET /v1/cases/:caseId/parent-summary · clinical-report(.pdf)
   ▼   notification-only email "a summary is ready + sign-in link"  ──► Mailgun
Family views in portal (case_portal_links.token — 256-bit, 90-day TTL, revocable, rate-limited)
   │   Family may post progress; clinician shares carryover resources
   ▼
Out-of-band 20-min video consult ──► Zoom (planned; tele-therapy, not stored by Sona)
```

**Logging:** no PHI is ever logged. The logger ([`apps/api/src/logger.ts`](../../apps/api/src/logger.ts))
drops any field not on a strict allowlist (IDs/counts/route/status only), reduces errors to
name/code/message/stack (never pg `detail`/`parameters` or HTTP bodies), and logs the matched
route pattern (`/v1/intake-links/:token`) never the concrete token-bearing path (DEV-23).

### 2.4 Retention & deletion

| Data | Retention | Mechanism |
|---|---|---|
| Clinical case record | Until the HCPC clinical-record duty expires (children's records typically to the 25th/26th birthday) or an open complaint/claim closes | `cases.legal_hold` blocks erasure; otherwise erasable on request (DEV-24) |
| Audit trail | **7 years**, then purged (PHI-free already) | `purgeExpiredAuditRows` (DEV-25), append-only DB trigger |
| Right of access (Art. 15) | Within 1 calendar month | `GET /v1/cases/:caseId/dsar-export` (DEV-24) |
| Right to erasure (Art. 17) | Within 1 calendar month, subject to legal hold | two-step `erasure/request` → `erasure/confirm`; hard-deletes PHI, retains a PHI-free `case.erased` tombstone (DEV-24) |
| Vertex prompts/responses | **Not retained** by Google (ZDR / abuse-logging exemption — to be confirmed, ADR-007) | Contractual + endpoint config |

See [`docs/compliance/dsar-runbook.md`](dsar-runbook.md) and
[`docs/compliance/audit-retention.md`](audit-retention.md).

### 2.5 Subprocessors

Full published-style list in [`docs/compliance/subprocessors.md`](subprocessors.md). Summary:

| Subprocessor | Role | Data it touches | Region | Safeguard / status |
|---|---|---|---|---|
| **Google Cloud (Cloud SQL, Cloud Run, GCS, Cloud Tasks, Secret Manager)** | Infrastructure / hosting | All PHI at rest & in transit | `europe-west2` | Google Cloud DPA + BAA; CMEK; VPC-SC. Live infra; **DPA/BAA execution = human TODO** |
| **Google Cloud — Vertex AI (Gemini)** | AI inference **processor** | Data-minimised clinical prompts (PHI, reduced) | `europe-west2` | No-training, ZDR, PSC/VPC-SC, CMEK, DPA/BAA (ADR-007, DEV-52). **Not yet fully live — gate item** |
| **Mailgun (Sinch)** | Transactional email | **Metadata only** (recipient address, timing). **Never PHI/clinical content** | EU region preferred | DPA preferred for metadata (DEV-51 scope includes vendor DPAs). Email is notification-only by hard design (ADR-005) |
| **Zoom** | Tele-therapy video for the 20-min consult | Live audio/video of consult (not stored by Sona) | EU data residency to confirm | **Planned**; Unlisted OAuth app; **Zoom DPA = DEV-51, human TODO** |
| **Identity provider** (Firebase Auth / Identity Platform today; **Auth0 planned, DEV-30**) | Clinician authentication | Clinician account identity (no patient PHI) | EU/UK to confirm | Covered by Google Cloud DPA today; if Auth0 is adopted (DEV-30) a separate DPA is required. **See §7 — controller must decide identity provider** |

> **Honesty note:** the repo currently provisions **Firebase Auth / Identity Platform**
> (`infra/terraform/.../firebase_auth`), not Auth0. The DEV-30 "Auth0" item is a *planned*
> identity decision. The DPIA records both; the controller must confirm which identity
> provider ships and ensure its DPA is in place before that provider handles real clinician
> accounts.

---

## 3. Necessity & proportionality

### 3.1 Purpose & lawful basis

**Purpose:** to run the first 30 days of an SLT client relationship — structured pre-consult
intake, consult prep, triage, an AI-drafted (clinician-reviewed) first session plan, and a
parent-friendly summary — reducing clinician admin while keeping every clinical artefact under
clinician control.

| Processing | Art. 6 lawful basis (candidate) | Art. 9 condition for special-category (candidate) |
|---|---|---|
| Intake, triage, planning, summary (core care) | (b) contract / (f) legitimate interests of the practice in delivering care, **and/or** the parent's (a) consent | **(h) provision of health/social care** by/under a health professional bound by confidentiality (HCPC), **or** (a) **explicit consent** |
| AI drafting (Vertex) | Same as core care — AI is a tool used *within* the care purpose, not a separate purpose | Same — covered by the care/consent condition; data is minimised before it reaches the processor |
| Notification email (Mailgun) | (f) legitimate interests / (b) contract | n/a — no special-category content (metadata only) |
| Audit trail | (c) legal obligation / (f) legitimate interests (accountability, Art. 5(2)) | Art. 9(2)(h) ancillary to care; PHI-free anyway |

> **HUMAN DECISION (DPO/controller) — lawful basis:** The Art. 6 basis and especially the
> **Art. 9 condition must be confirmed and documented**. The strongest fit for a regulated
> SLT is **Art. 9(2)(h) (health care provision by a health professional)** *combined with*
> parental consent for the relationship and for the use of AI assistance. If consent is the
> chosen Art. 9 route, it must meet the UK GDPR consent standard (freely given, specific,
> informed, unambiguous, withdrawable) and **parental responsibility** must be verified for a
> child. The intake consent wording is finalised under **DEV-28**. This DPIA does not decide
> the basis; it flags that the controller must.

### 3.2 Data minimisation

- **Intake collects only what triage needs** (mvp-brief privacy stack); branching avoids
  asking irrelevant questions.
- **Prompt minimisation before AI (DEV-53 / ADR-007 safeguard 7):**
  [`apps/api/src/llm/redact.ts`](../../apps/api/src/llm/redact.ts) strips/pseudonymises direct
  identifiers (child/parent names, DOB→age band, address, postcode, email, phone, NHS number)
  from both structured fields and free text before any prompt leaves our service; the child's
  name is sent as `[CHILD]` and re-inserted **in our own layer** after generation, so the real
  identifier never reaches the processor.
- **Logs carry no PHI** (allowlist logger, DEV-23).
- **DSAR/FHIR exports never disclose token values or other tenants' data.**

### 3.3 Purpose limitation

- **No model training on our data** — a hard rule (mvp-brief; ADR-007 safeguard 2) backed by
  the Google AI/ML Privacy Commitment and the DPA.
- **No cross-jurisdiction processing** — UK data stays in the UK stack (ADR-001); the FHIR
  export asserts `jurisdiction = 'uk'` before emitting (ADR-006 §4).
- **No secondary analytics on raw clinical payloads** (ADR-001).
- **Email is notification-only, permanently** — clinical content is never emailed regardless
  of any DPA (ADR-005, enforced in `apps/api/src/services/email.ts`).

### 3.4 Clinician-in-the-loop (proportionality of the AI)

AI **drafts**; the clinician **decides**. Every AI artefact is labelled "DRAFT — clinician must
review", is gated by `ai_drafts.reviewed_at` before it counts as record material (ADR-006), and
is **never auto-sent** (schema comment; ADR-007 safeguard 9). There is no automated decision
producing legal/similarly-significant effects on the data subject (Art. 22 not engaged), because
a human clinician makes every clinical decision.

### 3.5 Individuals' rights

Access, erasure, rectification (clinician edits), portability (FHIR export, ADR-006/DEV-27),
and the right to be informed (privacy notice + consent wording, DEV-28) are all supported. The
DSAR/erasure SLAs and mechanics are documented and tested (DEV-24).

---

## 4. Risks to individuals

Likelihood (L) and Severity (S) each scored **Low / Med / High**; overall risk is the combination.
"Residual" = risk **after** the listed mitigation is fully in place. Several mitigations are not
yet live — those are the §7 gate items, and the residual rating *assumes they are completed*.

| # | Risk to individuals | L | S | Inherent | Mitigation (control) | Tracking | Residual |
|---|---|---|---|---|---|---|---|
| R1 | **Third-party (Vertex) processing of a child's PHI** — Google sees minimised clinical prompts as our processor; not air-gapped | Med | High | **High** | Enterprise Vertex only; no-training; ZDR; region-pinned `europe-west2`; PSC + VPC-SC; CMEK; DPA/BAA; prompt minimisation; clinician-in-loop | DEV-52, DEV-53; ADR-007 | **Med** (residual is the knowing trade-off in ADR-007; cannot be Low while a processor sees any PHI) |
| R2 | **Magic-link interception / enumeration** — token grants access to a child's record | Low | High | **High** | 256-bit tokens (infeasible to brute-force); short TTL (intake 14d / portal 90d) + revocation; per-IP rate limiting on token endpoints; failed-resolve auditing; tokens never logged/exported | DEV-31 | **Low** |
| R3 | **Email metadata exposure / mis-sent notification** — wrong recipient, or metadata reveals a care relationship | Low | Med | **Med** | Email is **notification-only**, no clinical body (ADR-005); content only in authenticated portal; Mailgun DPA for metadata | DEV-51, ADR-005 | **Low** |
| R4 | **AI drafting error / clinician over-reliance** — a wrong or fabricated clinical statement reaches a family | Med | High | **High** | Mandatory clinician review (`reviewed_at` gate); "DRAFT" labelling; AI never auto-sends; eval harness for quality (DEV-15); HCPC accountability stays with clinician | ADR-007 (§9), DEV-15 | **Med** (human error in review is irreducible; bounded by the review gate + labelling) |
| R5 | **Re-identification of "minimised" prompt data** — age band + rich clinical context could re-identify a rare case | Low | Med | **Med** | Direct identifiers stripped/pseudonymised (DEV-53); DOB→coarse age; ZDR (no retention to correlate); processor under no-training + DPA | DEV-53; ADR-007 | **Low–Med** (rare-case residual; acknowledged) |
| R6 | **Cross-tenant data leakage** — one practice sees another's records | Low | High | **High** | Tenant-scoped queries; jurisdiction-pinned DB resolution (ADR-001); automated tenant-isolation tests | DEV-34 | **Low** |
| R7 | **Data breach / unauthorised access** (infra, credential, dependency) | Low | High | **High** | Encryption at rest+in transit; CMEK; least-privilege SAs; security headers; dependency audit CI gate; append-only audit trail; documented 72-hr ICO breach path; pen test pre-scale | DEV-31, DEV-25; pen test (§7) | **Low–Med** (until pen test + prod hardening complete) |
| R8 | **Unauthorised internal access to PHI** — MVP case API is currently unauthenticated-by-design | Med | High | **High** | Read/write access auditing now; **auth gating required before non-demo exposure** (`TODO(DEV-31/auth)`); DSAR/erasure to be admin-gated | DEV-31 (auth), DEV-30 | **Med until auth lands** — see §7 |
| R9 | **Excessive retention** — keeping a child's data longer than lawful | Low | Med | **Med** | Legal-hold-gated erasure tied to the HCPC duty; 7-yr audit purge; documented retention schedule | DEV-24, DEV-25 | **Low** |
| R10 | **International transfer of PHI** outside the UK | Low | High | **High** | Region-pin `europe-west2`; no cross-jurisdiction processing; **SCCs / UK IDTA** must cover any residual transfer (e.g. provider support access) | ADR-001, ADR-007 (§5) | **Low–Med** — **HUMAN to confirm transfer mechanism** (§7) |
| R11 | **Invalid / insufficient consent for a child** — parental responsibility not verified, or wording not GDPR-grade | Med | High | **High** | Consent captured + versioned at intake; wording finalised under DEV-28; lawful basis confirmed by DPO | DEV-28 | **Med until DEV-28 + lawful-basis sign-off** |
| R12 | **Subprocessor change without controller awareness** | Low | Med | **Med** | Published subprocessor list, updated on change; controller must accept Google/Vertex et al. | subprocessors.md; ADR-007 (§10) | **Low** |

---

## 5. Measures / safeguards summary

| Safeguard | How implemented | Reference |
|---|---|---|
| UK data residency, no cross-jurisdiction | Separate UK stack, `europe-west2`; DB resolved from jurisdiction; FHIR export asserts UK | ADR-001, ADR-006 §4 |
| Encryption at rest & in transit | Cloud SQL / GCS encryption + CMEK; TLS | architecture-gcp-hipaa.md |
| Network isolation for inference | Private Service Connect + VPC Service Controls; no public egress | ADR-007 §6, DEV-52 |
| No training on our data | AI/ML Privacy Commitment + DPA clause | ADR-007 §2 |
| Zero Data Retention at the processor | ZDR / abuse-logging exemption on Vertex endpoints (to confirm) | ADR-007 §3 |
| Prompt data minimisation | `llm/redact.ts` — strip/pseudonymise identifiers; `[CHILD]` placeholder | DEV-53 |
| No PHI in logs | Allowlist logger; route-pattern logging; sanitised errors | DEV-23 |
| Clinician-in-the-loop | `reviewed_at` gate; "DRAFT" labels; never auto-send | ADR-007 §9; schema |
| Magic-link hardening | 256-bit tokens, TTLs, revocation, rate limiting, failed-resolve audit | DEV-31; token-lifecycle.md |
| Portal-first delivery | Clinical content only in authenticated portal; email notification-only | ADR-005 |
| Tenant isolation | Tenant-scoped queries + isolation tests | DEV-34 |
| Append-only, retained audit trail | DB trigger + REVOKE; 7-yr purge; read+write auditing | DEV-25 |
| DSAR / erasure | PHI registry-driven export + two-step erasure; legal-hold | DEV-24 |
| Subprocessor transparency | Published list, updated on change | subprocessors.md |
| Breach response | 72-hr ICO notification runbook | mvp-brief; (runbook to finalise) |
| Branch protection / change control | Protected `main`, required review/CI | DEV-47 |
| Dependency & supply-chain hygiene | Dependabot + `npm audit` CI gate | DEV-31 |

---

## 6. Sign-off

> **TODO — HUMAN ACTION. This DPIA is not valid until signed.** An agent cannot accept risk
> on behalf of the controller, confirm a lawful basis, or execute contracts. The following
> must be completed by the named humans before real family data is processed.

| Role | Name | Responsibility | Signature | Date |
|---|---|---|---|---|
| **Controller** (design partner / practice) | _TODO_ | Accepts the residual risks in §4; **accepts Google/Vertex, Mailgun, Zoom and the chosen identity provider as subprocessors**; confirms parental-consent & lawful-basis approach | _TODO_ | _TODO_ |
| **DPO / Data Protection lead** | _TODO_ | Confirms lawful basis & Art. 9 condition; confirms a prior Art. 36 ICO consultation is **not** required (or initiates it); approves the risk treatment | _TODO_ | _TODO_ |
| **Clinical lead (HCPC registrant)** | _TODO_ | Confirms clinician-in-the-loop controls and clinical-record retention duty are adequate | _TODO_ | _TODO_ |
| **Technical / engineering lead** | _TODO_ | Confirms the §5 safeguards and §7 gate items are actually live in the environment that will hold real data | _TODO_ | _TODO_ |

**Notes for the controller:** The design partner (the SLT practice) is the **data controller**
for the patient data; Sona/the operator acts on their behalf and the named third parties are
**processors/subprocessors**. The controller must positively accept each subprocessor (esp.
Google/Vertex processing children's PHI — the core trade-off in ADR-007) and must hold the
underlying processor agreement with the Sona operator. If controllership is in fact **joint**
(operator + practice), that must be documented in a controller/joint-controller arrangement —
**a human decision flagged in §7.**

---

## 7. Open items before go-live (Go-Live Compliance Gate)

These MUST all be true before any real family data is processed. They map to the project's
"Go-Live Compliance Gate" and to the conditions in ADR-007. Items marked **[HUMAN]** cannot be
done by an agent.

1. **[HUMAN]** This DPIA **signed** by Controller + DPO (+ clinical/eng leads) — §6.
2. **[HUMAN]** **Lawful basis & Art. 9 condition confirmed and documented** (likely Art. 9(2)(h)
   + explicit parental consent); **parental-responsibility verification** approach agreed (R11).
3. **Vertex safeguards live (DEV-52)** — enterprise Vertex on invoiced billing; no-training;
   **ZDR/abuse-exemption confirmed enabled** for the chosen Gemini model in `europe-west2`
   (incl. input cache); PSC + VPC-SC perimeter; CMEK; least-privilege SA. ADR-007 §3/§6 — these
   are *confirm, not assume*.
4. **Prompt minimisation verified end-to-end (DEV-53)** — `redact.ts` covers the live intake
   field set; spot-check that no direct identifier reaches a prompt (R1, R5).
5. **[HUMAN]** **Consent wording finalised (DEV-28)** and wired to `consent_version`; privacy
   notice published (right to be informed).
6. **[HUMAN]** **Contracts executed** — Google Cloud **DPA + BAA** scoped to the exact Vertex
   services/region (ADR-007 §5); **Mailgun DPA** for metadata; **Zoom DPA (DEV-51)**; identity
   provider DPA (Firebase today / Auth0 if adopted, DEV-30).
7. **[HUMAN]** **International-transfer mechanism confirmed** — region-pinning plus **SCCs / UK
   IDTA** covering any residual transfer (e.g. provider support/CMEK key access) (R10).
8. **[HUMAN]** **Controller identity / subprocessor acceptance recorded** — design partner
   accepts Google/Vertex and the other subprocessors; controllership (sole vs joint) documented.
9. **Auth gating live** — close `TODO(DEV-31/auth)`: case API gated, DSAR export → admin/clinician,
   erasure & legal-hold → admin-only (R8); confirm the identity decision (DEV-30).
10. **[HUMAN]** **Branch protection on `main` (DEV-47)** — required review + CI; protects the
    integrity of the controls above (repo-admin only).
11. **Tenant-isolation tests green (DEV-34)** (R6).
12. **[HUMAN]** **Penetration test** completed and material findings remediated (R7;
    mvp-brief "pen-test before pilot scale-out").
13. **[HUMAN]** **Production environment provisioned & hardened (DEV-39)** — real data must live
    in prod (IAM-locked, no dev access — ADR-004), not the demo environment.
14. **[HUMAN]** **Breach-response runbook finalised** — 72-hour ICO notification path tested.

> If any item is open, the answer to "can real family data flow?" is **no**.

---

## References

- [`docs/mvp-brief.md`](../mvp-brief.md) — product & privacy intent
- ADR-001 [data residency](../decisions/001-data-residency-jurisdiction-stacks.md) ·
  ADR-005 [portal-first comms](../decisions/005-portal-first-patient-communications.md) ·
  ADR-006 [FHIR/UK Core](../decisions/006-fhir-r4-uk-core-alignment.md) ·
  **ADR-007 [Vertex Gemini managed inference](../decisions/007-vertex-gemini-managed-inference.md)**
- [`docs/security/token-lifecycle.md`](../security/token-lifecycle.md) ·
  [`docs/security/hardening-checklist.md`](../security/hardening-checklist.md)
- [`docs/compliance/dsar-runbook.md`](dsar-runbook.md) ·
  [`docs/compliance/audit-retention.md`](audit-retention.md) ·
  [`docs/compliance/subprocessors.md`](subprocessors.md)
- Code: [`apps/api/src/db/schema.ts`](../../apps/api/src/db/schema.ts) ·
  [`apps/api/src/routes/v1.ts`](../../apps/api/src/routes/v1.ts) ·
  [`apps/api/src/logger.ts`](../../apps/api/src/logger.ts) ·
  [`apps/api/src/llm/redact.ts`](../../apps/api/src/llm/redact.ts)
- [ICO — Data protection impact assessments](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/accountability-and-governance/data-protection-impact-assessments-dpias/)
