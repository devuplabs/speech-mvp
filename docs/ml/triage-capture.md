# ML Design — Triage pathway suggestion

**Feature:** AI-suggested triage outcome surfaced on the clinician prep dashboard  
**Slice owner:** Sona API — `services/triage-suggestion.ts` (to be written)  
**Status:** Stub (`prep_brief` draft hardcodes probe areas; no suggestion today)  
**ADRs:** [003](../decisions/003-self-hosted-llm-air-gap.md) (air-gap LLM), [001](../decisions/001-data-residency-jurisdiction-stacks.md) (jurisdiction)  
**Target:** 90-day ship · v0.2

---

## Problem

After a parent submits the intake form, the clinician opens the consult-prep screen with about 20 minutes before the free consultation call. Today they must read all 8 steps of raw intake text and decide unaided which of four pathways to follow:

| Outcome | Meaning |
|---------|---------|
| `strategy_only` | Advice session — no block of therapy needed yet |
| `short_block` | 4–6 sessions; specific, time-limited goal |
| `full_assessment` | Full diagnostic assessment before committing to a plan |
| `refer_out` | Outside scope — refer to paediatrics, ENT, OT, etc. |

The clinician (Monal) reads between 3 and 8 intakes per week. Reading the full intake and forming a hypothesis takes 5–10 minutes per case. That time compounds across cases and erodes the value of the free-call slot.

**Goal:** Given the complete intake JSON, generate a ranked triage suggestion (top outcome + 2-sentence clinical rationale + 3 probe questions to verify), presented as a *draft for clinician review* on the prep screen. The clinician accepts, modifies, or overrides — and records the final outcome. The suggestion is never shown to parents.

**Non-goal:** Autonomous triage. The system never records a triage outcome without explicit clinician confirmation.

---

## Metrics

| Metric | Definition | Target at 90 days |
|--------|-----------|-------------------|
| **Agreement rate** | % of cases where the AI suggestion matches the clinician's final recorded outcome | ≥ 70 % (pilot; rises with more data) |
| **Override rate** | % of cases where clinician selects a different outcome than the top suggestion | Tracked; no ceiling — override is healthy |
| **Prep time reduction** | Time from opening the prep screen to clicking "Ready for call" (measured via audit timestamps) | ≥ 20 % reduction vs. pre-feature baseline |
| **Probe coverage** | % of suggested probe questions the clinician selects to ask (from a checkbox list on the UI) | ≥ 60 % selected |
| **Draft latency P95** | Time from intake submission to `prep_brief` status `ready` in `ai_drafts` | ≤ 8 s on L4 GPU (INT4) |
| **Hallucination rate** | Proportion of clinical statements in the rationale flagged by a separate LLM-as-judge prompt as unsupported by the intake | ≤ 5 % |

**Leading indicator:** clinician override rate with a written reason surfaces disagreement patterns early, before agreement rate data has statistical weight.

---

## Data

### Input (available at inference time)

```
IntakeAnswers (JSONB, all 8 steps)  →  ~3 000–6 000 tokens of structured text
triageRecords (prior case, if any)  →  excluded: different child, different context
```

The full `answers` JSONB is passed to the prompt. Fields that are the strongest triage signals (from Monal's interview):

- `mainConcern` — primary presenting issue
- `difficulties` — multi-select array (21 options across 4 domains)
- `ageAtReferral` — age band determines which pathway applies
- `assessedByOthers`, `receivingTherapy` — indicate prior involvement
- `familyHistory` — elevates `full_assessment` probability
- `hearingTested`, `earInfections`, `entInvolvement` — ENT risk factors for `refer_out`
- `diagnosis` — existing ADHD/autism shifts probe set
- `senPlan` — EHCP presence affects `full_assessment` framing
- `respondsToName`, `ageFirstWords`, `ageTwoWordPhrases` — milestone flags

### Ground truth

For the pilot: Monal's recorded outcomes in `triage_records` (accumulated over 4–6 weeks). For training a fine-tuned classifier: anonymised historical intakes from Monal's existing caseload (requires DPIA + explicit consent).

**Important:** We do NOT train Gemma on client data. The model is used for zero-shot / few-shot inference at runtime. Fine-tuning is a v1 roadmap item using consented, anonymised data only, and only for a small adapter (LoRA).

### Prompt construction

```
system: You are an RCSLT-registered SLT consultant supporting triage of a
        new paediatric referral. You must not diagnose. You may suggest a
        triage pathway and clinical reasoning for review by the responsible
        clinician. Output JSON only.

user:   INTAKE DATA
        ============
        Child age at referral: {ageAtReferral}
        Primary concern: {mainConcern}
        Difficulties flagged: {difficulties.join(', ')}
        [... 12 highest-signal fields ...]
        
        TASK
        ====
        Return JSON: {
          "topOutcome": one of ["strategy_only","short_block","full_assessment","refer_out"],
          "confidence": "low"|"medium"|"high",
          "rationale": "Two sentences. Reference only the intake. No diagnosis.",
          "probeQuestions": ["Q1", "Q2", "Q3"],
          "redFlags": ["flag1"] or []
        }
```

Max tokens: 512. Temperature: 0.2 (low variance — clinical). JSON validated with Zod before storing.

---

## Model

**Inference:** Gemma 3 27B IT, INT4 AWQ, via vLLM on private GKE in tenant region (ADR-003).

**Why not a fine-tuned classifier?** The pilot caseload (4–8 cases/week) will not generate enough triage records to train a reliable classifier for ~3 months. Zero-shot Gemma 3 27B with a well-structured prompt + few-shot examples sourced from Monal's review achieves acceptable baseline quality without labelled data.

**Few-shot examples (in-prompt, 3 max):** Anonymised synthetic cases hand-authored by Monal covering one example per triage class. These are static strings in the prompt template, not retrieved from the DB.

**Confidence calibration:** The model's `"confidence"` field is overridden post-generation by a rule: if `redFlags` is non-empty and `topOutcome` is `strategy_only`, downgrade to `"low"` regardless of model output. Rule authored by Monal.

**Prompt versioning:** The prompt template is versioned in source (`services/triage-suggestion.ts`). The `modelId` stored in `ai_drafts` encodes both model checkpoint and prompt version (`gemma-3-27b-it-awq:triage-v1`). Breaking prompt changes bump the minor version; model weight changes bump the major.

---

## Deployment

**Path:** Intake submit → Cloud Tasks `llm-prep` job → `draftPrepBrief()` → inference → `ai_drafts(kind='prep_brief')` → case status `prep_ready`.

**Concurrency:** vLLM continuous batching; up to 4 concurrent prep-brief jobs per GPU. Cloud Tasks max concurrency = 4 per worker Cloud Run instance. Set `Cloud-Tasks-Max-Dispatches-Per-Second = 1` until GPU capacity is confirmed.

**Timeout budget:**

| Stage | Budget |
|-------|--------|
| Cloud Tasks enqueue | < 100 ms (synchronous) |
| Worker → inference network | < 200 ms |
| Gemma 3 27B INT4 TTFT | ≤ 3 s |
| Token generation (512 tokens) | ≤ 4 s |
| DB write + audit | < 500 ms |
| **Total P95** | **≤ 8 s** |

**Retry:** Cloud Tasks retries up to 3× on 5xx. Worker is idempotent (checks `ai_drafts.kind='prep_brief'` before generating). Third failure triggers `alert.llm_prep_failed` alert and leaves case in `prep_drafting` with a UI warning.

**Degraded mode:** If `INFERENCE_OPENAI_BASE_URL` is not set or `/v1/models` returns unhealthy, `draftPrepBrief` falls back to the current stub (3 generic probes, no suggestion). Clinician sees "AI prep unavailable — generic probes shown" banner. Case proceeds normally.

---

## Monitoring

| Signal | Mechanism | Alert threshold |
|--------|-----------|----------------|
| Inference latency P95 | vLLM Prometheus → Cloud Monitoring | > 12 s |
| `llm_prep_failed` (3 retries exhausted) | Worker → Cloud Logging → alert | Any occurrence |
| GPU memory utilisation | GKE node metrics | > 90 % |
| JSON parse failure rate (Zod) | Structured log counter | > 2 % |
| Override rate delta (7-day rolling) | Scheduled BigQuery query (audit_log) | Jump > 15 pp |
| Prep brief request latency | Cloud Run metrics | P99 > 30 s |

**Quality reviews:** Monal receives a weekly summary email (not automated) listing all cases where she overrode the suggestion, with the AI rationale and her final reason. This is the primary feedback loop until the caseload is large enough for quantitative analysis.

---

## Ethics

| Concern | Control |
|---------|---------|
| **Clinician in the loop always** | `ai_drafts.reviewedAt` is null until the clinician explicitly saves their triage outcome. The suggestion is never auto-applied. The triage route `POST /v1/cases/:id/triage` requires a clinician-authored `outcome` field. |
| **No diagnosis** | System prompt explicitly forbids diagnostic language. A secondary LLM-as-judge prompt (run after generation) checks for diagnostic terms and redacts the rationale if found, replacing with a neutral fallback. |
| **Parent transparency** | The prep brief is **never shown to parents**. Parents see only the clinician-reviewed `parent_summary`. The Sona privacy notice states that intake data is used to prepare clinician materials. |
| **No model training on client data** | `modelId = "gemma-3-27b-it-awq:triage-v1"` — weights are the public Gemma 3 checkpoint, never fine-tuned on client PHI. Requires DPA clause in any future fine-tuning contract. |
| **Audit trail** | `audit_log` records `prep_brief.drafted` (with model_id) and `triage.recorded` (with `actor: "clinician"` and optional override note). 7-year retention. |
| **HCPC/RCSLT alignment** | The suggestion is framed as a "starting hypothesis". The clinician's final recorded decision is the authoritative clinical act. Wording on UI: "DRAFT — clinician must review and record final outcome." |

---

## Trade-offs

| Decision | Why | What we gave up |
|----------|-----|----------------|
| Zero-shot rather than fine-tuned | No labelled data at launch; avoids PHI-on-weights risk | Lower agreement rate early on (~65 % vs ~80 % fine-tuned) |
| Gemma 3 27B over 12B | Better multi-step reasoning; worth the VRAM cost on L4 INT4 | Cold start ~8 s; can't batch many concurrent jobs on a single L4 |
| Async (Cloud Tasks) over sync | Intake submit is on the parent's device; they shouldn't wait for inference | Clinician must wait for `prep_ready` (typically < 10 s from submit) |
| JSON-only output | Deterministic parsing; no narrative hallucination in structured fields | Rationale field is length-constrained (2 sentences); nuance lost |
| Single GPU (L4) in `uk/dev` | Cost — £X/hr in dev | Maximum 4 concurrent jobs; queue waits if surge |
| Stub fallback rather than hard failure | Clinical workflow must never block on inference | Generic probes not as useful; risk of clinicians ignoring the "unavailable" state |
