# Generic Assessment / Instrument / Report Data Model & Extensibility Spec

*The conceptual data model for Sona's assessment→report cycle (Linear **DEV-101**). Defines
the versioned, config-driven entities that let a clinician upload a completed assessment,
have data extracted and verified, and generate a personalised report — while staying
**generic** across SLTs, instruments and scenarios, and **never** hosting licensed norm
tables.*

**Date:** 2026-07-01 · **Status:** Draft → In Review · **Scope:** conceptual model only —
**no PII, no publisher content, no norm/conversion tables reproduced.**

> **Reads-with:** DEV-99 teardown (`docs/research/assessment-forms-teardown.md`), the
> assessment landscape (`docs/research/SLT_SLP_Assessment_Landscape.md`), ADR-006 (FHIR/UK
> Core), ADR-001 (UK residency). Cross-references collected in §6.

---

## 0. Design goals & non-negotiables

The model exists to serve one v1 loop — **upload completed assessment → extract → clinician
verifies → generate personalised report** — but must be shaped so the *next* instrument, the
*next* SLT, and the *next* scenario are **config, not code**. Concretely:

| # | Principle | Where enforced |
|---|-----------|----------------|
| G1 | **Genericity via config.** Instruments and report templates are versioned data/DSL, never hard-coded classes. Adding CELF, VHI-10 or EAT-10 is authoring, not a deploy. | §2 (Instrument/ReportTemplate config), §3 (walk-throughs) |
| G2 | **Scores are captured, never computed.** Scaled score / percentile / composite are **inputs with `provenance = clinician`**. Sona never hosts or computes from a licensed raw→scaled→percentile table. | §1 entities, `licensed/self-scored` flag; DEV-99 §1; AGENTS.md guardrail |
| G3 | **PII separated from clinical data.** Names/DOB/contacts live in an identifier-linked PII partition; captured clinical values carry no names. Reports/exports are **producible without names** (name re-attached only at render). | §1 (Client/Case ↔ clinical split), §5 |
| G4 | **Provenance is value-level.** Every captured value knows *where it came from* (intake / uploaded doc + extraction / session note / clinician entry) and *who confirmed it*. | §1 `CapturedValue`, §5 |
| G5 | **FHIR-aligned semantics.** Entities carry the fields a UK Core serialiser needs; FHIR is an *export projection*, not native storage (ADR-006). | §4 |
| G6 | **UK residency.** All clinical + PII data lives in the UK data plane (`europe-west2`); the model is jurisdiction-tagged. | ADR-001; §4 jurisdiction gate |

---

## 1. Core entities & relationships

### 1.1 Entity map (conceptual)

```
        ┌─────────────────────────────┐         PII PARTITION (identifier-linked)
        │  ClientIdentity (PII)       │   name, DOB, sex, address, NHS no?, contacts
        │  id ─────────────────────┐  │   ── never in captured clinical values ──
        └──────────────────────────┼──┘
                                   │ 1:1 (surrogate link, no name on clinical side)
        ┌──────────────────────────▼──┐         CLINICAL PARTITION (no names)
        │  Case (episode of care)     │   clientRef, tenantRef, status, jurisdiction
        └───────┬───────────────┬─────┘
                │ 1:N            │ 1:N
     ┌──────────▼─────┐  ┌───────▼──────────────┐
     │ IntakeRecord   │  │ CapturedAssessment   │  one clinician-completed instance
     │ (QR-shaped)    │  │  ─ instrumentRef@ver │  of an Instrument, for this Case
     └────────────────┘  │  ─ administeredAt    │
                         │  ─ SourceDocument[]  │──► uploaded record forms / scans (GCS)
                         │  ─ CapturedValue[]   │──► the confirmed values (with provenance)
                         └───────┬──────────────┘
                                 │  feeds
     ┌───────────────────────────▼──────────────────────────────┐
     │ GeneratedReport  (draft → in-review → signed, versioned)  │
     │   bindsTo: ReportTemplate@ver                             │
     │   sections rendered from CapturedValue[] + IntakeRecord + │
     │   SessionNote[] + static template boilerplate             │
     └───────────────────────────────────────────────────────────┘

   CONFIG (tenant-authored, versioned, no code):
     Instrument@ver ── FieldSchema[]  (what a form captures; licensed/self-scored flag)
     ReportTemplate@ver ── Section[] ── binding → captured fields / score-table layout
```

### 1.2 Entity definitions

**`ClientIdentity` (PII partition).** The person receiving care (usually the child; the
adult client for voice/swallowing/aphasia). Holds structured name (given/family), DOB,
sex/gender, address, optional NHS number, and carer/contact details. **This is the only
place names live.** Everything clinical references it by opaque `id` only. Aligns with the
ADR-006 §5 P0 schema deltas (structured name, DOB, relationship). Contacts (parent/carer)
are modelled as related identities with a coded `relationship`.

**`Case` (clinical partition).** The episode of care for one client under one tenant
(practice). Carries `clientRef` (surrogate FK into the PII partition), `tenantRef`,
lifecycle `status`, and immutable `jurisdiction` (ADR-001). A Case aggregates intake,
captured assessments, session notes and generated reports. **No name, DOB or address on the
Case or anything under it.**

**`Instrument` / `FormTemplate` (config, versioned).** The definition of *what a given
assessment captures* — a config-driven **FieldSchema** (see §2), plus metadata:
`instrumentKey`, `edition/region` (e.g. "CELF-5 **UK**" vs "CELF-5 **US**" — regional norms
are load-bearing, landscape §3.1), `domain` (one of the 12 landscape domains), `refType`
(`norm-referenced` | `criterion-referenced` | `PRO` | `perceptual` | `instrumental`), and
the load-bearing **`scoring`** flag:

| `scoring` value | Meaning | Effect on model |
|---|---|---|
| `licensed_self_scored` | Publisher-copyright norm tables (CELF, PLS, GFTA, BPVS3, WAB-R…). | Scaled/percentile/composite fields are **capture-only, `provenance=clinician`**. No auto-score. Upload triggers a licence/attribution check (DEV-100). |
| `free_criterion` | Free / criterion-referenced / PRO with a published, non-restricted cut-off or level scheme (Communication Matrix, DAGG-3, EAT-10, CAPE-V, VHI-10…). | May carry a small published scoring rule **if licence permits**; still stored as captured values with clear provenance. Skips the licensing restriction. |
| `external_thirdparty` | Result produced elsewhere (school CTOPP/TOWRE, ENT audiology). | Captured as values with `source = external`; never re-derived. |

`FormTemplate` is **versioned** (`instrumentKey@version`): a CapturedAssessment pins the
exact version it was captured against, so a later schema edit never rewrites history.

**`CapturedAssessment`.** One clinician's completed instance of an Instrument for a Case.
Holds:
- `instrumentRef` = `instrumentKey@version` (pinned),
- `administeredAt`, `administeredBy` (clinician),
- `SourceDocument[]` — the uploaded completed record forms / scans / photos (stored in
  GCS, UK region; the **blank publisher form layout is never reproduced** — we store the
  clinician's filled artefact as an opaque document + its extracted values),
- `CapturedValue[]` — the confirmed values (below),
- `status` (`uploaded → extracted → verifying → verified`).

**`CapturedValue`.** The atomic unit of captured clinical data — **one field, one value,
with provenance.** This is where G2 and G4 live:

```
CapturedValue {
  fieldRef        // links to a FieldSchema entry (e.g. "wordClasses.scaledScore")
  value           // typed per the field (number | code | text | band | measurement)
  provenance {
    origin        // clinician_entry | extracted_from_document | intake | session_note | external
    sourceDocRef? // which SourceDocument, if extracted
    confidence?   // extraction confidence (pre-verification only)
    method        // "manual scoring off publisher table" for licensed scores (audit)
  }
  verifiedBy      // clinician id — REQUIRED before a value feeds a report
  verifiedAt
}
```

For any field whose FieldSchema `role` is `scaled_score | percentile | composite`, the
model **rejects** `provenance.origin = computed` — there is no such origin. Those values are
only ever `clinician_entry` or `extracted_from_document` (i.e. read back off the completed
form the clinician already scored). This is the data-model expression of the DEV-99 §1
bright line.

**`ReportTemplate` (config, versioned).** The clinician's own report skeleton (her IP —
DEV-99 §2). An ordered list of **Section**s; each Section declares how it is filled:
`static` (boilerplate — credentials blurb, the scaled-score explainer), `bound` (renders
from CapturedValues / intake / session notes via a binding expression), `score_table`
(a captured-score table with a declared column layout), or `ai_drafted` (drafted from
bound inputs, clinician-edited — never auto-published). Versioned; a GeneratedReport pins
the template version it was produced from.

**`GeneratedReport`.** A concrete report for a Case, bound to `ReportTemplate@version`.
Lifecycle `draft → in_review → signed`, **versioned** (each signed revision retained,
append-only — supports the 7-year audit retention in the MVP brief). Rendered content is
assembled from verified CapturedValues + IntakeRecord + SessionNotes + static boilerplate.
The name is **re-attached only at render time** from ClientIdentity (G3): a
name-free variant is always producible for exports.

**`IntakeRecord` / `SessionNote`.** Existing surfaces (intake-form-spec; DEV-99 §2.6). Both
produce CapturedValues (or their own typed rows) that bind into report sections — see §5.
Modelled here so the report engine has *one* converging source per Case.

### 1.3 PII ↔ clinical separation (G3)

```
  PII partition                         Clinical partition
  ┌───────────────────┐   surrogate     ┌────────────────────────────┐
  │ ClientIdentity    │◄── id only ─────│ Case, CapturedAssessment,  │
  │  name, DOB, addr, │   (no name      │ CapturedValue, Report…     │
  │  NHS no?, carers  │    crosses)     │  (never carry a name)      │
  └───────────────────┘                 └────────────────────────────┘
        ▲                                          │
        └──────── join happens ONLY at render ─────┘
                  (report header) / authorised export
```

- Captured clinical values, score tables and report *bodies* contain **no** identifiers.
- The report **header/identity block** (DEV-99 §4) is the only place PII is joined in, and
  only at render time by an authorised clinician.
- Exports (PDF, FHIR Bundle, DSAR) can be produced **name-suppressed** by simply not
  performing the join — the clinical record stands on its own.
- Erasure (UK GDPR Art. 17) can drop the ClientIdentity row while retaining de-identified
  clinical/audit data where lawful, because the two are physically distinct.

---

## 2. Config / DSL — adding a new instrument or report template without code (G1)

The whole point of DEV-101 is that **"not a single report looks the same"** and there are
**dozens of instruments across 12 domains** (landscape §3). Hard-coding any of them is a
trap. Instead, two authored, versioned config objects drive everything.

### 2.1 Instrument FieldSchema

A FieldSchema is a list of typed fields, each with a `role` that the report engine and the
licensing gate understand. Field types: `number`, `code` (from an enum/value-set), `text`,
`band` (a labelled qualitative band, e.g. "Within Average Range"), `measurement`
(value + unit), `boolean`. Field `role`s carry semantics:

| `role` | Semantics | Licensing behaviour |
|---|---|---|
| `raw_score` | Count captured off the form. | Captured; safe to store. |
| `scaled_score`, `standard_score`, `percentile`, `composite`, `index` | Norm-derived. | **Capture-only, provenance clinician; never computed.** |
| `severity_band` / `level` | Criterion band or level (Communication Matrix level, EAT-10 risk band). | Captured; may include a published rule if `free_criterion` + licence permits. |
| `pro_item` / `pro_total` | Patient-reported item / self-scored total. | Captured; free PRO totals may be summed if the tool's licence allows. |
| `qualitative` / `verbatim` | Free-text observation / child response. | Captured clinical data. |

### 2.2 Illustrative (synthetic, non-copyright) instrument schema

> Illustrative only — a fictional norm-referenced tool. **No real publisher items, norms or
> conversion values.** Demonstrates shape, not content.

```yaml
instrument:
  key: "example-lang-screen"
  version: 3
  title: "Example Language Screen (synthetic)"
  domain: "receptive_expressive_language"
  region: "UK"
  refType: "norm-referenced"
  scoring: "licensed_self_scored"        # ← drives the capture-only rule below
  subtests:
    - key: "word-groups"
      label: "Word Groups"
      what_it_tests: "Grouping words by meaning"
      fields:
        - { key: "raw",       role: "raw_score",     type: number }
        - { key: "scaled",    role: "scaled_score",  type: number, capture_only: true }
        - { key: "percentile",role: "percentile",    type: number, capture_only: true }
        - { key: "band",      role: "severity_band", type: band,
            options: ["Below Average","Within Average Range","Above Average"] }
        - { key: "analysis",  role: "qualitative",   type: text }
  composites:
    - { key: "core-language", role: "composite", type: number, capture_only: true }
```

`capture_only: true` is redundant with `role ∈ {scaled_score, percentile, composite}` — it
is emitted explicitly so the config reads unambiguously and a linter can assert the two
never disagree. When `scoring: licensed_self_scored`, the authoring tool **forbids** adding
any `compute:` expression to these fields.

### 2.3 ReportTemplate DSL (sections + bindings + score-table layout + conditional logic)

```yaml
report_template:
  key: "initial-assessment"
  version: 5
  title: "Initial Assessment Report"
  sections:
    - id: "credentials"
      kind: static
      content_ref: "boilerplate/hcpc-rcslt-credentials"

    - id: "score-explainer"
      kind: static
      content_ref: "boilerplate/scaled-score-explainer"     # "avg scaled = 10; range 7–13"

    - id: "background"
      kind: bound
      heading: "Relevant Background Information"
      bind: "{{ intake.summary }} + {{ ai.background_draft }}"   # ai_drafted, clinician-edited

    - id: "receptive-scores"
      kind: score_table
      heading: "Formal Assessment — Receptive"
      # renders ONLY confirmed CapturedValues; never computes a cell
      source: "capturedAssessment[instrument=example-lang-screen].subtests"
      filter: "subtest.category == 'receptive'"
      columns:
        - { header: "Subtest",      value: "subtest.label" }
        - { header: "What it tests",value: "subtest.what_it_tests" }
        - { header: "Scaled Score", value: "field.scaled",     require_verified: true }
        - { header: "% Rank",       value: "field.percentile", require_verified: true }
        - { header: "Analysis",     value: "field.band ~ field.analysis" }

    - id: "summary"
      kind: ai_drafted
      heading: "Summary of Needs"
      bind: "sections.receptive-scores + sections.background"
      requires_review: true

    - id: "recommendations"
      kind: bound
      heading: "Recommendations"
      bind: "{{ targets }} + {{ clinician.recommendations }}"

  conditional:
    # DEV-99 §2.3 informal branch: no standardized test → drop score tables
    - when: "case.assessment_kind == 'informal'"
      hide: ["score-explainer","receptive-scores","expressive-scores"]
    # DEV-99 §2 recommendation: statutory-plan variant is a branch, not a new template
    - when: "case.statutory_plan == true"
      insert_after: "background": "boilerplate/purpose-of-report"
```

Design consequences captured here:
- **Score tables render only `require_verified: true` captured values** — the engine has no
  path to a raw→scaled computation (G2, DEV-99 §4).
- **One engine, config branches** — the Initial Assessment / Annual Review / Informal
  variants (DEV-99 §2.1–2.3) are `conditional` branches on **one** template family, per the
  teardown's explicit recommendation, not three code paths.
- **Static boilerplate stays static** — the credentials blurb and the scaled-score
  explainer are `content_ref` includes, never AI-generated (DEV-99 §4).
- **AI sections are `requires_review`** — never auto-published (MVP brief principle #2;
  ADR-006 gates unreviewed drafts out of any export).

---

## 3. Genericity validation — the model beyond CELF (G1)

To prove the model isn't CELF-shaped, walk three landscape instruments of different
`refType`/`scoring` classes through the **same** entities. Each is just a different
`Instrument@ver` + `ReportTemplate` binding — no new tables.

### 3.1 CELF-5 UK — norm-referenced, licensed (the v1 anchor)

| Model element | Value |
|---|---|
| `Instrument.scoring` | `licensed_self_scored` |
| `refType` / `domain` / `region` | norm-referenced / receptive_expressive_language / **UK** |
| FieldSchema roles | per-subtest `raw_score`, `scaled_score` (capture-only), `percentile` (capture-only), `severity_band`, `qualitative`, `verbatim`; `composite` (Core Language etc.) |
| CapturedValue provenance | scaled/percentile = `clinician_entry` or `extracted_from_document`, **never computed**; `method = "manual scoring off Pearson Appendix"` |
| Report binding | `score_table` (Receptive / Expressive), `require_verified: true` |
| Licensing gate | **on** — upload triggers DEV-100 licence/attribution check; no norm table hosted |

This is exactly DEV-99 §3's capture surface, expressed as config.

### 3.2 Communication Matrix (or DAGG-3) — criterion-referenced, free (early/AAC)

An early-communication / AAC profile scored against **7 communicator levels**, not norms
(landscape §3.6/§3.12). Same entities, different config:

| Model element | Value |
|---|---|
| `Instrument.scoring` | `free_criterion` — **skips the licensing restriction** (G2 exemption) |
| `refType` / `domain` | criterion-referenced / early_language (or AAC) |
| FieldSchema roles | per-behaviour `level` (`code` from the tool's 7-level value-set), `qualitative`; **no** scaled/percentile fields exist |
| CapturedValue provenance | `clinician_entry`; a published level-assignment rule *may* be applied because the tool is free/criterion and its licence permits |
| Report binding | a **level-profile** section (`kind: bound`, tabular by domain × level) — *not* a scaled-score table; the score-table columns simply aren't declared |
| Licensing gate | **off** — `free_criterion` short-circuits the DEV-100 check |

Proof point: the model expresses "there is no scaled score here" simply by the schema not
declaring those roles — no special-casing. The `licensed/self-scored` flag makes the
licensing behaviour a **data attribute**, exactly as AGENTS.md and DEV-99 §1 require.

### 3.3 EAT-10 / VHI-10 — adult PRO, self-scored (swallowing / voice)

A patient-reported outcome: EAT-10 is a 10-item swallowing self-report with a published risk
cut-off (≥3); VHI-10 a 10-item voice-handicap self-report (landscape §3.11/§3.4). Same
entities again:

| Model element | Value |
|---|---|
| `Instrument.scoring` | `free_criterion` (free clinical-use PRO) |
| `refType` / `domain` / `population` | PRO / dysphagia (or voice) / adult |
| FieldSchema roles | 10 × `pro_item` (`number`, 0–4), `pro_total` (`number`), `severity_band` (risk flag) |
| CapturedValue provenance | items = `intake`/`clinician_entry` (patient-completed, entered); `pro_total` **may be summed** because the instrument's own scoring is a published free rule — captured with `method="published PRO sum"`, still provenance-tagged |
| Report binding | a compact PRO block (`kind: bound`): item responses + total + cut-off interpretation |
| Licensing gate | **off** |

Proof point: the model spans **pediatric norm-referenced → criterion/AAC → adult PRO**, and
**child SLT → adult voice/swallowing**, with no schema change — only different `Instrument`
config and `ReportTemplate` bindings. It also correctly distinguishes the two scoring
regimes: **licensed norm tools are capture-only; free PRO/criterion tools may carry their own
published, non-restricted scoring rule.**

---

## 4. FHIR R4 / UK Core mapping (G5, aligned with ADR-006)

FHIR is an **export projection** over the relational model, not native storage (ADR-006 §1).
The DEV-101 entities map onto UK Core STU2 (`2.0.2`) resources as follows. Where ADR-006
already fixed a mapping (intake, reports, progress), we align; the assessment-specific
entities (`Instrument`, `CapturedAssessment`, `CapturedValue`) extend it consistently.

| DEV-101 entity | FHIR R4 / UK Core resource | Notes / alignment |
|---|---|---|
| `ClientIdentity` (child) | `UKCore-Patient` | Structured name + DOB + gender = ADR-006 §5 P0 deltas. The **only** PHI-bearing resource. |
| `ClientIdentity` (carer) | `UKCore-RelatedPerson` | Coded `relationship` (ADR-006 §5). |
| `Case` | base R4 `EpisodeOfCare` (+ `ServiceRequest` for referral) | ADR-006: no UKCore-EpisodeOfCare in STU2 → base R4. |
| `Instrument` / `FormTemplate` | `Questionnaire` (`UKCore-Questionnaire`) | The **definition** — its FieldSchema fields become `Questionnaire.item[]` with stable `linkId`s. Versioned → `Questionnaire.version`. |
| `CapturedAssessment` | `QuestionnaireResponse` (`UKCore-QuestionnaireResponse`) | The clinician-completed instance; `QR.questionnaire → Instrument@ver`; `QR.item.linkId` matches the schema. `QR.status = completed` once verified. |
| `SourceDocument` (uploaded form) | `UKCore-DocumentReference` | The filled record-form scan; `content.attachment.url` → GCS (referenced, not inlined). Blank publisher layout never stored/emitted. |
| `CapturedValue` — score fields | `Observation` (base R4) | Each verified scaled/percentile/composite = an `Observation` (`valueQuantity`/`valueInteger`); `Observation.derivedFrom → QuestionnaireResponse`; **`performer = clinician`** encodes provenance = clinician (never a device/rule). Qualitative bands → `valueCodeableConcept`/`valueString`. |
| `CapturedValue.provenance` | `Provenance` (Year-2) / `Observation.performer` + `.method` | v1 carries provenance inline (performer + method text); richer `Provenance` deferred (ADR-006 §5 P2). |
| `GeneratedReport` | `DiagnosticReport` **+** `Composition` **+** `DocumentReference` | The report *as a clinical result set* = `DiagnosticReport` (`.result →` the score `Observation`s, `.conclusion` = summary); `Composition.section` mirrors the ReportTemplate sections; the rendered PDF = `DocumentReference`. Only a **signed** report exports (analogous to ADR-006's "reviewed drafts only" rule). |
| `IntakeRecord` | `QuestionnaireResponse` + `Consent` | Per ADR-006 (intake mapping) — same converging pattern. |
| `SessionNote` / progress | `Observation` / `CarePlan` | Per ADR-006 (`progressEntries → Observation`). |

`DiagnosticReport` is the natural home for a formal assessment report because it *is* "a set
of observations + an interpretation" — the score `Observation`s are its `result`s and the
clinician's summary is its `conclusion`. This is the assessment-cycle extension of ADR-006's
`aiDrafts[kind=clinical_report] → DocumentReference + Composition` mapping, adding the
structured score layer.

**Jurisdiction (ADR-001):** the export mapper asserts `tenant.jurisdiction = 'uk'` and runs
entirely inside `europe-west2` before emitting any UK Core resource. No cross-jurisdiction
export.

**Provenance in FHIR:** the capture-only guarantee survives the projection — score
`Observation`s always have a **human `performer`** and never a `Device`/rule as the source,
so a downstream consumer cannot mistake a captured scaled score for a computed one.

---

## 5. Capture-once flow — one client record feeds every report (G4)

The clinician should enter each fact **once**. Intake, uploaded assessment data and session
notes all converge into **one Case**, producing verified `CapturedValue`s (with value-level
provenance) that every report binds to.

```
  ┌─────────────┐   ┌──────────────────────┐   ┌────────────────┐
  │ Parent      │   │ Uploaded completed   │   │ Clinician      │
  │ intake form │   │ assessment forms     │   │ session notes  │
  │ (magic link)│   │ (CELF record form…)  │   │ (per-session)  │
  └──────┬──────┘   └──────────┬───────────┘   └───────┬────────┘
         │ answers             │ Gemini/Vertex          │ typed / dictated
         │                     │ extraction             │
         ▼                     ▼                         ▼
   provenance=intake   provenance=extracted_from_doc   provenance=session_note
         │                     │  (+confidence)          │
         └─────────────┬───────┴─────────────────────────┘
                       ▼
              ┌───────────────────────────┐
              │  CLINICIAN VERIFY STEP     │  ← the human gate (HCPC in-the-loop)
              │  each value: confirm/edit  │     scaled/percentile confirmed off the
              │  → verifiedBy, verifiedAt  │     publisher's own table (never computed)
              └─────────────┬─────────────┘
                            ▼
              ┌───────────────────────────┐
              │  ONE Case record          │  verified CapturedValue[] + IntakeRecord
              │  (clinical partition,     │  + SessionNote[]  — NO names
              │   no PII)                 │
              └─────────────┬─────────────┘
             binds ⟶        │        ⟶ binds
      ┌──────────────┬──────┴───────┬───────────────┐
      ▼              ▼              ▼               ▼
 Initial Assess.  Annual Review  Target Setting  Block Summary
 (score tables)   (score tables) (targets)       (session roll-up)
      │              │              │               │
      └────── name re-attached ONLY at render (from ClientIdentity) ──────┘
```

Key properties:
- **Extraction never scores.** Gemini extracts what the clinician *already wrote* (raw,
  scaled, percentile, verbatim, qualitative) from the uploaded form; it never derives a
  scaled score from a raw score (DEV-99 §1; AGENTS.md). Extracted score values carry
  `origin = extracted_from_document` + confidence, and still require the verify step.
- **Verify is mandatory before binding.** No CapturedValue feeds a report until
  `verifiedBy` is set — the report engine's `require_verified` (§2.3) enforces it.
- **One value, many reports.** A verified Core Language composite entered once appears in
  the Initial Assessment *and* the Annual Review with no re-keying — the reports **bind**,
  they don't copy.
- **Provenance travels with the value**, so any report cell / FHIR `Observation` can answer
  "where did this come from and who confirmed it?" — supporting audit and DSAR.
- **Third-party results** (school CTOPP/TOWRE — DEV-99 §5 open question) enter the same way
  with `origin = external`, `Instrument.scoring = external_thirdparty`.

---

## 6. Cross-references

| Reference | What it fixes for this model |
|---|---|
| **DEV-99** teardown — `docs/research/assessment-forms-teardown.md` | The 7 report templates, the CELF capture surface (§3), the report-section→captured-input map (§4), and the **§1 licensing bright line** this model encodes as the `licensed/self-scored` flag and capture-only score roles. |
| **DEV-100** licensing guardrails — `docs/compliance/instrument-licensing-guardrails.md` *(to be written)* | The upload-time licence/attribution check that the `scoring` flag switches on/off; the "no hosted norm table / no auto-score" rule this model must never violate. |
| **ADR-006** — `docs/decisions/006-fhir-r4-uk-core-alignment.md` | The FHIR/UK Core projection (§4): QuestionnaireResponse / DocumentReference / Observation / DiagnosticReport / Composition mappings, emit-only, reviewed-drafts-only, STU2 `2.0.2` pinning. |
| **ADR-001** — `docs/decisions/001-data-residency-jurisdiction-stacks.md` | UK residency: all PII + clinical data and any FHIR export stay in the UK plane (`europe-west2`); jurisdiction is immutable on the Case. |
| Landscape — `docs/research/SLT_SLP_Assessment_Landscape.md` | The 12 domains, norm/criterion/PRO split, regional editions, and the specific instruments used to validate genericity in §3. |
| `docs/intake-form-spec.md`, `docs/mvp-brief.md` | The existing intake surface that converges into the Case (§5) and the clinician-in-the-loop / no-model-training / UK-GDPR principles. |
| `AGENTS.md → Guardrails` | The licensed-instrument guardrail this model operationalises (per-instrument flag; provenance = clinician, never computed). |

### Open questions (carried / new)

1. **Composite/index set per instrument** (from DEV-99 §5.1): confirm the exact captured
   composite rows per instrument version — a *config* question (add fields to the
   FieldSchema), not a schema change.
2. **Extraction confidence thresholds:** what confidence auto-flags a value for closer
   clinician attention in the verify step (§5)? Tuning, not modelling.
3. **PRO self-scoring boundary:** confirm per-PRO that summing a `pro_total` (EAT-10/VHI-10)
   is within its free-use licence before enabling the rule (§3.3) — default is capture-only
   until confirmed.
4. **`Provenance` resource:** v1 carries provenance inline (performer + method); confirm
   whether any Year-2 consumer needs full FHIR `Provenance` (ADR-006 §5 P2).
```
