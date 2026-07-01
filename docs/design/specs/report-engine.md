# Report Template Engine & Assessment-Report Generation

*Design spec for Linear **DEV-105**. Sona's highest-value surface: the ~3-hour formal
assessment report, produced today with ChatGPT prose + manual find-and-replace + manually
keyed score tables. v1 output is a **clinician-reviewed DRAFT** in her own headings and voice,
with **auto-built score tables**, on a **template-driven, generic** engine that other SLTs and
report kinds plug into.*

**Date:** 2026-07-01 · **Status:** Draft → In Review · **Scope:** design only, no code ·
**Data:** structure only — no PII, no publisher content · **UK English.**

**Builds on:** DEV-101 (data model: `ReportTemplate` section types + binding DSL,
`GeneratedReport` versioned draft→in-review→signed) · DEV-100 (licensing: score table from
**confirmed captured** clinician values, provenance = clinician) · ADR-007 (Gemini on Vertex,
Pro for report-quality drafts, data-minimisation, no PHI in logs, clinician-in-the-loop).

**Read alongside:** `docs/research/assessment-forms-teardown.md` (the 7 templates + confirmed
score-table shape + field→section mapping), `docs/design/sona-care-journey-map.md` (stage 9),
`AGENTS.md → Guardrails`.

---

## 0. Principles (the non-negotiables this engine encodes)

1. **AI drafts; the clinician decides.** Every generated report is a labelled DRAFT until the
   clinician signs. Nothing auto-sends, nothing auto-saves as clinical record.
2. **Her report, her voice.** The engine reproduces *her* headings, section order, and register —
   not a Sona house style. "Not a single report looks the same": the prose is bespoke; the
   *skeleton* is templated.
3. **Score tables are data, never prose.** The score table is rendered from confirmed captured
   values (provenance = clinician). The model never writes, edits, or computes a scaled score or
   percentile, and Sona never hosts a norm/conversion table (DEV-100, AGENTS.md guardrail).
4. **One engine, many report kinds.** The same template model drives all report kinds from the
   teardown. Statutory plans (EHCP) are a **config branch**, not a fork.
5. **Data-minimised by construction.** Direct identifiers are stripped before any prompt and
   re-attached only at render (ADR-007 §7, DEV-109).
6. **Auditable.** Every generation and sign-off writes an append-only audit event (model, case,
   timestamp — no content).

---

## 1. Report template model (from DEV-101)

A `ReportTemplate` is an ordered list of **sections**, plus template-level metadata (report kind,
owning clinician/practice, statutory-plan flag, tone/reading-level defaults, header layout). A
template is versioned; a `GeneratedReport` pins the template version it was built from.

### 1.1 Section types

Each section declares a `type` that governs how it is filled and whether the model may touch it:

| Section type | Filled from | Model role | Editable |
|---|---|---|---|
| `static` | Fixed boilerplate stored on the template (credentials blurb, scaled-score explainer, standing disclaimers) | **None** — never generated, never rewritten | Locked by default; template-owner can edit the boilerplate at template level |
| `bound` | Directly from CapturedValues via the binding DSL (identity block fields, dates, target statements) | **None** — deterministic field substitution | Value-editable inline; edits flow back as captured-value overrides |
| `score_table` | **Confirmed captured** subtest values, laid out by the fixed table shape (§1.3) | **None** — rendered from data, never authored | Cell-editable (each edit is a captured-value correction with provenance = clinician) |
| `ai_drafted` | Bound captured context → Gemini(Vertex, Pro) → prose in the section's heading/style | **Drafts** the prose; clinician edits/regenerates | Fully editable; per-section regenerate |

A section carries: `id`, `heading` (the clinician's own wording), `order`, `type`, `binding`
(see §1.2), `required`/`optional`, `tone_override?`, `reading_level_override?`, and for
`ai_drafted` a `guidance` note (what this section should cover, in her words).

### 1.2 Binding DSL (section → CapturedValues)

Sections bind to captured data by **reference**, never by embedding raw values in the template.
The DSL is declarative and resolves at generation time against the case's CapturedValues:

- `bind: field(<path>)` — single captured field (e.g. `field(case.identity.age_at_assessment)`).
- `bind: group(<path>)` — a set of captured notes/observations feeding an `ai_drafted` section
  (e.g. `group(observations.classroom)` → the Classroom Observation section).
- `bind: table(<instrument>, <domain>)` — resolves the confirmed subtest rows for a `score_table`
  (e.g. `table(celf5_uk, receptive)`), returning only clinician-derived values.
- `bind: static()` — no data; the section renders its stored boilerplate.
- Modifiers: `optional` (section is dropped if the binding is empty — e.g. no score table on an
  informal report), `redact_identifiers` (default on for anything sent to the model), and
  `source_filter(external|clinician)` for third-party instrument results captured with a
  `source = external` flag.

Bindings are **resolved and validated before generation**: a missing required binding surfaces as
a pre-flight gap ("Formal Assessment score table has no confirmed values yet"), not a silent hole
or a hallucinated value.

### 1.3 Score-table layout (fixed, confirmed shape)

The table shape is fixed by the teardown and rendered verbatim from captured values:

```
Subtest | What it tests | Scaled Score | % Rank | Analysis
```

- **Receptive** and **Expressive** blocks render as separate grouped tables where the template
  declares both domains (CELF-based reports); composite/index rows (Core Language, Receptive/
  Expressive Language Index) render only where the clinician captured them.
- Every value in `Scaled Score` and `% Rank` is a **captured input, provenance = clinician** — never
  computed, never model-authored. `What it tests` is captured/boilerplate descriptive text (the
  clinician's own wording, not publisher text). `Analysis` is a captured plain-language band
  ("Within Average Range").
- The standing explainer ("raw score is converted to a scaled score… average is 10… normal range
  7–13") is a **`static` boilerplate** section adjacent to the table, not generated.
- Score tables are **optional bound sections**: informal/preschool reports (teardown §2.3) carry
  no table; the engine simply drops the section when `table(...)` resolves empty.

### 1.4 Boilerplate vs personalised regions

- **Boilerplate regions** (`static`) — credentials/HCPC-RCSLT blurb, scaled-score explainer,
  standing disclaimers, AI-disclosure footer. Owned at template level, reused unchanged, never
  sent to the model.
- **Personalised regions** (`ai_drafted`, `bound`, `score_table`) — everything client-specific.
  Prose is drafted per case; scores and identity are data-driven.
- The boundary is explicit in the template so the model's writable surface is *only* the
  `ai_drafted` sections — it can never overwrite boilerplate, identity, or scores.

### 1.5 Tone / reading-level controls

Template-level defaults with per-section overrides:

- **Tone** — a slider spanning *clinical ↔ warm* (mirrors the existing parent-summary tone
  control). Formal assessment defaults clinical; a family-facing block summary defaults warmer.
- **Reading level** — target register (e.g. professional / accessible / plain-English) applied to
  `ai_drafted` sections; identity, scores and boilerplate are unaffected.
- Controls feed the prompt as instructions and are recorded on the `GeneratedReport` so a
  regenerate is reproducible.

---

## 2. Generation flow (verified data → Gemini(Vertex, Pro) → sectioned draft)

```
Case CapturedValues (confirmed)              ReportTemplate (pinned version)
        │                                              │
        └──────────────┬───────────────────────────────┘
                       ▼
         Pre-flight: resolve + validate every binding
         (flag missing required data; no silent gaps)
                       │
        ┌──────────────┴───────────────────────────────┐
        ▼                                               ▼
  ai_drafted sections                          score_table / bound / static
        │                                               │
        ▼ (per section)                                 │  (NO model involvement)
  Data-minimise → strip identifiers,                    │
  assemble section context                              │
        │                                               │
        ▼                                               ▼
  Gemini on Vertex (Pro) — Zero Data           Rendered deterministically:
  Retention, europe-west2, PSC/VPC-SC          - score tables from confirmed
        │                                        captured values (§1.3)
        ▼                                        - bound fields substituted
  Section prose (draft), in her heading/style   - static boilerplate inserted
        └──────────────┬───────────────────────────────┘
                       ▼
        Assemble sectioned GeneratedReport (status = draft)
        Identifiers re-attached at render only (§6)
        Audit event written (model, case, ts — no content)
```

Key rules:

- **Two rails, never crossed.** The AI rail produces prose for `ai_drafted` sections only. The
  deterministic rail renders score tables, bound fields, and boilerplate. Score-table values never
  pass through the model, and model output never lands in a score cell.
- **Model + tier.** `ai_drafted` prose uses **Gemini Pro on Vertex** (report-quality tier, ADR-007).
  Flash may be used for lightweight regenerate previews only if eval-harness quality holds; the
  authoritative draft is Pro.
- **Per-section generation.** Each `ai_drafted` section is generated independently so it can be
  regenerated in isolation without disturbing edited siblings.
- **Grounding, not invention.** Prompts carry only the minimised captured context bound to that
  section. The model is instructed to draft strictly from provided context and to leave gaps
  flagged rather than fabricate — especially never to state a score.
- **Prompt parity.** Report prompts live behind the provider-agnostic LLM client and stay in
  parity with the `speech-ml` eval harness (AGENTS.md → Prompt parity).

---

## 3. Clinician editing & sign-off

The clinician opens the generated draft in a **sectioned editor** that mirrors the template order
and her headings.

- **Editable sections.** `ai_drafted` prose is fully editable rich text. `bound` fields and
  `score_table` cells are editable as data (an edit is a captured-value correction, provenance =
  clinician, not a free-text override of the record). `static` boilerplate is locked in the report
  (editable only at template level).
- **Regenerate per section.** Each `ai_drafted` section has a regenerate action (optionally with a
  short instruction, e.g. "shorter", "more on attention & listening"). Regeneration replaces only
  that section; edited sections are untouched. Prior versions of a section are retained.
- **DRAFT badge until signed.** The whole report carries the standard "AI-drafted ·
  clinician-reviewed" DRAFT marker (design-system accent pill) on screen and on every export,
  removed only on sign-off. No export or share is possible while unsigned unless explicitly marked
  as a working draft watermark.
- **Sign-off.** Sign-off is an explicit clinician action that: sets status `signed`, **stamps the
  clinician's HCPC number** (and RCSLT membership where configured) into the report footer, records
  signer identity + timestamp, and freezes the content as a versioned clinical record.
- **Versioning.** `GeneratedReport` is versioned draft → in-review → signed (DEV-101). Each state
  transition and each signed export is an immutable version; re-opening a signed report creates a
  new draft version rather than mutating the signed one.
- **Export.** Signed (and, with a draft watermark, unsigned) reports export to **Word (.docx)** and
  **PDF**, rendered server-side (not client-side, per architecture sketch), preserving her heading
  hierarchy, the score tables, and the HCPC/DRAFT stamps. Export events are audited.

---

## 4. Personalisation without impersonality (the style profile)

The core risk is that automation flattens her voice into a generic template. The **clinician style
profile** prevents that while keeping her in the loop.

- **What it captures** — her *own* headings and section order per report kind, register/phrasing
  preferences, standard opening/closing conventions, and her boilerplate (credentials blurb,
  disclaimers). Derived from her redacted exemplar reports during onboarding; **never** from client
  PII and **never** reproducing publisher content.
- **How it's used** — the profile parameterises the template (heading text, section order,
  tone/reading-level defaults) and seeds `ai_drafted` guidance so drafts arrive already in her
  structure and register. It is **style only**: it carries no client data into prompts and cannot
  override the score-table or identity rails.
- **Still clinician-in-the-loop** — the profile drafts; she edits and signs. It reduces the
  find-and-replace / re-styling tax, not the clinical judgement. Profile edits are versioned and
  apply to future generations, never retroactively to signed reports.
- **Generic** — a style profile is per clinician (and per report kind), so a second SLT onboards
  their own voice without code changes. Default profiles ship per report kind as a starting point.

---

## 5. Generic across report kinds (one engine → the 7 templates)

All report kinds are instances of the same `ReportTemplate` model; they differ only in section
list, bindings, and config flags. Mapping to the teardown:

| # | Report kind (teardown) | Sections (abridged) | Score table | Notes |
|---|---|---|---|---|
| 1 | **Initial Assessment** (flagship formal) | credentials `static` → Background `ai_drafted` → Observations/Findings `ai_drafted` + Formal Assessment `score_table` → Summary `ai_drafted` → Recommendations `ai_drafted` | Yes (CELF-5 UK, receptive + expressive) | The ~3-hour report; scaled-score explainer is a `static` block |
| 2 | **Annual Review** (statutory) | Purpose → Background → 1:1 Assessment (Child's Views, Attention & Listening, Formal Assessment) → Summary of Needs → Recommendations → Next Steps | Yes (same shape) | **Statutory-plan branch** — see §5.1 |
| 3 | **Informal Consultation** (under-4/nursery) | Purpose → Background (Dev/Medical, Early Comms, Nursery) → Assessment (observations) → Recommendations | **No** (`optional` table drops) | No standardised test; score section absent |
| 4 | **Target Setting** | Header `bound` → `TARGET 1..N` each with statement + **Carryover for School** + **Carryover for Home** | No | School/Home split is first-class → feeds portal + school-access (DEV-107/108) |
| 5 | **Block Summary** (end-of-block) | Header → **Summary of Strategies Taught** (Purpose · Continue at Home · Why It Helps) | No | Rolls up from session notes (DEV-106); warmer tone default |
| 6 | **Session Feedback** (N of 10) | Header (session + position in block) → Target areas → "What We Worked On" table → video-clip references → Next Steps → next session | No | Fast-capture artifact (DEV-106); clip references are non-forwardable links (DEV-107/108) |

Because they share the engine, adding a new report kind = authoring a new template (section list +
bindings + flags), not writing new generation code.

### 5.1 Statutory-plan (EHCP) as a config branch

EHCP is **one example** of a statutory plan, handled as configuration on the template rather than a
separate engine (teardown §5 Q2; journey-map generalisation guardrail — "no statutory hard-wiring";
others: IDP, CSP, Statement, or none):

- A `statutory_plan` config flag (type + jurisdiction) turns on plan-specific sections
  (e.g. Purpose of Report, Summary of Needs, Next Steps), plan-aware headings, and required-field
  rules for that plan.
- Statutory phrasing is expressed as `ai_drafted` guidance + `static` boilerplate on the template,
  never as hard-coded logic, so new plans/jurisdictions plug in as config.

---

## 6. Data-minimisation & audit

Applies ADR-007 §7–8, §11 and DEV-109 to the report surface.

- **Strip before prompt.** Direct identifiers — child name, DOB, address, parents, school,
  therapist contact — are removed from all model context. Sections bind to a **pseudonymised** case
  (stable case id + age band / "the client"), matching the teardown's field→section mapping where
  the identity block is identifier-linked and the name is re-attached only at render.
- **Re-attach at render.** Identity block and any inline identifiers are substituted back in the
  **deterministic render layer**, after generation, from the case PII record — never from anything
  the model saw or produced.
- **No PHI in prompts or logs.** Prompts carry only the minimised clinical context a section needs;
  inference logs record model id, case id, latency, outcome — never prompt/response content
  (AGENTS.md → PHI safety; ADR-007 §8).
- **Score-table minimisation.** Score tables never enter a prompt at all (rendered on the
  deterministic rail), so scaled scores/percentiles are not exposed to the processor.
- **Audit.** Append-only audit events for: report generated (template + version, model, case,
  timestamp), per-section regenerate, edit-then-save, sign-off (signer, HCPC number, timestamp),
  and each export (format, timestamp). Content is not logged; 7-year retention per the privacy
  stack.

---

## 7. Screen / flow list (for the Figma task)

Clinician workspace, desktop-oriented (Web 1440×900), consistent with the existing Sona design
system (Inter; primary teal `#2D6A6E`; accent coral `#F2A878` for AI-draft markers; DRAFT pill).
All surfaces are adult-facing; no client-facing report authoring.

| # | Screen / surface | Purpose | Key elements |
|---|---|---|---|
| R0 | **Reports · list** | Entry from the clinician workspace `reports` tab | Table of reports per client (kind, status draft/in-review/signed, updated), "New report" action, status chips |
| R1 | **New report · pick kind & template** | Start a report | Report-kind cards (the 6 kinds), template + style-profile selector, statutory-plan toggle (type/jurisdiction), client picker |
| R2 | **Pre-flight · data check** | Show binding resolution before generation | Section list with per-binding status (ready / missing), explicit gaps (e.g. "no confirmed score values"), "Generate draft" gated on required bindings |
| R3 | **Generating** | Async draft state | Per-section progress ("Drafting" → "Ready"), Pro-tier notice, cancel; mirrors existing "Drafting → Ready" pattern |
| R4 | **Report editor (sectioned)** | Review & edit the draft | Left: section outline in her headings + status; centre: editable sections with DRAFT pill; per-section **Regenerate** (with optional instruction) + version history; boilerplate shown locked |
| R5 | **Score-table editor** | Correct confirmed values | The fixed `Subtest \| What it tests \| Scaled Score \| % Rank \| Analysis` grid; receptive/expressive blocks; cell edits flagged provenance = clinician; explicit "not computed / captured value" note; add composite/index row |
| R6 | **Tone & reading-level panel** | Adjust register | Tone slider (clinical ↔ warm), reading-level select, per-section override; "regenerate affected sections" |
| R7 | **Sign-off** | Convert draft → signed | Review summary, HCPC number confirmation, sign action, freeze-version confirmation, removes DRAFT badge |
| R8 | **Export** | Produce deliverables | Word / PDF export, draft-watermark option for unsigned, preview, export-history |
| R9 | **Style profile settings** | Manage her voice | Per-report-kind headings/order, register preferences, boilerplate (credentials/HCPC-RCSLT blurb), onboarding-from-exemplars entry (redacted), version history |
| R10 | **Report audit trail** | Compliance view | Timeline of generate / regenerate / edit / sign / export events (no content), signer + HCPC + timestamps |

**Happy path:** Reports list → New report (kind + template + profile) → Pre-flight data check →
Generate → Sectioned editor (edit prose, correct score cells, regenerate sections, adjust tone) →
Sign-off (HCPC stamped, DRAFT removed) → Export to Word/PDF → shared via the portal.

---

## 8. Open questions (carried from the teardown)

1. **CELF composite/index rows** — confirm the exact set she reports (Core Language, Receptive/
   Expressive Language Index) so `score_table` rows are complete, **without** hosting the appendix
   that produces them (teardown §5 Q1).
2. **Third-party instrument results** (e.g. school CTOPP/TOWRE) — confirm capture as free-text
   values with `source = external`, rendered into the table with a source note (teardown §5 Q5).
3. **Draft-watermark exports** — confirm whether unsigned reports may ever leave the app (watermarked)
   or export is sign-off-gated only.
4. **Regenerate model tier** — confirm Flash-for-preview vs Pro-only via the eval harness (ADR-007 Q3).
5. **Style-profile onboarding** — confirm the redacted-exemplar ingestion path keeps PII/publisher
   content out (style only), per §4.
