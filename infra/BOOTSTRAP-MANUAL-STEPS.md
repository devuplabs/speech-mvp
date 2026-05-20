# Bootstrap and operations — manual steps

Terraform and Cloud Build configs in this repo are the **source of truth** for infrastructure. Normal deploys run **only** via GitHub triggers (plan on PR, apply on `main` after approval). Do **not** use `gcloud builds submit` for routine applies.

Use this document for steps that **cannot** be fully automated in code (human OAuth, org policy, quotas, break-glass recovery).

---

## Automated vs manual

| Step | Automated (scripts / Terraform) | Manual (human) |
|------|----------------------------------|----------------|
| State bucket | `bootstrap-terraform-state.*` | — |
| Cloud Build SA + IAM | `bootstrap-cloud-build-iam.*` | Narrow `roles/owner` after first apply (recommended) |
| Enable APIs | `setup-cloud-build.*` | — |
| GitHub connection | `setup-cloud-build.*` creates connection | **OAuth** in browser when `PENDING_USER_OAUTH` |
| GitHub App repo access | — | **Configure** app on org/repo (see below) |
| Link repository | `setup-cloud-build.*` or Console | Console preferred for webhooks |
| Cloud Build triggers | `setup-cloud-build.*` (REST API) | — |
| Phase 1 Terraform apply | **Trigger** `sona-terraform-dev-apply` | **Approve** build in GCP Console |
| Phase 2 GPU / vLLM | Terraform when `inference_enabled=true` | **GPU quota** request; upload model weights |
| Prod project creation | — | Create GCP project, billing, org policies |

---

## One-time per GCP project (new env: stage, prod, US)

Run from repo root with **Owner** on the target project. Replace project id, number, region, and jurisdiction paths from [`gcp-projects.yaml`](gcp-projects.yaml).

### 1. Terraform state bucket

```powershell
.\infra\scripts\bootstrap-terraform-state.ps1 -ProjectId "YOUR_PROJECT_ID" -Location "europe-west2"
```

### 2. Cloud Build service account (Terraform executor)

Creates `sona-cloudbuild@YOUR_PROJECT_ID.iam.gserviceaccount.com` with bootstrap IAM (`roles/owner` on project + state bucket access). **Narrow roles after the first successful apply** (see § Post-bootstrap hardening).

```powershell
.\infra\scripts\bootstrap-cloud-build-iam.ps1 -ProjectId "YOUR_PROJECT_ID" -ProjectNumber "YOUR_PROJECT_NUMBER"
```

Legacy `PROJECT_NUMBER@cloudbuild.gserviceaccount.com` often **does not exist** on new projects — triggers must use `sona-cloudbuild@...` (already set in CI YAML and trigger templates).

### 3. GitHub + triggers

```powershell
.\infra\scripts\setup-cloud-build.ps1 -ProjectId "YOUR_PROJECT_ID" -ProjectNumber "YOUR_PROJECT_NUMBER" -RepositoryName "devuplabs-speech-mvp"
```

**Manual — GitHub OAuth:** If the script exits with `PENDING_USER_OAUTH`, open the printed URL and authorize.

**Manual — GitHub App repository access:** Even when `installationState.stage` is `COMPLETE`, the app may lack access to the repo (common for org-private repos):

1. GitHub → **devuplabs** → Settings → GitHub Apps → **Google Cloud Build** → Configure  
2. **Repository access** → add `speech-mvp` (or all repos for dev only)

Org install example: https://github.com/organizations/devuplabs/settings/installations

**Manual — Cloud Build data sharing (if PR checks never appear):**  
[Cloud Build → Settings → Data sharing](https://console.cloud.google.com/cloud-build/settings/data-sharing)

### 4. Grant apply approvers

Users who may approve production applies need `roles/cloudbuild.builds.approver` on the project.

---

## Routine deploy (all environments)

1. Open PR → `sona-terraform-*-plan` runs (`terraform plan` only).
2. Review plan in [Cloud Build History](https://console.cloud.google.com/cloud-build/builds).
3. Merge to `main` → apply trigger starts and **waits for approval**.
4. **Manual:** Approver opens the build → **Approve** → `terraform apply` runs (~15–30 min first time; Cloud SQL is slow).

No `gcloud builds submit` in the standard workflow.

---

## Terraform behaviour encoded in modules (no extra manual config)

These fixes are in code so CI matches what was validated on uk/dev:

| Area | Implementation |
|------|----------------|
| MVP phase 1 | `_INFERENCE_ENABLED=false` on triggers; `inference_enabled = false` in tfvars example |
| VPC connector | `min_instances = 2`, `max_instances = 3` in `modules/network` |
| Cloud SQL Postgres 16 + cheap tier | `edition = "ENTERPRISE"` (default) so `db-f1-micro` works; override for prod (below) |
| Cloud Build identity | `serviceAccount: sona-cloudbuild@...` in plan/apply YAML |
| Linked repo name | `devuplabs-speech-mvp` (not `speech-mvp`) in `setup-cloud-build` and `gcp-projects.yaml` |

---

## Prod / stage differences (configure in Terraform, not one-off CLI)

| Setting | dev (MVP) | stage / prod (typical) |
|---------|-----------|-------------------------|
| `db_edition` | `ENTERPRISE` (default) | `ENTERPRISE_PLUS` if policy requires |
| `db_tier` | `db-f1-micro` | `db-g1-small`, `db-custom-*`, or `db-perf-optimized-N-*` |
| `db_deletion_protection` | `false` | `true` |
| `gcs_bucket_force_destroy` | `true` | `false` |
| `inference_enabled` | `false` then `true` | `true` when GPU + model ready |
| Cloud Build SA IAM | `roles/owner` bootstrap only | Least-privilege custom role |
| Apply approval | Required | **Required** |

Set substitutions on the prod apply trigger (`_DB_TIER`, `_INFERENCE_ENABLED`, etc.) to match `terraform.tfvars` for that environment.

---

## Post-bootstrap hardening (manual, recommended)

After the **first successful** `terraform apply` on a project:

1. Remove `roles/owner` from `sona-cloudbuild@...` (replace with a custom role: state bucket, Terraform resource APIs, `cloudkms.admin`, `compute.networkAdmin`, etc.).
2. Keep `roles/iam.serviceAccountUser` binding for `service-PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com` on `sona-cloudbuild`.
3. Document break-glass Owner for humans in your access policy ([ADR-004](../docs/decisions/004-unified-environments-access.md)).

---

## Recovery: partial failed apply

### VPC connector `409` or `ERROR` state

A failed apply can leave `sona-vpc-cn` in GCP without Terraform state:

```powershell
gcloud compute networks vpc-access connectors delete sona-vpc-cn `
  --region=europe-west2 --project=YOUR_PROJECT_ID --quiet
```

Re-run apply via the **approved trigger** (not manual submit).

### Cloud SQL tier / edition errors

If apply fails with `Invalid Tier (db-f1-micro) for (ENTERPRISE_PLUS) Edition`, ensure `db_edition = "ENTERPRISE"` in tfvars (module default) or use a tier valid for Enterprise Plus.

---

## Phase 2 — inference (manual prerequisites)

Before setting `inference_enabled = true` and `_INFERENCE_ENABLED=true`:

1. **Manual:** Request **NVIDIA L4** quota in the inference zone (e.g. `europe-west2-b`).
2. **Manual:** Upload model weights to the models bucket (`model_gcs_prefix`).
3. **Manual:** Mirror `vllm/vllm-openai` to Artifact Registry.
4. Merge Terraform change + **approve** apply trigger.

---

## Related docs

- [`MVP-INFRA.md`](MVP-INFRA.md) — uk/dev phase 1 checklist  
- [`ci/cloud-build-terraform.md`](ci/cloud-build-terraform.md) — trigger wiring  
- [`docs/cloud-build-github-troubleshooting.md`](../docs/cloud-build-github-troubleshooting.md) — GitHub App / `/gcbrun` issues
