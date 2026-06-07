# ML Design — Parent summary generation

**Feature:** AI-drafted parent-friendly summary email/PDF generated after clinician finalises the session plan  
**Slice owner:** Sona API — `services/parent-summary.ts` (stub → real)  
**Status:** Stub (`defaultParentSummaryHtml()` returns a static 3-line template; no LLM)  
**ADRs:** [003](../decisions/003-self-hosted-llm-air-gap.md) (air-gap LLM), [001](../decisions/001-data-residency-jurisdiction-stacks.md) (jurisdiction)  
**DB table:** `ai_drafts` where `kind = 'parent_summary'`  
**Target:** 90-day ship · v0.2

---

## Problem

After the first session plan is reviewed, Monal sends the parent a written summary of what was discussed on the call and what comes next. This document:

- Is the first formal clinical communication with the family.
- Must be accurate (reflects the triage decision, not generic boilerplate).
- Must be readable (parent's first language may not be English; reading level matters).
- Must carry the "AI-drafted · clinician-reviewed" disclosure if AI was involved.
- Doubles as a carryover tool — the home practice section is what the parent will actually do.

Today Monal writes this from scratch in a word processor after each call. It takes 15–30 minutes. She has tried ChatGPT here too — same PHI risk as with session plans.

**Goal:** After the clinician reviews and saves the session plan, generate a parent-facing summary email/PDF draft that:

1. Opens with a warm, personalised greeting naming the child.
2. Summarises what was discussed (drawn from the triage reason and prep brief probes).
3. States the agreed pathway and next steps clearly (drawn from the triage outcome).
4. Lists the home-practice recommendations in plain language (drawn from the session plan).
5. Includes a "What to notice" section — observable behaviours for the parent to track.
6. Closes with contact information and the AI disclosure footer.

The clinician adjusts tone (warm ↔ clinical slider, 5 points), reading level (primary / secondary / adult), and toggles sections in/out before publishing. Publishing stores the final HTML in `ai_drafts` and exposes it via the parent portal.

---

## Metrics

| Metric | Definition | Target at 90 days |
|--------|-----------|-------------------|
| **Draft acceptance rate** | % of summaries where the clinician publishes without deleting > 50 % of content | ≥ 85 % |
| **Clinician edit time** | Minutes from opening summary preview to clicking Publish | ≤ 8 min (vs. ~25 min write-from-scratch baseline) |
| **Flesch–Kincaid grade level** | Computed on published HTML content | ≤ 8 for "secondary" setting; ≤ 5 for "primary" setting |
| **Home-practice retention** | % of home-practice items from the session plan that appear verbatim or near-verbatim in the published summary | ≥ 90 % (accuracy: nothing from the plan is silently dropped) |
| **Parent portal open rate** | % of published summaries opened by the parent within 48 hours | ≥ 70 % (engagement; proxy for usefulness) |
| **Parent re-read rate** | % of parents who open the summary more than once | Tracked; no target yet |
| **Draft generation latency P95** | Time from session plan `reviewedAt` to `parent_summary` draft ready in `ai_drafts` | ≤ 20 s |

**Primary editorial signal:** Clinician edit time + section deletion rate. If the clinician spends > 15 min editing, the draft is not saving time and the prompt must be revised.

---

## Data

### Input (available at inference time)

```
IntakeAnswers (JSONB, key fields)         →  ~1 000 tokens (selected)
triageRecords.outcome + .reason           →  outcome enum + up to 500 chars
ai_drafts(kind='session_plan').content    →  goals, activities, homePractice, parentGoals
ai_drafts(kind='prep_brief').content      →  probeAreas used in the call (what was discussed)
clinicianPreferences: {
  tone: 1–5,                             →  1=clinical, 5=warm
  readingLevel: "primary"|"secondary"|"adult"
  sections: string[]                     →  which sections to include
}
```

**What is NOT passed to the model:**

- Raw medical/birth history (steps 4–5 of the intake) — too clinical; not parent-facing.
- Father/second parent contact details — PII, not needed for the narrative.
- GP details — not included in parent summary.

The summary is about *what we discussed and what happens next* — not a clinical history recital.

### Tone calibration

| Tone value | Prompt instruction fragment |
|-----------|---------------------------|
| 1 (clinical) | "Use formal, clinical language appropriate for a professional referral context." |
| 2 | "Use clear professional language. Avoid jargon but maintain clinical precision." |
| 3 (balanced, default) | "Write in accessible, professional language. Warm but not overly informal." |
| 4 | "Write warmly. Use plain language. Prioritise reassurance and clarity for an anxious parent." |
| 5 (warm) | "Write as if talking to a close friend. Short sentences. Reassuring. No clinical jargon." |

### Reading level enforcement

After generation, apply a Flesch–Kincaid grade-level check (`flesch-kincaid` npm package or computed inline). If the output exceeds the target grade level, a post-processing pass rewrites sentences using a simplified-vocabulary prompt (2-sentence system prompt: "Rewrite the following using only words a Year 8 student would understand."). This is a secondary inference call (< 200 tokens output) — fast, and produces measurable grade-level compliance.

### Structured output format

```ts
const parentSummarySchema = z.object({
  subject: z.string().max(80),        // email subject line
  greeting: z.string().max(200),      // personalised opening
  discussionSummary: z.string().max(800),
  nextSteps: z.string().max(400),
  homePractice: z.array(z.object({
    instruction: z.string().max(200),
    frequency: z.string().max(80),    // e.g. "5 minutes daily"
  })).min(1).max(3),
  whatToNotice: z.array(z.string().max(150)).max(4),
  closingNote: z.string().max(200),
  aiDisclosureFooter: z.literal(
    "This summary was drafted with AI assistance and reviewed by your clinician before sending."
  ),
});
```

The `aiDisclosureFooter` is a `z.literal` — it cannot be omitted or modified by the model. The client renders it verbatim in every published summary.

---

## Model

**Inference:** Gemma 3 27B IT, INT4 AWQ, vLLM, private GKE, tenant region (ADR-003).

**Context budget:**

| Component | Tokens (est.) |
|-----------|--------------|
| System prompt + schema + tone instruction | 1 000 |
| Selected intake fields (10 fields) | 600 |
| Triage outcome + reason | 300 |
| Session plan content | 700 |
| Prep brief probes | 300 |
| Few-shot examples (1 warm, 1 clinical) | 1 200 |
| **Total input** | **~4 100** |
| Max output tokens | 1 000 |
| **Total** | **~5 100 / 128K window** |

**Two-pass generation:**

1. **Pass 1:** Generate the full summary JSON (all sections, at the chosen tone/level).
2. **Pass 2 (conditional):** If Flesch–Kincaid > target, run a simplification pass on `discussionSummary` and `nextSteps` only (the most likely offenders). The homePractice instructions are generated in plain imperative language and rarely need simplification.

**Multi-language awareness:** If `parentLanguages` includes a non-English language, append to the system prompt: "Note: the parent's first language is [X]. Use particularly clear English. Do not generate content in [X] — the clinician will arrange translation if needed." This is a risk mitigation note, not a translation feature.

**Few-shot examples:** Two complete synthetic summaries: one clinical tone (3/5) for a `full_assessment` outcome, one warm tone (5/5) for a `strategy_only` outcome. Authored by Monal and reviewed against her actual summary templates.

---

## Deployment

**Trigger:** The summary draft is generated when the clinician **opens the summary preview screen** (on-demand, not at session plan save). This avoids generating unused drafts (clinicians who never reach the summary screen). The request goes through a new synchronous endpoint `POST /v1/cases/:id/parent-summary/draft` with the clinician's preferences in the body.

```
Clinician opens summary preview
  → Flutter calls POST /v1/cases/:id/parent-summary/draft { tone, readingLevel, sections }
  → API calls inference synchronously (SSE streams partial JSON to Flutter)
  → Flutter renders sections as they arrive
  → Clinician edits in-place
  → Clinician clicks "Publish" → POST /v1/cases/:id/parent-summary/publish { htmlBody }
  → Parent portal serves the published HTML
```

**Why synchronous here, not async?** The clinician is actively waiting with the UI open and expects an interactive drafting experience. 20 s total latency with streaming (first section ≈ 3 s) is acceptable. Async (Cloud Tasks) would require polling or SSE push management and adds perceived latency.

**Regeneration:** The clinician can change tone/reading level and click "Regenerate". This calls `POST /v1/cases/:id/parent-summary/draft` again, overwriting the unpublished draft in memory (not in DB). The DB is only written on Publish.

**PDF generation:** On publish, a Cloud Run worker converts the HTML to PDF using headless Chromium (separate `pdf-worker` service). The PDF is stored in GCS (CMEK bucket) and the signed URL is returned to the clinician for optional download. PDF generation is async from the publish call — the portal HTML is immediately available; the PDF arrives within 30 s.

**Email delivery:** the summary body is **never emailed**. A future `POST /v1/cases/:id/parent-summary/notify` would send a **notification-only** email ("a report is ready" + portal sign-in link, no clinical content) — see ADR-005 and the email design rule in `apps/api/src/services/email.ts`. Transactional email setup is in `infra/docs/unblock-mailgun-and-inference.md`. Not in 90-day scope; the portal link is the v0.2 delivery mechanism.

---

## Monitoring

| Signal | Mechanism | Alert threshold |
|--------|-----------|----------------|
| Summary draft generation latency P95 | Cloud Run custom metric | > 30 s |
| Flesch–Kincaid post-simplification failure rate | Structured log | > 10 % still over target after pass 2 |
| Section deletion rate | Diff of `draft_content` vs `published_content` in `ai_drafts` | > 15 % for any section |
| Portal open rate (7-day rolling) | Cloud Logging `parent_summary.viewed` events | < 60 % |
| `aiDisclosureFooter` present in published HTML | Nightly assertion job (read `ai_drafts`, check substring) | Any failure = P0 |
| JSON parse failure rate | Structured log | > 3 % |
| PDF generation failure rate | `pdf-worker` Cloud Run error rate | > 1 % |

**The `aiDisclosureFooter` assertion job is P0:** if the disclosure line is ever absent from a published summary — whether due to a schema bug, migration error, or content substitution — that is a regulatory compliance failure. The nightly job alerts immediately and blocks further publishes until resolved.

---

## Ethics

| Concern | Control |
|---------|---------|
| **Mandatory AI disclosure** | `aiDisclosureFooter` is a `z.literal` in the schema — model cannot omit or modify it. The field is stored verbatim in `ai_drafts.content` and rendered by the Flutter parent portal widget without the clinician being able to remove it. Published summaries always carry the line: *"This summary was drafted with AI assistance and reviewed by your clinician before sending."* |
| **Clinician review gate** | `publishParentSummary()` API requires `reviewedAt IS NOT NULL` on the `session_plan` draft (the upstream plan must have been saved by the clinician). No summary is published without a reviewed session plan. The `publish` endpoint itself sets `ai_drafts.reviewedAt = now()` on the summary — a clinician action, not a system action. |
| **Reading level and health literacy** | Intake data may indicate English is a second language. The Flesch–Kincaid enforcement and the ESL note to the model are safeguards. At v0.2, translation is handled offline by the clinician if needed. The v0.3 roadmap includes optional machine translation (with disclosure) via a GDPR-compliant API. |
| **PHI minimisation in the summary** | The summary prompt explicitly omits birth history, GP details, and detailed medical history fields. Parents may be distressed if clinical language from the intake appears verbatim (e.g. referencing a listed diagnosis without clinical framing). The system prompt includes: "Do not quote from the intake form verbatim. Synthesise into plain language." |
| **Parent consent for portal access** | The magic link sent to the parent to access the portal is time-limited and single-use. The parent consent checkboxes on the intake review screen (`consentGuardian`, `consentPrivacy`, `consentAccurate`) are required before the case can advance to `summary_sent`. The `intake_submissions.consentVersion` field records the version of the consent wording at the time of submission. |
| **No training on summary content** | Published summaries are stored in `ai_drafts.content` (JSONB). They are not exported to any training pipeline. Any future adaptation (e.g. tone fine-tuning) requires a separate consent mechanism and anonymisation review. |
| **Audit trail** | `audit_log` records `parent_summary.draft_generated` (model_id, tone, readingLevel), `parent_summary.published` (clinician act, with `reviewedAt`), `parent_summary.viewed` (parent portal open, with timestamp, no IP). |
| **Children's data protections** | The portal is addressed to the parent/guardian, not the child. The summary does not contain the child's address or contact details. The child's name appears only in the personalised greeting; it is not stored in logs. |

---

## Trade-offs

| Decision | Why | What we gave up |
|----------|-----|----------------|
| Synchronous draft generation (not async) | Clinician is at the keyboard; streaming first section within 3 s is better UX than a "drafting" spinner | Ties up a Cloud Run connection for ~20 s; must set concurrency limits on the draft endpoint |
| On-demand draft (not pre-generated at plan save) | Avoids generating summaries for cases that never reach publish; saves GPU time | Clinician waits ~20 s when they open the preview — mitigated by streaming |
| Portal-first delivery (clinical content never emailed) | By design, PHI/clinical content is only rendered in the authenticated portal (ADR-005); email is notification-only ("report ready" + sign-in link), regardless of any BAA/DPA | Parents used to receiving clinical letters by email may not know to check the portal — mitigated by a notification email |
| PDF async from publish (not blocking) | Headless Chromium can take 10–30 s; blocking publish on PDF would hurt the UX | PDF may arrive 30 s after publish; clinician cannot download immediately |
| `aiDisclosureFooter` as `z.literal` | Regulatory non-negotiable; enforcement at schema level is more reliable than a UI reminder | The disclosure wording is fixed; any wording change requires a schema version bump and migration |
| No in-summary PHI from steps 4–5 | Minimisation; avoids clinical language alarming parents | Some clinically relevant context (e.g. hearing test result) is paraphrased rather than quoted — acceptable trade-off for parent-facing communication |
| Tone slider (1–5) not a model parameter | Discrete prompt fragments are more controllable than a continuous temperature parameter for tone | Subtle tonal gradations within a level are inconsistent; clinicians may notice jumps between adjacent settings |
| English-only generation | Scope; UK pilot; clinician can translate offline | Parents whose primary language is not English receive less clear communication until v0.3 translation is added |
