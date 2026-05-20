# Architecture review vs Google developer documentation

**Date:** 2026-05-20 (updated after ADR-003/004)  
**Method:** [Google Developer Knowledge MCP](https://developerknowledge.googleapis.com/mcp) (`search_documents`) cross-checked against repo artifacts.

## Summary

| Area | Repo alignment | Notes |
|------|----------------|-------|
| **Jurisdiction / data residency** | ADR-001 | Separate UK/US SQL — confirmed. |
| **Cloud SQL + Cloud Run** | VPC connector in Terraform | [connect-run](https://cloud.google.com/sql/docs/postgres/connect-run) — aligned. API/workers reach **private inference** on same VPC. |
| **LLM** | ADR-003 self-hosted air-gap | **Not** managed Vertex API for Sona inference. MCP Vertex location docs apply only if a future ADR reopens managed APIs. |
| **Cloud Build + GitHub** | Plan/apply YAML | GitOps pattern — aligned. Prod apply without developer console access (ADR-004). |
| **Cloud Tasks async LLM** | Architecture | [using-tasks](https://cloud.google.com/run/docs/triggering/using-tasks) — worker calls **internal** inference URL. |
| **Frontend** | Flutter + GenUI **A2UI** | [GenUI A2UI](https://docs.flutter.dev/ai/genui/get-started) server path — **same** in dev and prod (ADR-002, ADR-004). |
| **Flutter web hosting** | GCS+CDN or Firebase Hosting | Static only; PHI via API. |
| **HIPAA / GCP** | Cloud Run, SQL, GCS, GKE | Re-verify eligible list at BAA; inference on **private GKE** is in-scope engineering, not a separate demo stack. |

## Infra Terraform — current vs needed

**In repo today:** VPC, private Cloud SQL, VPC connector, GCS/KMS, Secret Manager, Artifact Registry, runtime SA.

**In Terraform (ADR-003):**

1. **`modules/inference`** — GKE L4 pool, vLLM Deployment, internal LB, egress deny firewall.
2. **`modules/model_storage`** — CMEK bucket for Gemma weights.
3. **`modules/cloud_tasks`** — `sona-llm-{env}` queue.
4. **`modules/sona_environment`** — wires all roots `{uk|us}/{dev,stage,prod}`.

**Still manual before apply:** mirror `vllm-openai` image to Artifact Registry; upload `gemma-3-27b-it/` to models bucket; GPU quota.

**Later:** Flutter web hosting (ADR-005 TBD); prod GKE control plane CIDR lockdown (`gke_master_authorized_cidrs`).

## Application architecture (current)

```
Flutter (genui + genui_a2a) ──A2UI/HTTPS──▶ Sona API (Cloud Run)
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    ▼                         ▼                         ▼
              Cloud SQL                   GCS                    Inference (GKE/GCE)
                    ▲
              Cloud Tasks → worker ──────────┘
```

**Dev vs prod:** identical diagram; different GCP project, data (synthetic vs PHI), and IAM (ADR-004).

## GenUI + regulated data

Per [GenUI get started](https://docs.flutter.dev/ai/genui/get-started):

- Use **GenUI A2UI** / server agent — Sona API implements the server side.
- **Do not** use Firebase AI Logic or client-side Gemini for any environment.
- Demo walkthroughs use **dev** API + synthetic data, not a forked client.

## Open items

1. Google **BAA** + eligible services snapshot.
2. **GKE/GPU Terraform** in `uk/dev`.
3. ~~Lock model~~ — **Gemma 3 27B IT** (`google/gemma-3-27b-it`) + vLLM image; mirror weights to GCS.
4. DPIA before prod PHI.
5. Pen-test before scale-out.

## Document map

| Doc | Role |
|-----|------|
| [`decisions/002-flutter-genui-client.md`](decisions/002-flutter-genui-client.md) | Flutter + A2UI → API |
| [`decisions/003-self-hosted-llm-air-gap.md`](decisions/003-self-hosted-llm-air-gap.md) | Air-gap LLM |
| [`decisions/004-unified-environments-access.md`](decisions/004-unified-environments-access.md) | Same arch; prod access lockdown |
| [`architecture-gcp-hipaa.md`](architecture-gcp-hipaa.md) | Full GCP architecture |
