# Demo data and LLM-backed drafts

## Two practice tenants

| Tenant | Bootstrap body | Purpose |
|--------|----------------|---------|
| **Monal Gajjar SLT — Demo** | `{ "practice": "demo" }` | Stable, realistic caseload for demos and screenshots |
| **Sona E2E (automated)** | `{ "practice": "e2e" }` | Playwright/API tests; ephemeral children with `· e2e` suffix |

Flutter `bootstrapDemoTenant()` sends `practice: "demo"`. E2E specs send `practice: "e2e"`.

## Canonical demo caseload

Four personas in `scripts/personas/*.json` include a `demo` block (`targetStage`, `triageOutcome`, registration fields). Stages:

| Persona | Target stage | Clinical snapshot |
|---------|--------------|-------------------|
| Aria (4yo speech sounds) | `prep_ready` | Intake done, prep brief ready |
| Jaden (7yo stutter) | `triaged` | Triage + session plan |
| Mia (11yo social comm) | `plan_ready` | Through plan draft |
| Theo (3yo feeding) | `summary_sent` | Parent summary published |

Seed locally or on dev API (non-production only):

```bash
# API running with DATABASE_URL
node scripts/seed-dev.ts
# or explicitly:
curl -sS -X POST "$SONA_API_URL/v1/demo/seed-canonical" \
  -H 'content-type: application/json' \
  -d '{"practice":"demo"}' | jq .
```

Idempotent: re-running updates stages without duplicating children (matched by `childDisplayName`).

Legacy multi-case seeding (timestamp suffixes) remains for load tests:

```bash
SEED_MODE=ephemeral node scripts/seed-dev.ts
```

## LLM-backed drafts (OpenAI-compatible)

When `INFERENCE_OPENAI_BASE_URL` is set, the API generates drafts for:

- Prep brief (after intake submit)
- Session plan (after triage)
- Clinical report (after parent summary publish)
- Parent summary HTML (on publish when no body supplied)

If the endpoint is unset or the call fails, behaviour falls back to the existing MVP stubs (no user-facing error).

### Environment variables

| Variable | Description |
|----------|-------------|
| `INFERENCE_OPENAI_BASE_URL` | Base URL for OpenAI-compatible API (vLLM on GKE, or Vertex AI endpoint) |
| `LLM_MODEL` | Model id sent in chat requests (default `google/gemma-3-27b-it`) |
| `LLM_API_KEY` | Optional bearer token (vLLM with API key) |
| `SONA_WEB_BASE_URL` | Used when seeding intake magic links |

For **Vertex AI** (usage-based, OpenAI-compatible), set the base URL to your regional endpoint and rely on **Application Default Credentials** (Cloud Run service account). The API adds a Google bearer token when the host contains `googleapis.com`.

Example (replace project, region, endpoint id):

```bash
INFERENCE_OPENAI_BASE_URL=https://europe-west2-aiplatform.googleapis.com/v1/projects/PROJECT/locations/europe-west2/endpoints/ENDPOINT_ID
LLM_MODEL=google/gemma-3-27b-it
```

Self-hosted **vLLM** on GKE (preferred per ADR-003) uses the internal or forwarded `/v1` base URL; optional `LLM_API_KEY` if the service is key-protected.

### Cost and hosting notes

- **Self-hosted vLLM** on GKE: pay for GPU node time; best for steady clinical volume.
- **Vertex AI endpoint**: pay per token / usage similar to Azure AI Foundry managed endpoints; no cluster to operate.
- Local dev: leave `INFERENCE_OPENAI_BASE_URL` unset; stubs apply automatically.

Deploy inference URL via Terraform / Cloud Run env after merge — do not patch production with ad-hoc `gcloud run services update`.
