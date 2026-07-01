# Assessment Forms & Report Templates — Teardown

*Foundational teardown for the v1 assessment→report cycle (Linear **DEV-99**). Maps every
real form/report the design partner uses → its structure → the data it captures → which
report sections that data feeds → and the hard line between **the clinician's own captured
data** (ours to store) and **licensed-instrument content** (never ours to host).*

**Date:** 2026-07-01 · **Status:** Draft → In Review (pending approval) · **Data:** structure only, **no PII, no publisher content reproduced**

---

## 0. Sourcing & handling note (read first)

- Source material: the design partner's **redacted** report templates (7 files, her own IP)
  and the **Pearson CELF-5 UK** record forms + scoring-manual appendices, received 2026-07-01.
- The raw files were analysed **in-session only** and are **not committed**: the templates
  carry the clinician's contact details + client initials/partial address (PII), and the CELF
  PDFs are **Pearson copyright**. This document reproduces **neither** — only structural shape.
- Client examples are generalised to age bands / "the client"; no names, initials, DOBs,
  addresses, or contact details appear here.

---

## 1. The load-bearing constraint — licensed norm tables (⚠️ decision, not a preference)

> **We cannot use the CELF (or any licensed instrument's) norm/conversion tables. The SLT
> derives every scaled score, index/composite score and percentile rank *manually*, off the
> publisher's own tables, and enters/uploads the finished value. Sona stores and tabulates
> only the value the clinician produced. Sona never hosts, embeds, ships, or computes from a
> licensed raw→scaled→percentile lookup table.**

Why this is the whole reason v1 is "upload the completed form" rather than "digitise CELF":

- The Pearson CELF-5 UK kit includes three **conversion appendices** — **Appendix A** (test →
  scaled scores), **Appendix B** (core language & index/composite scores), **Appendix D**
  (percentile ranks). These lookup tables **are** the commercial IP of the instrument.
  Reproducing them, or auto-computing a scaled score/percentile from them, would embed Pearson's
  copyrighted norms in our product — the exact thing licensing forbids.
- Therefore the scoring step stays **manual and human**: the clinician reads the raw score she
  recorded, looks it up in the publisher's appendix, and writes down the scaled score + percentile.
  Sona's job starts **after** that: capture the confirmed scaled score / percentile / analysis,
  and lay them into the report's score table automatically (removing the *re-keying*, not the
  *scoring*).

**Design consequences (must hold across every spec):**

| Where | Rule |
|---|---|
| Extraction (DEV-102/104) | Extract the **raw scores, scaled scores, percentiles, and verbatim/qualitative content the clinician already wrote**. Never derive a scaled score/percentile from a raw score. |
| Report engine (DEV-105) | The score table is built from **confirmed captured values**, not model prose and not a hosted norm table. No "auto-score" feature that maps raw→scaled internally. |
| Data model (DEV-101/109) | Scaled score / percentile are **captured inputs with provenance = clinician**, not computed fields. |
| Licensing guardrails (DEV-100) | Codify the bright line + a licence/attribution check at upload. |
| Repo | See the new **AGENTS.md → Guardrails** bullet on licensed instruments. |

Generalisation: the same rule applies to **any** norm-referenced instrument in
`SLT_SLP_Assessment_Landscape.md` (PLS-5, GFTA-3, CASL-2, BPVS3, WAB-R, …). Some tools are free
/ criterion-referenced (Communication Matrix, DAGG-3, CAPE-V, EAT-10) and have no such
restriction — the model must carry a per-instrument `licensed / self-scored` flag so this is a
data attribute, not a special case.

---

## 2. Report templates teardown (the clinician's own IP — 7 files)

Common shape across the formal reports: a **header/identity block**, a **standing HCPC/RCSLT
credentials blurb**, then personalised prose sections, and (for CELF-based reports) a **score
table**. "Not a single report looks the same" — the prose is bespoke per client; the *skeleton*
is stable and templatable.

### 2.1 Initial Assessment Report — *the flagship £495 formal assessment*
- **Instrument:** CELF-5 UK (named subtests), plus classroom observation + informal.
- **Header block:** student name, DOB, date of assessment, **age at assessment**, school, parents, home address, therapist.
- **Sections (in order):** credentials blurb → **Relevant Background Information** → **Assessment, Observations & Findings** = { Classroom Observation, Child's Views, **Formal Assessment** (subtest **score tables**) } → Summary → Recommendations.
- **Score table shape (confirmed):** `Receptive Subtest | What it tests | Scaled Score | % Rank | Analysis`, and an equivalent **Expressive Subtest** block. Subtests seen: Word Classes, Following Directions, Semantic Relationships (receptive) and the expressive counterparts. Values are the manually-derived scaled score + percentile + a plain-language band ("Within Average Range").
- **Standing explainer text:** "raw score is converted to a scaled score… average scaled score is 10… normal range 7–13." (Boilerplate → belongs in the template, not generated.)

### 2.2 Annual Review Report — *EHCP / statutory annual review*
- **Instrument:** CELF-5 UK + clinical observation; incorporates prior reports & school provision.
- **Header block:** student name, DOB, date of assessment, date of report, school, **year group**, **class teacher**.
- **Sections:** credentials blurb → **Purpose of Report** → **Relevant Background Information** → **1:1 Assessment** = { Child's Views, Attention & Listening Skills, **Formal Assessment** (score tables) } → Summary of Needs → Recommendations → Next Steps.
- Same score-table shape as 2.1. This template is the statutory-plan branch (EHCP is one example; keep statutory-plan handling generic).

### 2.3 Initial Consultation Report (Informal) — *under-4 / nursery, no standardized test*
- **Instrument:** none standardized — parent discussion + nursery feedback + informal observation.
- **Sections:** **Purpose of Report** → **Background Information** = { Developmental & Medical History, Early Communication Development, Nursery Information } → **Assessment** = { Class Observation, sensory/motor observations } → Recommendations.
- No score table. This is the "informal write-up" branch (lower price, preschool cohort).

### 2.4 Target Setting Report — *targets pack (the "program"/plan targets)*
- **Header:** client name, date of review, therapist.
- **Body:** `TARGET 1..N`, each = a measurable target statement (criterion e.g. "in 4/5 opportunities, with visual modelling") + **Carryover for School** + **Carryover for Home**.
- **Design signal:** the School vs Home carryover split is first-class → maps directly to the parent-portal + **separate school-access path** (DEV-108) and homework/resource assignment (DEV-107).

### 2.5 Therapy Block Summary Report — *end-of-block (5/10) progress summary*
- **Header:** client name, therapy-block date range, therapist.
- **Body:** **Summary of Strategies Taught** — each strategy = { Purpose · How to Continue at Home · Why It Helps }. Composed from what happened across the block.
- **Design signal:** cleanly rolls up from per-session feedback (2.6) → DEV-106 (end-of-block report auto-composed from session notes).

### 2.6 Therapy Session Feedback Notes — *per-session ("N of 10")*
- **Header:** client name, **date of session + position in block (e.g. "5 of 10")**, therapist.
- **Body:** **Target areas for the block** → **"What We Worked On"** table (activity/strategy → notes), with **references to attached video clips** ("see video clip 5 attached") → **Next Steps** → **next session date/time**.
- **Design signals:** (a) this is the artifact she's dropped to WhatsApp for — DEV-106's fast capture targets it; (b) **video-clip attachments** confirm the non-forwardable video/resource requirement (DEV-107/108); (c) target areas link a session to its block/plan.

### 2.7 Professional Subs (xlsx) — *her expense/subscription tracker*
- Out of the assessment→report core; it's the monthly professional-subscription figure noted as a design-partner action item (cost-offset framing). Not a report template — logged here for completeness only.

---

## 3. CELF-5 UK capture surface (Pearson — structure only, analyse-only)

Two artifacts, opposite sides of the licensing line:

| Artifact | What it is | Our stance |
|---|---|---|
| **Record Form 1 (Ages 5–8)**, **Record Form 2 (Ages 9–21)** | The clinician's **capture surface**: per-subtest trial rows where she records **raw scores**, **verbatim child responses**, and **qualitative observations**, plus a summary/score-transfer page. | The *values she writes* are her captured clinical data → ours to capture (via upload+extraction) and store. The blank form layout itself is Pearson IP → we don't reproduce it; we model the **data**, not the form. |
| **Scoring Manual Appendix A / B / D** | The **norm/conversion tables** (raw→scaled, core-language/index, percentile ranks). | **Licensed IP — never hosted, embedded, shipped, or computed from.** Used by the clinician manually (see §1). |

Captured-data fields the record forms yield (to model generically in DEV-101/109):
`subtest name`, `raw score`, `scaled score` (clinician-derived), `percentile rank`
(clinician-derived), `analysis/band` (free text), `verbatim responses` (per trial),
`qualitative observations` (free text), plus derived **composite/index scores** (also
clinician-derived). Every score field's provenance = **clinician**, never **computed**.

---

## 4. Report-section → captured-input mapping (feeds DEV-105 report engine)

| Report section | Fed by |
|---|---|
| Header / identity block | Case/PII record (intake) — identifier-linked, name re-attached only at render (DEV-109) |
| Credentials blurb, scaled-score explainer | Static template boilerplate (not generated) |
| Relevant Background Information | Intake questionnaire + AI intake summary (DEV-110) |
| Classroom / class observation | Clinician session/observation notes (captured, DEV-104/106) |
| Child's Views | Clinician-captured qualitative notes |
| Attention & Listening | Clinician-captured qualitative notes |
| Formal Assessment **score table** | **Confirmed captured** subtest scaled scores + percentiles + analysis (§3) — laid out automatically, never computed |
| Summary / Summary of Needs | AI-drafted from the above, clinician-edited |
| Recommendations / Next Steps / Targets | Clinician input + Target Setting (2.4) |
| Carryover (School / Home) | Target/session data → portal + school-access (DEV-107/108) |

---

## 5. Open questions / follow-ups

1. **CELF composite/index scoring:** confirm the exact set of composite/index scores she reports (Core Language, Receptive/Expressive Language Index, etc.) so the template's table rows are complete — **without** hosting the appendix that produces them.
2. **Report variants:** are 2.1/2.2 one templatable skeleton with a statutory-plan branch, or two templates? (Recommend: one engine, statutory-plan as a config branch, per generalisation guardrails.)
3. **Informal (2.3) score-free path:** confirm it never needs a table, so the engine treats the score table as an optional bound section.
4. **Video-clip handling** in session feedback (2.6): confirms DEV-107/108 scope — verify max clip length/consent expectations with the partner.
5. **Other instruments:** the reports already reference school-run CTOPP/TOWRE results — confirm whether Sona captures *third-party* instrument results too (likely yes, as free-text captured values with a `source = external` flag).

---

## 6. Cross-references
- Licensing guardrails: **DEV-100** · `docs/compliance/instrument-licensing-guardrails.md` (to be written)
- Generic data model: **DEV-101** · Capture-once IA: **DEV-109**
- Extraction: **DEV-102 / DEV-104** · Report engine: **DEV-105** · Session/progress: **DEV-106**
- Landscape (extensibility direction): `docs/research/SLT_SLP_Assessment_Landscape.md`
- Repo guardrail: `AGENTS.md → Guardrails (do not violate)` — licensed-instrument bullet
