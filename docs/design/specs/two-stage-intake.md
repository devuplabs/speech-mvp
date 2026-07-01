# Two-Stage Intake + AI Questionnaire Summary — Design Spec

**Linear:** DEV-110 · **Status:** Draft → In Review · **Date:** 2026-07-01
**Data:** structure only — no PII, no publisher content, synthetic personas only.

Extends (does **not** rebuild) the existing 8-page intake (`docs/intake-form-spec.md`).
Builds on: **DEV-101** (generic data model — values carry provenance), **DEV-109**
(capture-once Case record), **ADR-007** (Vertex/Gemini managed inference,
clinician-reviewed, data-minimised prompts, no PHI in logs). Feeds the assessment→report
cycle (`docs/research/assessment-forms-teardown.md §4`).

This is connective tissue between the intake that already exists and the report pipeline.
It adds two things: (1) a **commitment gate** so the long questionnaire is only released
after the family has committed, and (2) an **AI summary** of the returned questionnaire
that lands in the capture-once Case record and pre-populates report context — so nothing
is re-keyed.

---

## 1. Why two stages (the "superstition")

Field wisdom from the design partner, taken as a hard design constraint: **a questionnaire
sent before the family has committed rarely comes back.** A long form is friction at the
exact moment trust is lowest. So we split the existing intake at its natural seam:

- **Stage 1 — Contact capture (enquiry):** a lightweight form, captured the moment an
  enquiry lands. Minimal, low-friction, no clinical detail. Its only job is to open a
  traceable case and let the clinician respond.
- **Stage 2 — Full questionnaire (post-commitment):** the existing 8-page clinical
  questionnaire, **released only after a commitment event** — the clinician (or a triage
  rule) marks the enquiry as *Accepted / consult booked*. This is when families reliably
  complete it, and when the clinical detail is actually worth collecting.

We are not adding a second form. We are **re-using the existing intake** and gating pages
2–8 behind commitment. Stage 1 is a thin new front on the same Case.

---

## 2. Stage 1 — Contact capture (the delta to Page 1)

Stage 1 is a **subset of the existing Page 1**, not new fields. Reference
`intake-form-spec.md → Page 1`. Released at enquiry with no login beyond the enquiry link.

| Stage-1 field | Source in existing spec | Required |
|---|---|---|
| Parent/carer name | Page 1 · Mother's / Father's Name | Yes |
| Parent/carer mobile | Page 1 · mobile number | Yes |
| Parent/carer email | Page 1 · email (magic-link anchor) | Yes |
| Child's name | Page 1 · Child's Name | Yes |
| Child's date of birth | Page 1 · Date of Birth | Yes |
| Presenting concern (one line) | Page 1/2 · condensed *Reason for referral* | Yes |
| Lead source (see §3) | Page 1 · "How did you hear about us?" — now a **manual tag** | Yes |
| Consent — privacy notice ack | Page 1 · consent blurb | Yes |

**Explicitly deferred to Stage 2** (do not ask at enquiry): GP details, both-parent
detail, referral chain, the Page-2 difficulty checklist, and everything on Pages 3–8.
Full media/assessment consent stays on the existing review screen at Stage 2 submit.

**New field on the Case:** `intake_stage ∈ { enquiry, questionnaire_released,
questionnaire_in_progress, questionnaire_complete }` — drives status, reminders, and the
release gate. All Stage-1 values are written to the **same** capture-once Case record with
`provenance = parent`, so Stage 2 continues the record rather than starting a new one.

---

## 3. Lead source — manual tag (no omni-channel in v1)

The care-journey map flags omni-channel enquiry capture as *not built in v1* (manual case
logging only). We honour that here:

- `lead_source` is a **single manual tag** the clinician (or the enquiry form) sets from a
  short editable enum, e.g. `nursery/SENCO`, `GP`, `school`, `word-of-mouth`, `web`,
  `directory/ASLTIP`, `other (free text)`.
- No channel integrations, no inbox parsing, no auto-attribution. It exists so the
  clinician gets funnel data (which sources convert) without building an omni-channel
  pipeline. It maps the existing free-text "How did you hear about us?" onto a taggable
  field; the free-text answer is retained as a note.

---

## 4. Flow & status

### Screen / flow list (mostly re-uses existing screens)

| # | Screen | Surface | New / existing |
|---|---|---|---|
| S1 | Enquiry · Contact capture | Parent mobile/web | **New** — thin form (§2 fields) |
| S2 | Enquiry · "Thanks, we'll be in touch" | Parent | **New** — holding state, no questionnaire yet |
| S3 | Clinician · Enquiries queue | Clinician web | Extends existing **Today / Clients**: shows `intake_stage`, lead source, commit action |
| S4 | Clinician · Accept / release questionnaire | Clinician web | **New action** on the Case (the commitment gate) |
| S5 | Parent · Welcome | Parent | Existing `parent · welcome` — now entered via the **release** magic link |
| S6 | Parent · Form (Steps 1–8) | Parent | Existing 8-step intake; Page 1 pre-filled from Stage 1 |
| S7 | Parent · Review & consent | Parent | Existing `parent_review_screen` — full consent captured here |
| S8 | Clinician · Intake review + AI summary | Clinician web | Extends existing intake-review: adds the **AI summary card** (§5) |

### Status & reminders

- **Enquiry received** → Case created at `intake_stage = enquiry`; clinician notified.
- **Commitment (S4)** → clinician accepts; `intake_stage = questionnaire_released`; a
  **release magic link** (Mailgun, notification-only — never carries answers, per the
  mvp-brief email rule) invites the parent into the existing 8-step form.
- **In progress** → autosave/"save & exit" (already stubbed in the intake) flips the Case
  to `questionnaire_in_progress`; the clinician queue shows live status (mirrors care-map
  stage 2 "live status").
- **Reminders** → gentle, notification-only nudges to finish the questionnaire (e.g. at
  +3d and +7d), clinician-configurable and cancellable; content stays in the portal.
  Reminders fire **only after release** — never for a pre-commitment enquiry.
- **Complete** → on Stage-2 submit, `intake_stage = questionnaire_complete`; the AI
  summary job (§5) is queued.

Status values are a linear progression; the clinician can re-send a release link or
reminder, but the questionnaire is never surfaced before S4.

---

## 5. AI questionnaire summary (Gemini on Vertex, clinician-reviewed)

**Goal:** turn the returned questionnaire from a wall of long-text answers into a concise,
structured summary that (a) gives the clinician a fast whole-client read and (b)
**pre-populates report context** so background is not re-typed later.

### What it produces
A **draft** summary object attached to the Case, structured to line up with the report
skeleton in the teardown (`assessment-forms-teardown.md §4`):

- **Relevant Background Information** — a tight prose paragraph distilled from Pages 3–8
  (language exposure, birth/health history, developmental milestones, education/SEN). This
  is the section the report engine (DEV-105) reads for *Relevant Background Information*.
- **Presenting concern & difficulty profile** — the Page-2 free-text concern plus the
  ticked difficulty checklist, grouped by domain (speech/language, attention, social,
  reading/writing).
- **Flags to probe at consult** — items warranting a question in the free 20-min consult
  (e.g. hearing history, prior professional involvement, family history) — feeds the
  existing consult-prep brief, not a diagnosis.

### Provenance & clinician-in-the-loop
- The summary is a **DRAFT** carrying the standard "AI-drafted · clinician-reviewed" pill.
  Nothing propagates to a report until the clinician **reviews and accepts** it (S8).
- On acceptance, the accepted summary is written into the **capture-once Case record**
  (DEV-109) with `provenance = ai_summary (clinician-reviewed)`; the underlying intake
  answers keep `provenance = parent`. Scores/assessment values are **out of scope here**
  and remain `provenance = clinician` (never computed — teardown §1). The summary is
  **derived context**, never a source of truth that overwrites a parent answer.
- **No re-keying:** the report engine reads *Relevant Background Information* from the
  accepted summary; the clinician edits in place rather than re-typing from the raw form.

### Model & routing (ADR-007)
- Managed **Vertex AI Gemini**, region-pinned `europe-west2`, enterprise/ZDR endpoint via
  Private Service Connect. Default **Gemini Flash** (summary is a low-stakes distillation);
  no need for Pro here.
- Behind the provider-agnostic client; prompt stays in parity with the `speech-ml` eval
  harness and `apps/api/src/llm/intake-context.ts` (per AGENTS.md prompt-parity guardrail).
- Audit records that inference occurred (model id, case id, timestamp, outcome) — **no
  content** (ADR-007 §8/§11).

---

## 6. Data-minimisation for the summary prompt (ADR-007 §7 / DEV-53)

The prompt is built from a **redacted, pseudonymised** projection of the Case — direct
identifiers never enter it:

- **Strip before send:** child name, DOB (send **age band / age at referral** instead),
  full address, GP identifiers, parent names, phone numbers, email addresses, school name.
  Re-attach any identifiers in our own render layer, never via the model.
- **Send only clinical context:** presenting concern, difficulty checklist, and the
  clinical narrative fields from Pages 3–8 the summary actually needs. Contact/admin fields
  (Page 1 beyond the concern) are excluded from the prompt entirely.
- **Enforced in code** by `llm/redact.ts` before inference (AGENTS.md PHI guardrail); the
  redaction set for this prompt is unit-tested against the personas mirrored across
  `scripts/personas`, `e2e/fixtures`, and `apps/sona/lib/test_utils`.
- **No PHI in logs:** neither the prompt nor the response is logged (ADR-007 §8). Failures
  log case id + error class only.
- **Lawful basis unchanged:** parental consent captured at Stage-2 review (mvp-brief
  privacy stack); Google/Vertex disclosed as subprocessor in the DPIA (ADR-007 §10).

---

## 7. Scope boundaries (extend, don't rebuild)

**In scope:** Stage-1 contact form (subset of existing Page 1); the `intake_stage` field +
release gate + reminders; `lead_source` manual tag; the AI summary draft → accepted Case
field → report-context pre-population; the summary prompt's data-minimisation.

**Out of scope (unchanged / elsewhere):** the 8-page questionnaire content itself
(`intake-form-spec.md` is authoritative — no page/field redesign here); score capture and
the report engine (DEV-101/105 + teardown); omni-channel enquiry capture (deferred per
care-map); appointment booking/payments (mvp-brief out-of-scope). No new fields on Pages
2–8; the only new persisted fields are `intake_stage`, `lead_source` (+ retained
free-text note), and the accepted-summary object on the Case.

---

## 8. Open questions

1. **Commitment trigger** — is the release gate always a manual clinician action (S4), or
   may a triage rule auto-release after a booked consult? (Default: manual in v1.)
2. **Reminder cadence** — confirm +3d/+7d and max count with the design partner.
3. **Lead-source enum** — confirm the starter set and whether it's practice-editable in v1.
4. **Summary granularity** — does the clinician want the three sections above, or a single
   paragraph? Confirm against real (consented) intakes in co-design session #1.
5. **Flash vs Pro** — validate Flash quality for the background summary via the eval
   harness (ADR-007 open q.3) before go-live.

## 9. Cross-references
- Existing intake: `docs/intake-form-spec.md` (Pages 1–8, review/consent screens)
- Report mapping: `docs/research/assessment-forms-teardown.md §4`
- Care journey: `docs/design/sona-care-journey-map.md` (stages 1–3)
- Inference + safeguards: `docs/decisions/007-vertex-gemini-managed-inference.md`
- Data model / capture-once: DEV-101 / DEV-109 · Data-minimisation: DEV-53
- Guardrails: `AGENTS.md → Guardrails` (PHI, prompt parity, personas parity)
