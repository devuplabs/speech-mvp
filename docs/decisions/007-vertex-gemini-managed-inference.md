# ADR 007 — Managed Vertex AI Gemini for inference (pilot), with self-hosted air-gap as fallback

**Status:** Accepted
**Date:** 2026-06-14
**Amends:** ADR-003 (self-hosted, air-gapped Gemma on GKE/vLLM) — see "Relationship to ADR-003"
**Depends on:** ADR-001 (UK data residency / jurisdiction stacks), ADR-005 (portal-first patient comms)
**Informs:** DEV-13 (wire live inference), DEV-32 (DPIA), DEV-52 (Vertex safeguards), DEV-53 (prompt data-minimisation); supersedes the critical-path role of DEV-11 (GPU quota) / DEV-12 (vLLM deploy)

## Context

ADR-003 chose a self-hosted, air-gapped LLM (Gemma 3 27B on GKE + vLLM) so PHI never leaves our VPC. That is the maximal-isolation posture, but it carries a GPU-quota lead time, GKE/vLLM operational burden, and a **fixed** GPU cost that is paid whether or not anyone is using it.

For the **pilot** (one solo private-practice clinician, low case volume) we re-evaluated against managed inference on **Vertex AI (Gemini)** — GCP's equivalent of "pick a model, call a managed endpoint." Two facts drove the decision:

### 1. Cost — at pilot scale, managed is ~100–1000× cheaper
Each case produces ~4 AI drafts (prep brief, session plan, family summary, clinical report) ≈ ~10k input + ~3k output tokens.

| Path | Cost basis | ~50 cases/mo (pilot) | Notes |
|---|---|---|---|
| Vertex **Gemini Flash** ($0.30/$2.50 per 1M tok) | per-token | **~$0.50/mo** | ~$0.01/case |
| Vertex **Gemini Pro** ($1.25/$10 per 1M tok) | per-token | **~$2/mo** | ~$0.04/case |
| **Self-hosted Gemma 27B** (GKE GPU 24/7) | fixed | **~$1,100–2,800/mo** | idle or not |

Crossover where self-hosting's fixed cost wins is ~27k cases/month (Pro) / ~110k (Flash) — far beyond pilot scale. **Self-hosting is therefore an isolation/control decision, not a cost decision.** At pilot volume the air-gap premium (~$1–3k/mo of mostly-idle GPU + ops time) is not justified.

### 2. Compliance — managed Vertex can be made GDPR-defensible for children's special-category data
Vertex AI (the **enterprise** Cloud product — *not* the consumer Gemini app or AI Studio free tier) supports the controls a UK paediatric-health product needs: contractual **no-training on customer data**, **Zero Data Retention**, **EU/UK data residency**, **DPA/BAA**, and **private networking**. The residual is that Google processes our (PHI-containing) prompts as our **data processor** — acceptable under contract, but not the same as "PHI never leaves our control." That residual is the price we knowingly accept for the cost/speed benefit at pilot scale.

## Decision

**Use managed Vertex AI Gemini as the inference path for the pilot and early production.** Default to **Gemini Flash** for most drafts (cheap, fast, sufficient) and **Gemini Pro** where output quality warrants it (e.g. clinical report). The API already speaks an OpenAI-compatible interface, so this is a configuration/endpoint change, not an app rewrite.

**Self-hosted Gemma on GKE/vLLM (ADR-003) is retained as a documented fallback** for any future customer who *contractually requires* true air-gap (e.g. certain NHS/enterprise deals). Because inference sits behind a provider-agnostic client and is guarded by the eval harness (DEV-15), switching to self-hosting later is a contained change with measurable quality parity.

This decision is conditional on **every safeguard below being in place before any real patient data flows.** This is a healthcare product: managed inference is acceptable *only* fully locked down. (See the project's "Go-Live Compliance Gate".)

## Mandatory safeguards (conditions of use — all required before real data)

1. **Enterprise Vertex only.** Use Vertex AI on an **invoiced Cloud Billing account**. Never the consumer Gemini app or AI Studio free tier (those may use data to improve products and are out of scope for PHI). The API must target the Vertex endpoint, never `generativelanguage.googleapis.com` free tier.
2. **No training on our data.** Rely on Google's AI/ML Privacy Commitment (Vertex does not use prompts/responses to train its or others' models) and confirm it in the contract. Do not opt into any data-sharing/improvement programs.
3. **Zero Data Retention.** Request the **abuse-monitoring logging exemption / ZDR** on the Vertex endpoints we use, so prompts/responses are not logged or retained for abuse review. Confirm ZDR covers the default ~24h input cache, or disable caching. Verify ZDR availability for the chosen Gemini model in our region.
4. **Data residency.** Region-pin to **`europe-west2` (London)** (or EU); ensure ML processing, any caches, and backups stay in-region. No cross-jurisdiction processing (ADR-001).
5. **Contracts.** Sign the **Google Cloud DPA** (UK GDPR — Google as processor, us as controller) and a **BAA** where applicable; ensure SCCs / UK IDTA cover any international transfer. Add **Google/Vertex to the published subprocessor list**.
6. **Network isolation.** Reach Vertex via **Private Service Connect** (no public internet egress for inference) inside a **VPC Service Controls** perimeter; **CMEK** for any at-rest data. Restrict the runtime SA to least-privilege Vertex access.
7. **Data minimisation (DEV-53).** Strip direct identifiers — child name, DOB, address, parent contact — from prompts; send only the clinical context the model needs. Reduces PHI exposure to the processor and satisfies the GDPR minimisation principle. (Pseudonymise, re-attach identifiers in our own layer.)
8. **No PHI in logs (extends DEV-23).** Never log prompts, responses, or model inputs/outputs. Inference logging records model id, case id, latency, outcome only.
9. **Clinician-in-the-loop (unchanged).** Every AI output remains a clearly-labelled DRAFT requiring clinician review/sign-off before it reaches a family. Vertex never auto-sends.
10. **DPIA (DEV-32).** Update the DPIA to reflect Google/Vertex as a subprocessor handling special-category data about children, with these safeguards as the mitigations; obtain DPO/legal sign-off and **design-partner (controller) acceptance** of Google as a subprocessor before go-live.
11. **Audit.** Record that inference occurred (model, case, timestamp — no content) in the audit trail.

## Relationship to ADR-003
ADR-003 is **not deleted** (per our "supersede, don't delete" rule). Its self-hosted design remains the **air-gap fallback**. ADR-007 changes the *default* inference path for the pilot/early production to managed Vertex. If a customer contract mandates that no third party process PHI, we invoke ADR-003 (file GPU quota, deploy vLLM/Gemma) for that tenant.

## Consequences

**Positive**
- Removes the GPU-quota long-pole and GKE/vLLM ops from the pilot critical path — live AI ships in days, not weeks.
- Cents-per-case economics; no idle GPU spend.
- Compliant-by-configuration (no-training, ZDR, residency, DPA/BAA, VPC-SC/PSC, CMEK) — a legitimate production posture, not a shortcut, *provided the safeguards above hold*.
- Provider-agnostic client + eval harness ⇒ low-risk exit to self-hosting or another provider.

**Costs / risks (accepted)**
- Google **processes PHI as our processor** — not air-gapped. Mitigated by contracts + ZDR + data minimisation, and disclosed in the DPIA/subprocessor list. This is the core trade-off.
- Dependency on a managed third party (availability, pricing, model deprecation). Mitigated by the swap-friendly client.
- ZDR/abuse-exemption and BAA/DPA scope must be **confirmed**, not assumed — see Open questions.

## Open questions (confirm before real data)
1. ZDR / abuse-logging exemption available and enabled for the chosen Gemini model in `europe-west2`? (incl. the input cache)
2. DPA + BAA scope confirmed to cover the exact Vertex services/region used?
3. Gemini **Flash vs Pro** per draft kind — pick by eval-harness quality vs cost (DEV-15).
4. Design partner (controller) sign-off on Google as subprocessor recorded in the DPIA.

> Note: an earlier draft PR (#56) proposed a `006-vertex-gemini-first-ai-loop-dev.md` ADR; that number is now taken by the FHIR ADR (006). This ADR (007) is the authoritative record — #56 should be rebased onto it or closed.

## References
- [Vertex AI data governance — no training on your data](https://cloud.google.com/vertex-ai/generative-ai/docs/data-governance)
- [Vertex AI abuse monitoring & logging](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/learn/abuse-monitoring)
- [Zero Data Retention for Gemini / Vertex](https://ai.google.dev/gemini-api/docs/zdr)
- [Vertex AI generative-AI security controls (VPC-SC, private endpoints, CMEK)](https://docs.cloud.google.com/vertex-ai/docs/generative-ai/genai-security-controls)
- [Google Cloud HIPAA / BAA](https://cloud.google.com/security/compliance/hipaa)
- [Gemini / Vertex pricing](https://ai.google.dev/gemini-api/docs/pricing)
- Internal: ADR-001 (residency), ADR-003 (self-hosted air-gap), ADR-005 (portal-first comms), and the project "Go-Live Compliance Gate".
