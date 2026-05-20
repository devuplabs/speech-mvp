# ADR 004 — Unified architecture; production access lockdown

**Status:** Accepted  
**Date:** 2026-05-20  
**Depends on:** ADR-002 (GenUI A2UI), ADR-003 (self-hosted LLM)

## Context

Teams often split “demo” (Firebase AI, mock APIs) from “prod” (real BFF, real LLM). That creates two GenUI transports, two auth flows, and drift. Sona requires **one maintainable path** with stricter controls only in production.

## Decision

### One application architecture, all environments

```
Flutter (GenUI + genui_a2a) ──HTTPS──▶ Sona API (Cloud Run)
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    ▼                     ▼                     ▼
              Cloud SQL              GCS (exports)     Inference (GKE/GCE, private)
                    ▲
              Cloud Tasks → worker (same inference endpoint)
```

- **Dev:** synthetic tenants, fake intake JSON, inference against **dev** air-gap stack.
- **Stage:** production-like config; still non-production data unless approved test cohort.
- **Prod:** real data; **identical** service topology and container images (promoted by CI), not a different stack.

### GenUI transport (all environments)

| Item | Choice |
|------|--------|
| Package | `genui`, `genui_a2a`, `a2a` |
| Transport | **A2UI** stream from **Sona API** (implements agent/server side of protocol) |
| **Not used** | Firebase AI Logic, `genui_google_generative_ai` on client, direct Gemini from Flutter |

### Production access (GCP)

| Principal | `uk/dev`, `uk/stage` | `uk/prod`, `us/prod` |
|-----------|----------------------|----------------------|
| Engineers (daily) | Yes — least privilege | **No standing access** |
| Cloud Build deploy SA | Yes (apply after approval on stage/prod) | Yes — **only** routine deploy identity |
| Break-glass | Documented, MFA, ticket, time-bound | Same; logged in audit |

- **No interactive `gcloud`/console access** for developers on prod projects under normal operations.
- Secrets: **Secret Manager**; prod secret versions rotated via automation or break-glass runbook.
- **Terraform plan** on PR; **apply** to prod only from protected `main` + manual approval (existing Cloud Build doc).

### What may differ by environment (allowed)

| Dimension | Dev | Prod |
|-----------|-----|------|
| GCP `project_id` | e.g. `project-a625d19b-…` | Separate prod project |
| Data | Synthetic | PHI |
| Min instances / GPU size | Smaller | Sized for pilot load |
| Log verbosity | More debug fields (still no raw prompts) | Stricter redaction |
| WAF / rate limits | Relaxed | Cloud Armor on public endpoints |

## Consequences

- Onboarding: engineers work only in **dev** until promotion pipelines are trusted.
- Integration tests run against **dev** inference + API, not mocks of a different architecture.
- Demo videos / stakeholder walkthroughs use **dev** with synthetic data — same app build as prod.

## References

- [`infra/ci/cloud-build-terraform.md`](../../infra/ci/cloud-build-terraform.md)
- [`infra/gcp-projects.yaml`](../../infra/gcp-projects.yaml)
