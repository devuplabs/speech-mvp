# ADR 006 — Managed Vertex AI Gemini for the first AI loop (dev)

**Status:** Accepted  
**Date:** 2026-06-02  
**Amends (does not supersede):** [ADR-003 — Self-hosted LLM (air-gap) in tenant region](003-self-hosted-llm-air-gap.md)  
**Depends on:** ADR-001 (jurisdiction stacks), ADR-003 (LLM architecture target)

## Context

ADR-003 picks self-hosted Gemma 3 27B IT on vLLM/GKE as the inference target for
production. The GPU quota request and the GKE + weights bootstrap are still
open (Notion: `[Parked] Phase 2: L4 GPU + Gemma weights`). In the meantime
every AI artifact on dev (`prep_brief`, `session_plan`, `clinical_report`,
`parent_summary`) is a deterministic stub — useful for shape testing but not
the AI experience the design partner asked us to validate.

The product wedge in `docs/mvp-brief.md` is the pre-consult prep brief.
Validating that wedge needs at least one AI artifact to actually be
LLM-generated against real intake content, in a way that:

- stays in the **same GCP project** and the **same region** (`europe-west2`),
- doesn't add a new vendor / DPA approval,
- can be turned off and reverted to the stub with one env var flip,
- doesn't block the GKE/vLLM work in ADR-003 from becoming the prod target.

## Decision

**Use Vertex AI Gemini 2.5 via its OpenAI-compatible endpoint, in
`europe-west2`, for `prep_brief` only, on dev, behind a feature flag.**

| Aspect | Choice |
|---|---|
| Endpoint | `https://europe-west2-aiplatform.googleapis.com/v1beta1/projects/{PROJECT}/locations/europe-west2/endpoints/openapi/chat/completions` |
| Model (default) | `google/gemini-2.5-flash` (cheapest; switch to `…-pro` if quality requires) |
| Auth | Cloud Run runtime SA → Google ADC → bearer access token. No new keys / secrets. |
| IAM | `roles/aiplatform.user` granted to the runtime SA, project-scoped, via Terraform (`grant_vertex_aiplatform_iam = true`). |
| Region | `europe-west2` — same as Cloud SQL + Cloud Run; PHI never leaves the UK stack. |
| Vendor relationship | GCP-native: Sona is on GCP, Vertex AI is a GCP service, processor relationship + no-training-on-data covered by the GCP DPA already in place. No new vendor approval needed. |
| Scope on dev | `LLM_ENABLED_KINDS` defaults to `prep_brief` only. The other three artifacts stay on stubs until each is independently validated. |
| Scope on prod | **Not enabled.** Vertex tfvars only exist in `uk/dev`. Prod / stage continue to use the deterministic stub until ADR-003's self-hosted path is funded. |
| Fallback | `chat.ts` already falls back to the deterministic stub on any LLM failure (timeout, 5xx, malformed JSON, schema mismatch). A bad LLM day cannot break the demo. |
| Data path | The intake context (synthetic personas only on dev) goes in the request body. **Never in logs.** A structured `llm.call` log line records `model`, `host`, `latencyMs`, `outcome`, `httpStatus` — PHI-free. |

## Consequences

- ADR-003 remains the **production** target. Vertex on dev is an interim path
  to validate the AI loop product-side without waiting on GPU procurement.
- When the GKE / vLLM stack stands up, swapping is a one-line tfvars change:
  set `inference_openai_base_url_override = ""` and let the
  `module.inference.vllm_openai_base_url` output take over. The app code is
  unchanged (the same OpenAI-compatible client serves both).
- If clinical evaluation says Vertex Gemini is acceptable for production
  (UK residency, DPA, latency, quality), we'll write **ADR-007** to make
  Vertex the prod choice and retire the GKE/vLLM work. Until then ADR-003
  stands.

## Out of scope (for this ADR)

- Stage / prod enablement.
- Other three artifacts (`session_plan`, `clinical_report`, `parent_summary`)
  — flip individually after each has been clinically reviewed.
- Async (Cloud Tasks → worker) inference for `prep_brief`. The
  synchronous path in `POST /v1/cases/:id/intake` is fast enough for the
  first loop (Gemini 2.5 Flash latency p50 ≈ 1–2 s for our prompt size).

## Reversibility

To turn the LLM off on dev: clear `inference_openai_base_url_override` in
`uk/dev` tfvars, merge, let `sona-terraform-dev-apply` run. The next
deploy returns to the deterministic stub for all four artifacts. No data
migration. No code changes.
