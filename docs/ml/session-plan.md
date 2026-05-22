# ML Design — Session plan generation

**Feature:** AI-drafted first-session plan generated after clinician records triage outcome  
**Slice owner:** Sona API — `services/session-plan.ts` (stub → real)  
**Status:** Stub (`draftSessionPlanStub` inserts generic placeholder sections)  
**ADRs:** [003](../decisions/003-self-hosted-llm-air-gap.md) (air-gap LLM), [001](../decisions/001-data-residency-jurisdiction-stacks.md) (jurisdiction)  
**DB table:** `ai_drafts` where `kind = 'session_plan'`  
**Target:** 90-day ship · v0.2

---

## Problem

After the free consultation call, Monal must write a first-session plan within 24 hours. Today she opens a blank document, mentally reconstructs the case from intake + notes from the call, and drafts:

- 2–4 goals (SMART, EHCP-aligned if applicable)
- A sequence of session activities
- A home practice recommendation for the parent
- Materials or visual aids needed
- Parent goals (what the parent should practise between sessions)

This takes 20–45 minutes per case at current volume. She already uses ChatGPT for this, pasting intake text manually — with all the PHI-outside-VPC and hallucination risks that entails.

**Goal:** After the clinician records a triage outcome (`short_block`, `full_assessment`, `strategy_only`; not `refer_out`), generate a structured first-session plan draft with five editable sections. The draft is stored in `ai_drafts`, surfaced on the clinician triage screen, and explicitly labelled as AI-drafted. The clinician edits and saves the final version before it influences any downstream artifact.

**Non-goal:** Full clinical report generation (roadmap v0.3). This is the *first-session plan only* — not a full assessment report, not a long-term therapy plan.

---

## Metrics

| Metric | Definition | Target at 90 days |
|--------|-----------|-------------------|
| **Clinician acceptance rate** | % of plan drafts where the clinician saves at least one section without deleting its entire content | ≥ 80 % (indicator that drafts are usable starting points) |
| **Edit distance ratio** | Levenshtein distance between AI draft and clinician final / length of AI draft. Lower = less editing needed. | ≤ 0.35 (clinician edits < 35 % of content on average) |
| **Time to plan (T2P)** | Minutes from triage `recordedAt` to clinician `reviewedAt` on the session plan draft | ≤ 15 min (vs. ~35 min baseline) |
| **Goal quality score** | % of goals rated ≥ 3 / 5 on a 5-point SMART rubric, assessed by Monal on a random sample of 10 cases/week | ≥ 3.5 / 5 |
| **Section deletion rate** | % of plan sections the clinician deletes in full (signal of useless content) | ≤ 10 % per section |
| **Draft latency P95** | Time from triage POST to `plan_ready` status | ≤ 15 s on L4 GPU INT4 |
| **Parent home-practice completion** | % of home practice tasks reported completed by parent at next session | ≥ 60 % (longer-term quality signal; requires parent feedback loop) |

**Primary signal for prompt iteration:** section deletion rate. If the "goals" section is deleted in > 15 % of cases, the goals prompt requires recalibration.

---

## Data

### Input (available at inference time)

```
IntakeAnswers (JSONB, all 8 steps)     →  ~3 000–6 000 tokens
triageRecords.outcome                  →  one of four outcome strings
triageRecords.reason                   →  optional clinician free-text from the call
ai_drafts(kind='prep_brief').content   →  probeAreas + redFlags from prep step
```

The session plan context window includes all three sources. The triage reason field is critical: it is the clinician's own words from the call and is the highest-signal input for goal setting. If the clinician provided no reason, the plan is generated from intake + outcome only (lower confidence; shown in the UI).

**Key fields per section:**

| Section | Primary intake signals |
|---------|----------------------|
| Goals | `mainConcern`, `difficulties`, `ageAtReferral`, `diagn osis`, `senPlan`, triage outcome, triage reason |
| Activities | `temperament`, `favouritePlay`, `ageAtReferral`, triage outcome |
| Home practice | `parentLanguages`, triage outcome, goals (generated in same pass) |
| Materials | `ageAtReferral`, `difficulties`, activities (generated in same pass) |
| Parent goals | `communicationAwareness`, triage reason, home practice (generated in same pass) |

### Structured output format

The model is prompted to return a JSON object. This is validated with Zod before storage. Invalid JSON triggers a retry (max 2), then fallback to the stub.

```ts
const sessionPlanSchema = z.object({
  label: z.literal("DRAFT — clinician must review"),
  ehcpAligned: z.boolean(),
  goals: z.array(z.object({
    text: z.string().max(200),
    domain: z.enum(["speech_sound", "language", "social_comm", "fluency", "voice", "feeding", "other"]),
    smart: z.boolean(),
  })).min(1).max(4),
  activities: z.array(z.string().max(200)).min(1).max(5),
  homePractice: z.array(z.string().max(200)).min(1).max(3),
  materials: z.array(z.string().max(100)),
  parentGoals: z.array(z.string().max(200)).min(1).max(2),
  confidence: z.enum(["low", "medium", "high"]),
  source: z.literal("gemma-3-27b-it-awq"),
});
```

`ehcpAligned: true` is set when `senPlan` is non-empty and not `"none"`. When true, the prompt adds an EHCP framing instruction ("goals must be measurable and linkable to EHCP outcomes") and the UI adds an EHCP badge.

### Ground truth

For quality evaluation (not training): Monal's saved final plans (after editing). Edit distance and deletion rate are computed from diffs between `ai_drafts.content` at creation vs. at `reviewedAt`. These diffs are stored in a separate `plan_edit_events` table (append-only).

We do not train the model on client session plans. Any future fine-tuning requires: (1) explicit clinician consent, (2) anonymisation review, (3) DPA with the compute provider, (4) separate ADR.

---

## Model

**Inference:** Gemma 3 27B IT, INT4 AWQ, vLLM, private GKE, tenant region (ADR-003).

**Context budget:**

| Component | Tokens (est.) |
|-----------|--------------|
| System prompt + output schema | 800 |
| Intake JSON (key fields only, not full 50-field dump) | 1 500 |
| Prep brief content | 400 |
| Triage reason | 200 |
| Few-shot examples (2) | 1 200 |
| **Total input** | **~4 100** |
| Max output tokens | 1 500 |
| **Total** | **~5 600 / 128K window** |

The full 50-field intake is **not** passed verbatim. A `buildPlanContext()` function selects the 18 highest-signal fields (validated with Monal) and formats them as key-value pairs. This reduces token cost and prompt noise.

**Temperature:** 0.4 — slightly higher than triage (more creative for activities/home practice) but constrained by the schema.

**EHCP-aware few-shot examples:** Two in-prompt synthetic cases — one with EHCP, one without — demonstrating the `ehcpAligned` flag and the difference in goal phrasing. These are reviewed by Monal and stored in `src/prompts/session-plan-examples.ts`.

**Multi-section coherence:** Goals, activities, and home practice are generated in a single inference call. This preserves coherence (home practice refers back to session activities). A two-pass approach (goals first, then rest) is an alternative if the single-pass JSON failure rate exceeds 5 %.

**Retry + fallback:** If Zod validation fails after 2 retries, the stub content is stored with `modelId = "fallback-stub"` and the UI shows "AI draft unavailable — generic plan shown". Clinician is not blocked.

---

## Deployment

**Trigger:** `POST /v1/cases/:caseId/triage` → `draftSessionPlanStub()` (sync, after triage record written). In production: replaces with `enqueuePlanDraft()` → Cloud Tasks → worker → real inference.

**Async path:**

```
POST /v1/cases/:id/triage
  → write triage_records
  → set case status = "plan_drafting"
  → Cloud Tasks enqueue: POST /internal/tasks/session-plan { caseId }
  → return 200 immediately

Worker:
  POST /internal/tasks/session-plan
    → buildPlanContext(db, caseId)
    → llamaClient.chat(prompt)
    → zod.parse(response)
    → insert ai_drafts(kind='session_plan')
    → set case status = "plan_ready"
    → [future] push notification to clinician Flutter client via SSE
```

**Streaming (phase 2):** When the clinician has the triage screen open, stream plan sections via SSE as tokens arrive (sections delimited by JSON array positions). This reduces perceived latency from ~15 s to "first goal visible in ~3 s". Requires `SelfHostedLlmClient.stream()` implementation.

**Idempotency:** Worker checks `ai_drafts` for an existing `session_plan` before calling inference. Duplicate Cloud Tasks deliveries are safe.

**Timeout budget:**

| Stage | Budget |
|-------|--------|
| Worker cold start (Cloud Run min-instances=1) | < 1 s |
| Inference (5 600 tokens in, 1 500 tokens out, L4 INT4) | ≤ 12 s |
| Zod validation + DB write + audit | < 1 s |
| **Total P95** | **≤ 15 s** |

---

## Monitoring

| Signal | Mechanism | Alert threshold |
|--------|-----------|----------------|
| Draft generation latency P95 | Worker logs → Cloud Monitoring custom metric | > 20 s |
| JSON parse failure rate | Structured log `session_plan.json_invalid` counter | > 5 % (7-day rolling) |
| Section deletion rate per section | BigQuery query on `plan_edit_events` | > 15 % for any section |
| `plan_ready` → `reviewedAt` gap | BigQuery on `ai_drafts` | Median > 30 min (suggests drafts not being used) |
| GPU OOM errors | vLLM error logs | Any |
| Worker 5xx rate | Cloud Run metrics | > 2 % |

**Weekly quality digest:** Automated report to Monal listing the 3 cases with the highest edit distance that week, with a side-by-side of AI draft vs. final. This drives prompt iteration without requiring manual review of all cases.

---

## Ethics

| Concern | Control |
|---------|---------|
| **HCPC/RCSLT compliance** | Plan is stored as `kind='session_plan'`, `reviewedAt=null` until the clinician saves. The API endpoint for publishing the parent summary requires that `reviewedAt IS NOT NULL` on the session plan (DB-level precondition). A plan draft never autonomously generates downstream artefacts. |
| **"AI-drafted · clinician-reviewed" disclosure** | The `label` field is hardcoded in the schema (`z.literal("DRAFT — clinician must review")`). The Flutter UI renders the `ai_draft_badge` widget on every section header. The label is immutable in the DB — it cannot be overwritten even if the clinician saves. |
| **EHCP mis-alignment risk** | EHCP goal language must meet statutory criteria. The `ehcpAligned` flag triggers a stricter prompt but does not claim the goals are compliant. The UI shows: "EHCP framing applied — clinician must confirm compliance." A future fine-tuning pass on EHCP-labelled goals (with consent) would improve reliability. |
| **No training on client data** | `modelId` always refers to the public Gemma 3 checkpoint + versiond prompt. No fine-tuning on session plan content without a separate DPIA and consent framework. |
| **Audit trail** | `audit_log` records `session_plan.drafted` (with model_id, context hash), `session_plan.edited` (edit distance logged without PII), `session_plan.reviewed` (clinician act). |
| **Parent data minimisation** | The plan itself is not shared with parents. Only the `parent_summary` (reviewed separately) reaches parents. The plan references intake data by implication, not by quoting PHI fields verbatim. |
| **Clinician override as signal, not error** | High edit-distance is not an error; it means the clinician made a meaningful clinical choice. Override rates are tracked as a quality signal, not penalised. |

---

## Trade-offs

| Decision | Why | What we gave up |
|----------|-----|----------------|
| Single-pass JSON for all 5 sections | One inference call; coherent cross-section references | Higher JSON failure rate than single-section calls; mitigated by retry + Zod |
| 18 selected intake fields rather than full 50 | Token efficiency; reduces noise in activities/materials sections | Some edge-case signals (e.g. detailed `pregnancyHealth`) may be missed for plan |
| `plan_drafting` status between POST triage and draft ready | Honest UI state; parent-facing status unaffected | Extra complexity in case state machine; Flutter must poll or use SSE for `plan_ready` |
| No streaming at launch | Simpler API surface; streaming requires `SelfHostedLlmClient.stream()` not yet built | Clinician sees a 15 s wait after triage — addressed in phase 2 SSE work |
| Generic stub as fallback (not empty) | Clinician is never presented with a blank plan | Stub content may be mistaken for a real draft if the `modelId` is not checked — UI must make the fallback state visually distinct |
| Max 4 SMART goals | RCSLT guidance: "specific, time-limited" — fewer well-defined goals beat many vague ones | Clinicians with complex cases (EHCP + 3 presenting concerns) may need 5 goals — allow via UI override |
