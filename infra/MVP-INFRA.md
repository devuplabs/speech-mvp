# MVP infrastructure bootstrap (uk/dev)

End-to-end path for **core GCP** only — no GKE/GPU until phase 2.

## What gets deployed (phase 1)

| Component | Purpose |
|-----------|---------|
| VPC + VPC connector | Private Cloud SQL + future Cloud Run |
| Cloud SQL (PostgreSQL 16) | App database |
| KMS + CMEK buckets | Exports + model storage |
| Secret Manager | DB password |
| Artifact Registry | Future app + vLLM images |
| Cloud Tasks | Async LLM jobs queue |
| Runtime SA | Cloud Run identity |

**Not in phase 1:** GKE, vLLM, GPU (`inference_enabled = false`).

## CI/CD flow

```mermaid
flowchart LR
  PR[PR to main] --> Plan[sona-terraform-dev-plan]
  Plan --> Review[Review plan in Cloud Build]
  Merge[Merge PR] --> Apply[sona-terraform-dev-apply]
  Apply --> Approve[Approve in GCP Console]
  Approve --> GCP[Resources in SONA-MVP-DEV]
```

1. Open PR → **plan** runs automatically (`sona-terraform-dev-plan`).
2. Merge to `main` → **apply** trigger starts, waits for **approval**.
3. [Cloud Build → History](https://console.cloud.google.com/cloud-build/builds;region=europe-west2?project=1055416779632) → approve `sona-terraform-dev-apply`.
4. First apply takes **~15–30 min** (Cloud SQL private IP is slow).

## Phase 2 (inference)

When ready:

1. Request **L4 GPU quota** in `europe-west2-b`.
2. Upload Gemma weights to the models bucket.
3. Mirror `vllm/vllm-openai` to Artifact Registry.
4. Set `_INFERENCE_ENABLED=true` on apply trigger and `inference_enabled = true` in tfvars.
5. Merge + approve apply.

## Manual apply (optional)

```powershell
gcloud builds submit . `
  --project=project-a625d19b-de99-48e9-9a9 `
  --region=europe-west2 `
  --config=infra/ci/cloudbuild.terraform.apply.yaml
```

## Outputs after apply

```bash
cd infra/terraform/environments/uk/dev
terraform output
```

Key values: `cloud_sql_instance_connection_name`, `runtime_service_account_email`, `exports_bucket_name`, `models_bucket_name`.
