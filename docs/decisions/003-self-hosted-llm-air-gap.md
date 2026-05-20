# ADR 003 — Self-hosted LLM (air-gap) in tenant region

**Status:** Accepted  
**Date:** 2026-05-20  
**Supersedes:** Managed Vertex Gemini as default (rejected for v1)  
**Depends on:** ADR-001 (jurisdiction stacks), ADR-002 (GenUI A2UI → Sona API)

## Context

- Clinical and parent data must not leave the jurisdiction’s VPC for **inference**.
- A separate “demo stack” (e.g. Firebase AI Logic on-device, Vertex public API) would fork the GenUI transport, auth, and ops model — high maintenance and compliance risk.
- **One architecture** for synthetic demo data and production PHI: same request paths, same services, same `LlmClient` implementation; only **IAM, data, and network policy** differ by environment.

## Decision

### Inference: **self-hosted open-weights** (air-gap)

| Requirement | Implementation |
|-------------|----------------|
| **No third-party LLM API** for prompts containing client data | Model runs on **GKE** or **GCE + GPU** (L4/L5) in the **same region** as Cloud SQL (`europe-west2` UK, `us-central1` US). |
| **No internet egress** from inference | Private subnet; **VPC firewall** deny default egress; optional **VPC Service Controls** perimeter; weights and artifacts in **GCS (CMEK)** only. |
| **Callers** | **Sona API** and **Cloud Tasks workers** call an **internal HTTP/gRPC endpoint** on the inference service — never the public internet. |
| **Interface** | Single `LlmClient` → **SelfHostedLlmClient** only in application code (no Vertex/OpenAI code paths in repo). |
| **Model (locked)** | **[Gemma 3 27B IT](https://huggingface.co/google/gemma-3-27b-it)** — `google/gemma-3-27b-it` — best-quality open Gemma for summarisation, drafting, and structured JSON/A2UI-friendly output. **Same checkpoint** in dev, stage, and prod. |
| **Serving** | **[vLLM](https://docs.vllm.ai/)** on GKE (see [Gemma 3 + vLLM on GKE](https://cloud.google.com/ai-hypercomputer/docs/tutorial-gemma-3-vllm-inference)). Internal OpenAI-compatible `/v1/chat/completions` for `SelfHostedLlmClient`. |
| **Modality (v0.1)** | **Text only** — intake and plans are text; do not load vision encoder paths in v0.1 (saves VRAM). |
| **Quantization** | **AWQ or GPTQ INT4** on pilot GPUs (single **NVIDIA L4 24GB** in `uk/dev`); promote to FP16/BF16 on larger GPU in prod if evals require it. |
| **Context** | Use **128K** window cap in API for long intake + plan prompts; default `max_tokens` per task in API config. |

### Unified demo and production

| Layer | Dev / stage | Prod |
|-------|-------------|------|
| **Flutter + GenUI** | `genui` + **`genui_a2a`** transport → Sona API | **Same** |
| **Sona API** | Cloud Run + VPC connector | **Same** |
| **LLM** | Self-hosted inference in **dev** project VPC | Self-hosted in **prod** project VPC |
| **Data** | Synthetic / anonymised fixtures only | Real PHI (after DPIA + BAA) |
| **Human GCP access** | Engineers: `roles/editor` (or narrower) on **dev/stage** | **No standing developer access** — deploy via **Cloud Build SA** only; **break-glass** documented, time-bound, audited |

**Explicitly rejected**

- **Vertex AI Generative API** (managed) for production or demo inference paths.
- **Firebase AI Logic** / client-side Gemini keys in Flutter.
- A second “non-PHI demo” UI or API codebase.

### Async work

- Long jobs (prep brief, session plan) remain **Cloud Tasks → worker Cloud Run** → **internal inference URL** (same as sync path).

### Why Gemma 3 27B (not smaller Gemma or Llama)

| Option | Verdict |
|--------|---------|
| **Gemma 3 27B IT** | **Selected** — top open “compact” tier on public leaderboards; strong reasoning/summarisation; 128K context; same research line as Gemini; fits air-gap self-host. |
| Gemma 3 12B / 4B | Reject for primary — lower draft quality on clinical prose and multi-section plans. |
| Gemma 3 1B / 270M | Reject — task-tuned only; insufficient for consult prep + session plans. |
| Llama 3.x | Not selected — team standardises on **Gemma** for parity with Google stack and `speech-train` familiarity. |

### GPU sizing (starting point)

| Environment | GPU | Notes |
|-------------|-----|--------|
| **uk/dev** | 1× **NVIDIA L4** (24 GB) | `gemma-3-27b-it` with **INT4** weights + vLLM; weights in GCS (CMEK). |
| **uk/prod** | 1× **L4** (INT4) or 1× **A100 40/80GB** (BF16) | Scale after pilot latency/quality metrics. |

Request **GPU quota** (`europe-west2`) before Terraform apply for inference node pool.

## Consequences

- Terraform must add **GKE GPU node pool** (L4) + vLLM Helm/manifest per jurisdiction/environment (start in `uk/dev`).
- Pull model weights once into **GCS**; inference pods mount or init from bucket — **no Hugging Face egress** from prod inference subnet.
- **Do not** enable `aiplatform.googleapis.com` for Sona inference (optional only if a future ADR adds non-PHI tooling elsewhere).
- Higher ops: model images, GPU quota, rolling upgrades, capacity planning in **each** jurisdiction project.
- `speech-train` (Vertex Whisper) remains a **sibling** concern for ASR roadmap — out of v0.1 Sona inference path.

## References

- [Gemma 3 model card](https://ai.google.dev/gemma/docs/core/model_card_3)
- [google/gemma-3-27b-it](https://huggingface.co/google/gemma-3-27b-it)
- [Gemma 3 + vLLM on GKE (Google Cloud)](https://cloud.google.com/ai-hypercomputer/docs/tutorial-gemma-3-vllm-inference)
- [VPC Service Controls](https://cloud.google.com/vpc-service-controls/docs)
- [Cloud Tasks → Cloud Run](https://cloud.google.com/run/docs/triggering/using-tasks)
- ADR-004 — environment access model
