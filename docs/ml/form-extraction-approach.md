# Document Ingestion & Extraction — Technical Approach (SPIKE)

*Approach/de-risking doc for **DEV-102**: ingest completed, often handwritten, multi-page
assessment forms and extract the clinician's captured data into a structured schema for
clinician verify/correct. Extraction runs on **Gemini on Vertex AI** (per ADR-007), behind a
provider-agnostic client and the eval-harness gate.*

**Status:** Draft (spike) · **Date:** 2026-07-01 · **Owner:** ML · **Data:** design only —
**no live inference run here**; the live eval is a credentialed follow-up (see §7).

> **This is a spike, not an implementation.** No prompts have been run against Vertex. All
> accuracy claims below are *design targets and hypotheses*, to be confirmed by the eval in §5
> once GCP/Vertex credentials are provisioned (human-gated — see §5.4 and §8).

---

## 1. The extraction problem

A completed assessment form arrives as an **image or PDF** — photographed or scanned by the
clinician, frequently on a phone, in variable lighting, at an angle, sometimes with shadow,
glare, or a folded page. A single case commonly spans **multiple pages** and mixes:

- **Handwriting** — the clinician's own hand, in the record-form trial rows: raw scores,
  ticks/crosses, verbatim child responses, and free-text qualitative observations. Legibility
  varies; there is crossing-out, marginalia, and shorthand.
- **Pre-printed structure** — the publisher's form layout (row labels, subtest names, column
  headers) is machine print interleaved with the handwriting.
- **Tables / score grids** — a summary or score-transfer page laid out as a grid, where the
  meaning of a value depends on its **row (subtest)** and **column (raw / scaled / percentile /
  analysis)**. Mis-associating a value with the wrong row or column is a *clinically material*
  error, not a cosmetic one.
- **Varied instruments** — the pipeline must be framed **generically**, not built around one
  form. Different instruments (and different age-band record forms of the same instrument) have
  different page counts, row sets, column sets, and scoring vocabularies. Some are
  norm-referenced; some are criterion-referenced/free with no score conversion at all. The
  system must treat "which instrument / which form" as data, not as a hard-coded assumption.

**What we extract vs. what we must never do (load-bearing licensing line).** We extract *only
the values the clinician has already written*: **raw scores, scaled scores, percentile ranks,
composite/index scores, verbatim responses, and qualitative free-text**. Every score field
carries **provenance = clinician**. We **never** derive a scaled score or percentile from a raw
score, never host/embed/ship a raw→scaled→percentile conversion or norm table, and never build
an "auto-score" feature. The clinician scores manually off the publisher's own appendices;
extraction begins *after* that step and removes the *re-keying*, not the *scoring*. (See
`docs/research/assessment-forms-teardown.md §1` and `AGENTS.md → Guardrails → Licensed
instruments`.)

**Output contract.** Extraction emits a structured record matched to the generic capture model
(DEV-101/109): per-instrument, per-subtest rows of `{ subtest, raw_score, scaled_score,
percentile_rank, analysis_band, verbatim_responses[], qualitative_observations }`, plus
composite/index rows — each field tagged with `provenance = clinician` and a **per-field
confidence signal** (§2.5) to drive the human verify/correct UX. Direct identifiers are handled
in our own layer and are **not** part of the model's task (§6).

**Success criteria for v1.** (a) The clinician spends materially less time than re-keying by
hand; (b) no fabricated values — a low-confidence or unreadable cell surfaces as
"needs-review", never a guess presented as fact; (c) table cells land in the correct
row/column; (d) the approach generalises to a new instrument by adding a form template/schema,
not by re-engineering the pipeline.

---

## 2. Approach options and recommendation

### 2.1 Recommended: Gemini multimodal on Vertex with schema-guided structured output

**Shape of the approach.** Send the page image(s) to a Gemini multimodal model on Vertex AI
(region-pinned `europe-west2`, per ADR-007) with:

1. A **structured-output / response schema** (constrained JSON) describing exactly the fields to
   emit for the identified instrument/form, so the model returns a typed object rather than free
   prose we then have to parse. The schema is **generic + per-form**: a base capture schema plus
   a form template that supplies the expected subtest rows and column set.
2. A **task prompt** that (a) states the extraction-only, never-derive rule explicitly ("copy
   the value written in the cell; if a cell is blank or illegible, return null and flag it — do
   **not** compute or infer a score"), (b) instructs verbatim transcription for response and
   qualitative fields, and (c) requires a per-field confidence and a short evidence locator
   (page + approximate region/row label) for traceability.
3. **Page/segment handling** (§2.2) and **table handling** (§2.3) so multi-page and grid
   structure survive.

**Why this over the alternatives.** A single multimodal model that jointly reads the print
scaffold *and* the handwriting *and* the spatial table layout avoids the brittle hand-off of a
classic OCR→layout→LLM pipeline, where OCR errors on handwriting poison everything downstream
and table structure has to be reconstructed from bounding boxes. It also keeps us on the
**one** managed provider we have already done the compliance work for (ADR-007), behind the
provider-agnostic client, so there is no second vendor/DPA to clear for the pilot.

### 2.2 Page segmentation

- **Split the document into pages** in our layer before inference; treat each page as a unit
  with a stable `page_index`. Do not rely on the model to keep a 6-page PDF coherent in one
  shot.
- **Classify each page** to a role (e.g. cover/identity, trial/response page, summary/score
  table, notes) using a lightweight first pass — either a cheap Gemini Flash call or a template
  match against the identified form. Routing lets us send the *score-table* page down the
  table-extraction path (§2.3) and *response* pages down the verbatim-transcription path, each
  with a tighter schema and prompt.
- **Identify the instrument/form + age-band variant** early (from the page set or a
  clinician-selected value at upload). This selects the correct form template/schema and the
  `licensed / self-scored` flag, and avoids asking the model to guess the form.
- Multi-page assembly (stitching per-page results into one case record, de-duping the transfer
  of a value that appears on both a trial page and the summary page) happens **in our layer**,
  deterministically — not in the model.

### 2.3 Table / score-grid extraction

- For the score-transfer/summary page, use a **row-anchored schema**: the form template supplies
  the expected subtest rows; the model fills each row's columns (`raw`, `scaled`, `percentile`,
  `analysis`) rather than emitting a free-form 2-D array we then have to align. Anchoring on
  known row labels is the single biggest defence against row/column mis-association.
- Require the model to return, per cell, the **written value verbatim** plus **confidence**;
  blanks return `null` + `blank` (not a fabricated 0).
- **Cross-check, in our layer:** where the same subtest's scaled score appears on both a trial
  page and the summary page, compare them; a mismatch is auto-flagged for review. This is a
  cheap, deterministic consistency signal that needs no norm table.
- **Never** reconstruct a missing scaled score/percentile from the raw score to "complete" the
  table — a missing value stays missing and is surfaced for the clinician (§1 rule).

### 2.4 Handwriting handling

- Rely on Gemini's native multimodal handwriting reading rather than a separate handwriting-OCR
  stage; the model sees the printed row label next to the handwritten value, which gives it
  disambiguating context a bare OCR pass lacks.
- **Bias towards abstention over invention.** The prompt and schema make "unsure" a
  first-class, cheap outcome: low-confidence transcription → flag, don't guess. For clinical
  numbers a wrong-but-confident digit is worse than an honest "please check".
- **Preserve ambiguity for the clinician** where useful: for a hard-to-read response, return the
  best transcription *and* mark low confidence so the verify UX shows the source crop next to
  it (§2.5, §5.3).
- Image quality is a first-class input: capture-time guidance (well-lit, flat, one page per
  shot) and a pre-inference quality check reduce the hardest handwriting cases at source.

### 2.5 Per-field confidence signalling (drives the verify/correct UX)

Every extracted field carries a **confidence signal** and an **evidence locator** (page +
region/row). Confidence is derived from a combination of: the model's own
self-reported/structured confidence, source image-quality for that region, and our
deterministic cross-checks (§2.3). This directly powers the human-in-the-loop UX (DEV-104):

- **High confidence** → pre-filled, single glance to confirm.
- **Medium** → pre-filled but visually marked "please check".
- **Low / blank / cross-check mismatch** → **always** routed to mandatory review, source crop
  shown, never auto-accepted.

Note that self-reported model confidence is *not* trustworthy on its own; §5 measures how well
each confidence tier actually predicts correctness (calibration), and which field types must be
**always double-checked** regardless of reported confidence.

### 2.6 Alternatives considered (briefly)

| Option | Summary | Verdict |
|---|---|---|
| **A. Google Document AI (Form/OCR parsers) → LLM** | Purpose-built OCR + form/layout parsers produce text + bounding boxes; an LLM then maps to schema. Strong on clean printed forms and native table structure. | **Not recommended as primary.** Weaker on *messy handwriting* and bespoke/varied instrument layouts without custom-processor training per form; adds a second processing stage (and possibly a second data-handling surface to compliance-clear). Keep as a **possible pre-processor** (e.g. deskew/OCR text as an auxiliary signal) and as a benchmark in the eval. |
| **B. Generic OCR (Tesseract/cloud OCR) + LLM reconstruction** | Cheap OCR text, LLM rebuilds structure. | **Not recommended.** Generic OCR is poor on handwriting; table structure is lost and must be re-inferred from coordinates — brittle exactly where we need reliability (score grids). |
| **C. Gemini multimodal + schema-guided structured output** (§2.1) | One model reads print + handwriting + layout jointly, emits typed JSON to our schema, per-field confidence. | **Recommended.** Best handwriting + varied-layout robustness, single already-compliant provider, provider-agnostic client keeps exit cheap. |
| **D. Self-hosted multimodal model** | Air-gapped, maximal isolation. | **Deferred** to the ADR-003 fallback posture. Not justified at pilot scale/cost; revisit only if a tenant contractually requires true air-gap. |

**Recommendation:** proceed with **Option C** (Gemini multimodal on Vertex, schema-guided,
page-segmented, row-anchored tables, per-field confidence), benchmarked against **Option A** in
the eval so the choice is evidence-backed, not assumed.

### 2.7 Model selection within Vertex (Flash vs Pro)

- **Flash** for page classification/routing (§2.2) and for clean printed/low-stakes fields —
  cheap and fast.
- **Pro** for the hard extraction surfaces where accuracy dominates cost: **handwritten trial
  rows** and the **score table**. A getting-the-scaled-score-wrong error is expensive
  clinically; the per-document cost delta (§7) is trivial at pilot volume.
- Final split is decided by the eval (§5), not asserted here — mirrors ADR-007 Open Q3 (Flash
  vs Pro per artifact kind, chosen on quality-vs-cost).

---

## 3. Pipeline (end to end, our-layer responsibilities in **bold**)

```
Upload (image/PDF, multi-page)
   │  ── clinician optionally selects instrument + form/age-band variant
   ▼
**Ingest & normalise**  ─ split to pages, deskew/enhance, per-page image-quality score,
   │                      **strip/withhold identifier regions from what inference sees (§6)**
   ▼
**Page classify & route**  ─ role per page (identity / trial / score-table / notes)
   │                          + confirm instrument/form template + licensed/self-scored flag
   ▼
Gemini on Vertex (europe-west2, via provider-agnostic client, ZDR)
   │   ├─ trial/response pages → verbatim + qualitative, schema-guided, per-field confidence
   │   └─ score-table page     → row-anchored grid, per-cell value + confidence  (NEVER derive)
   ▼
**Assemble & validate**  ─ stitch pages → one case record, dedupe transfers,
   │                        **deterministic cross-checks (trial vs summary), confidence tiering**
   ▼
**Re-attach identifiers in our layer**  (identifier ↔ case id map, §6)
   ▼
Clinician verify/correct UX (DEV-104)  ─ high=confirm · medium=check · low/blank/mismatch=mandatory review
   ▼
Confirmed captured values → generic data model (DEV-101/109) → report score table (DEV-105)
```

Everything that touches identifiers, norm/consistency logic, and multi-page assembly is
**deterministic and in our layer**. The model's job is narrow: read what is on the page into the
schema, honestly, with confidence.

---

## 4. Structured-output schema (illustrative shape)

Illustrative only — the authoritative model is DEV-101/109. Values are transcribed, never
computed.

```jsonc
{
  "instrument": { "id": "…", "form_variant": "…", "licensed": true },   // selected, not guessed
  "pages": [ { "page_index": 0, "role": "score_table", "image_quality": 0.83 } ],
  "subtests": [
    {
      "subtest": "…",                       // from form template (row-anchored)
      "raw_score":       { "value": 12,   "confidence": "high",   "provenance": "clinician",
                           "evidence": { "page_index": 2, "row_label": "…" } },
      "scaled_score":    { "value": 8,    "confidence": "medium", "provenance": "clinician", … },
      "percentile_rank": { "value": 25,   "confidence": "low",    "provenance": "clinician", … },
      "analysis_band":   { "text": "Within Average Range", "confidence": "high", … },
      "verbatim_responses": [ { "trial": 3, "text": "…", "confidence": "low", … } ],
      "qualitative_observations": { "text": "…", "confidence": "medium", … }
    }
  ],
  "composites": [ { "name": "…", "value": null, "confidence": "blank", "provenance": "clinician" } ],
  "flags": [ "cross_check_mismatch:subtest_X.scaled", "blank:composite.core_language" ]
}
```

- `provenance` is **always** `clinician`; there is no `computed` path for scores.
- A blank cell is `value: null, confidence: "blank"` — never a fabricated number.
- `flags[]` feeds the verify UX's "must double-check" list (§5.3).

---

## 5. Eval methodology (design now, **run later — credential-gated**)

The eval **designs the confidence tiers and proves the accuracy claims**. It runs on
**synthetic / redacted** samples only (§6, and the mvp-brief "synthetic data only until DPIA"
rule). Actually executing it against Vertex needs GCP/Vertex credentials and a region-pinned
endpoint — **human-gated; see §5.4 and §8.** Nothing here has been run.

### 5.1 Dataset (synthetic / redacted)

- A corpus of **synthetic completed forms**: generated/hand-filled record forms across ≥1
  norm-referenced instrument, ≥1 criterion-referenced/free instrument, and ≥1 age-band variant,
  to exercise the *generic* claim — not a single-instrument harness.
- Deliberate difficulty spread: neat vs. messy handwriting, phone photo vs. flat scan,
  glare/shadow/skew, crossings-out, blank cells, partially-completed forms.
- **Gold labels** = a human transcription of *exactly what is written* on each form (including
  "blank"/"illegible" where that is the truth). Gold never contains a derived value the form
  doesn't show. Double-keyed where feasible to bound labeller error.
- No real PHI. Any redacted real form has identifiers removed before it enters the corpus.

### 5.2 Metrics

- **Field-level accuracy** — exact-match on numeric score fields (raw/scaled/percentile/
  composite); normalised match on text fields (verbatim/qualitative), reported with a
  character-level edit-distance so "nearly right" is visible. Report **per field type** — a
  scaled-score digit error matters more than a wording slip in a qualitative note.
- **Table accuracy** — (a) **cell value** correctness *and* (b) **cell placement** (right
  row × right column). Track row/column mis-association separately: it is the highest-severity
  table failure.
- **Abstention / hallucination behaviour** — the critical safety metric: rate of **fabricated
  values** (model emitted a number where the cell is blank/illegible) — target ≈ **0**; and
  rate of correct abstention (flagged the unreadable cell). We would far rather over-flag than
  invent.
- **Confidence calibration** — for each confidence tier, the actual correctness rate. This is
  what makes the tiering trustworthy: a "high" tier that is only 80% correct is not high. Feeds
  the tier thresholds and the always-double-check list (§5.3).
- **Never-derive compliance check** — an explicit assertion in the harness that no score field's
  provenance is `computed` and that no output pattern implies a raw→scaled/percentile
  conversion. A regression here is a **hard fail** (licensing).
- **Cost / latency per document** — tokens and wall-clock per page and per document, by model
  (Flash/Pro) and by page role, to ground §7.
- **Flash vs Pro** — run both on the same corpus; pick per page-role by quality-vs-cost
  (ADR-007 Open Q3).

### 5.3 Failure-mode taxonomy → verify UX

Catalogue and count failure modes, then map each to a UX mitigation:

| Failure mode | Verify-UX response |
|---|---|
| Handwriting misread (wrong digit/word) | Show source crop beside the field; medium/low tier |
| Row/column mis-association in score table | Row-anchored display; cross-check flag; mandatory review |
| Fabricated value in a blank cell | Blocked upstream (abstention rule); if seen, hard-fail the eval |
| Trial-page vs summary-page mismatch | Auto-flag both, clinician reconciles |
| Blank/partial form read as complete | `blank` surfaced explicitly, not silently 0 |
| Wrong instrument/form assumed | Instrument selected at upload, not guessed |

The eval's output is an **"always double-check" list**: field types / conditions whose measured
accuracy or calibration falls below threshold are configured to **always** land in mandatory
review in DEV-104, regardless of reported confidence. Score-table numeric cells are the default
candidates for this list until data says otherwise.

### 5.4 Harness wiring & gating

- Lives alongside the existing eval assets (the `speech-ml` regression harness referenced in
  `AGENTS.md`); extraction prompts stay in parity with that harness, and **no extraction prompt
  change ships without a green eval** (the eval-harness gate from ADR-007).
- Runs through the **provider-agnostic client**, so the same suite can later score a self-hosted
  or alternative model for parity (ADR-007 exit path).
- **Credential-gated follow-up:** running it live requires provisioned Vertex/GCP access
  (region-pinned `europe-west2`, ZDR endpoint, least-privilege SA). Until then this section is a
  **design**; results are TBD. Marked as the DEV-102 follow-up in §8.

---

## 6. Data-minimisation & compliance wiring (per ADR-007)

Reflecting ADR-007 §7 (data minimisation), §3–§6 (ZDR / residency / contracts / network),
§8 (no PHI in logs), and the mvp-brief guardrails.

- **Pseudonymise before inference (ADR-007 §7).** Direct identifiers — child name, DOB,
  address, parent/carer contacts — are **stripped/withheld from what the model sees**. Identifier
  regions of the page (e.g. the identity/header block) are not sent for extraction, or are masked;
  the model is asked only for the *clinical* capture fields it needs. Identifiers are handled in
  our own layer and mapped to a case id; **re-attach identifiers in our layer** after extraction,
  never inside the prompt. (For v1 this may mean the identity page is handled by our own
  redaction/routing path and excluded from the multimodal call entirely.)
- **No PHI in logs (ADR-007 §8, `logging-policy.md`).** Never log page images, prompts,
  responses, or extracted values. Inference logs record **model id, case id, page role,
  latency, outcome, token counts — content-free** only. The eval corpus (synthetic/redacted) is
  the only place extracted content is inspected.
- **ZDR & residency (ADR-007 §3–§4).** Use the Vertex endpoints with the **abuse-monitoring
  logging exemption / Zero Data Retention** enabled, confirmed to cover any input cache (or
  caching disabled). **Region-pin `europe-west2`**; ML processing, caches, and backups stay
  in-region; no cross-jurisdiction processing (ADR-001).
- **Enterprise Vertex + contracts (ADR-007 §1, §5).** Enterprise Vertex on an invoiced billing
  account only — never AI Studio / consumer Gemini free tier. Covered by the Google Cloud DPA
  (+ BAA where applicable); Google/Vertex on the published subprocessor list; DPIA (DEV-32)
  updated to cover multimodal ingestion of children's special-category data.
- **Network isolation (ADR-007 §6).** Reach Vertex via Private Service Connect inside the
  VPC-SC perimeter; CMEK for any at-rest artefacts (uploaded images in GCS); least-privilege
  runtime SA.
- **Provider-agnostic client + eval-harness gate (ADR-007 Decision).** Inference sits behind the
  swappable client and is guarded by §5's eval; no prompt/schema change ships without a green
  eval. Keeps the exit to self-hosted (ADR-003) or another provider contained.
- **Synthetic/redacted only until DPIA (mvp-brief).** All spike and eval work uses
  synthetic/redacted forms; **no real family data** touches extraction until the DPIA update and
  design-partner (controller) sign-off (ADR-007 §10) are complete.
- **Clinician-in-the-loop (ADR-007 §9).** Extracted values are a **DRAFT** the clinician
  verifies/corrects before they become part of the clinical record or a report; extraction never
  auto-commits a value.

---

## 7. Cost & latency at pilot scale

Grounded in ADR-007's figures. At pilot volume (one solo practitioner, low case volume) the cost
of extraction is **negligible** and does **not** drive model choice — accuracy does.

- ADR-007 per-token pricing: **Flash** $0.30 / $2.50 per 1M input/output tok; **Pro** $1.25 /
  $10 per 1M input/output tok. At ADR-007's whole-case AI workload (~10k in + ~3k out tok/case)
  the *entire* per-case AI cost is ≈ **$0.01 (Flash) / $0.04 (Pro)**; ~50 cases/mo ≈
  **$0.50/mo (Flash) / $2/mo (Pro)**.
- **Document extraction sits inside that envelope.** Multimodal image input adds tokens per
  page, but at a handful of pages per assessment and pilot case volume, the marginal spend is
  still cents/month. The crossover where self-hosting's fixed **~$1,100–2,800/mo** GPU wins is
  ~27k cases/mo (Pro) / ~110k (Flash) — orders of magnitude beyond pilot. So **self-hosting
  remains an isolation decision, not a cost decision** (ADR-007 §1).
- **Per-document-kind steer (to be confirmed by §5):**
  - *Identity/cover pages* — not sent to inference (redaction path, §6): **$0**.
  - *Printed/low-stakes pages, page routing* — **Flash**: cheapest, fast.
  - *Handwritten trial rows & the score table* — **Pro**: the accuracy-critical surfaces; the
    per-document cost delta between Flash and Pro is a fraction of a cent at this volume, so
    paying for Pro where it reduces clinician-correction burden is clearly worth it.
- **Latency:** extraction is **asynchronous** (Cloud Tasks → worker, matching the existing
  async-AI pattern), surfaced to the clinician as "extracting → ready" — it is not on a blocking
  UI path, so a few seconds per page (multimodal, per-page) is acceptable. Per-page latency is
  measured in §5 to confirm.

---

## 8. Recommendation, open questions, and follow-ups

### 8.1 Recommendation

Adopt **Gemini multimodal on Vertex AI with schema-guided structured output**, page-segmented,
with **row-anchored table extraction**, **abstain-don't-invent handwriting handling**, and
**per-field confidence** driving the DEV-104 verify/correct UX. Keep extraction **extraction-only
/ never-derive** (provenance = clinician), behind the provider-agnostic client and the eval-harness
gate, with all ADR-007 §6 safeguards in place before any real data. Benchmark against Document AI
(Option A) in the eval so the primary choice is evidence-backed.

### 8.2 Open questions

1. **Flash vs Pro split per page role** — decide from the eval, not assumption (ADR-007 Open Q3).
2. **Model confidence trust** — how well does Gemini's structured/self-reported confidence
   predict correctness on handwriting? Drives the tier thresholds and always-double-check list
   (§5.2 calibration).
3. **Instrument identification** — clinician-selected at upload vs. model/template-classified,
   and how to fail safe when the form is unrecognised.
4. **Identity-page handling** — fully exclude from the multimodal call and capture identifiers
   via a separate our-layer path, vs. mask-and-send. §6 leans exclude; confirm.
5. **Third-party / external instrument results** (teardown §5, Q5) — captured as free-text with
   `source = external`; confirm extraction scope for these.
6. **Composite/index rows** (teardown §5, Q1) — ensure the schema carries the exact composite set
   the clinician reports, **without** hosting the appendix that produces them.
7. **Synthetic corpus fidelity** — do generated forms represent real handwriting/photo-quality
   variance well enough for the eval to be predictive? May need a small redacted real-form set
   (identifiers stripped) to calibrate.

### 8.3 Credential-gated follow-up (the DEV-102 next step)

- **Run the §5 eval live** against Vertex — **requires provisioned GCP/Vertex credentials**,
  region-pinned `europe-west2` endpoint, ZDR/abuse-exemption confirmed, least-privilege SA, on
  the synthetic/redacted corpus. **This is human-gated and not done in this spike.** It produces
  the actual field/table accuracy, calibration, and Flash-vs-Pro numbers that turn the design
  targets above into confirmed decisions and populate the always-double-check list for DEV-104.
- Prerequisites tracked in ADR-007 Open Questions (ZDR/abuse-exemption enabled in region; DPA/BAA
  scope; subprocessor + DPIA sign-off) and the mvp-brief "synthetic data only until DPIA" rule.

---

## 9. Cross-references

- Licensing / never-derive line: `docs/research/assessment-forms-teardown.md §1, §3` · `AGENTS.md
  → Guardrails → Licensed instruments` · DEV-100
- Inference decision + safeguards: `docs/decisions/007-vertex-gemini-managed-inference.md`
  (§7 minimisation, §8 no-PHI-logs, §3–§6 ZDR/residency/contracts/network)
- Data model & capture-once IA: DEV-101 / DEV-109 · Verify/correct UX: DEV-104
- Report engine (consumes confirmed values): DEV-105 · Logging: `docs/logging-policy.md`
- Eval harness parity: `speech-ml` (see `AGENTS.md`) · DPIA: DEV-32 · Data minimisation: DEV-53
