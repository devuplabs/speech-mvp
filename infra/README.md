# Sona — GCP infrastructure (Terraform)

Terraform layout for the stack in [`docs/architecture-gcp-hipaa.md`](../docs/architecture-gcp-hipaa.md):

- **VPC** + private **Cloud SQL** + **Serverless VPC Access**
- **GCS** (exports + **model weights**) with **CMEK**
- **GKE + vLLM** (Gemma 3 27B IT, air-gap) — [`modules/inference`](terraform/modules/inference/README.md)
- **Cloud Tasks** (async LLM jobs)
- **Secret Manager**, **Artifact Registry**, runtime service accounts

All environment roots use the composite module [`terraform/modules/sona_environment`](terraform/modules/sona_environment/README.md).

---

## GCP accounts: “subscription” vs project

Google Cloud does **not** use the word *subscription* (that is an Azure term). The closest mapping is:

| Concept | What it is |
|--------|------------|
| **Google account / Cloud Identity** | Who can log in to the console (`user@company.com`). |
| **Organisation** | Optional root for many projects; centralises org policies and folders. |
| **Project** | The unit of **API enablement, billing attachment, IAM, and resource names**. Terraform `project_id` almost always means **one GCP project**. |
| **Billing account** | Paying entity; **many projects** can link to **one** billing account. Billing admin ≠ automatic data access to all projects. |

### Should dev, stage, and prod share one project?

**No** — not if you want “dev access must not imply prod access.”

**Recommended:** **One GCP project per environment** (minimum):

| Environment | Example project id | Who gets IAM here |
|-------------|--------------------|-------------------|
| **dev** | `project-a625d19b-de99-48e9-9a9` | Engineers; synthetic data; full stack including **GKE inference** |
| **stage** | TBD | Engineers + release automation; production-like config |
| **prod** | TBD | **No standing developer access** — Cloud Build apply SA + break-glass only ([ADR-004](../docs/decisions/004-unified-environments-access.md)) |

All three can sit under the **same Organisation** and even the **same billing account**; **IAM is per project**, so granting `roles/editor` on the **dev** project does **not** grant access to **prod** unless someone explicitly adds you there.

### When to use multiple billing accounts or organisations

- **Separate billing accounts** (e.g. prod vs non-prod): finance / cost centre separation; still use **separate projects** for IAM.
- **Separate organisations**: strongest isolation (e.g. regulated prod org vs dev shop); more overhead. Uncommon for an early MVP unless policy demands it.

This repo assumes **one GCP project per environment** (dev configured; stage/prod when created). See [`gcp-projects.yaml`](gcp-projects.yaml).

| Jurisdiction | Environment | Status | Project ID |
|--------------|-------------|--------|------------|
| **uk** | dev | **Active** — SONA-MVP-DEV | `project-a625d19b-de99-48e9-9a9` |
| **uk** | stage / prod | Not created | See `gcp-projects.yaml` |
| **us** | all | Not created | Separate US project per env (no shared DB with UK) |

**v1 rule:** one **Cloud SQL** per jurisdiction — never mix US PHI and UK data. See [`docs/decisions/001-data-residency-jurisdiction-stacks.md`](../docs/decisions/001-data-residency-jurisdiction-stacks.md).

**Deploy from GitHub:** use **Cloud Build** (plan on PR, apply on `main` with approval) — not GitHub Actions for Terraform. Full steps: [`ci/cloud-build-terraform.md`](ci/cloud-build-terraform.md).

---

## Prerequisites

1. **Dev project** created (see table above). Stage/prod when you are ready.
2. A user with **Owner** (or equivalent) on the dev project for first-time bootstrap.
3. [Terraform](https://developer.hashicorp.com/terraform/install) **>= 1.5** (optional if you only use Cloud Build).
4. [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud`) for bootstrap scripts.

---

## One-time bootstrap (dev project)

Terraform state lives in the **same project** as the workload.

### UK dev (`project-a625d19b-de99-48e9-9a9`)

```bash
gcloud config set project project-a625d19b-de99-48e9-9a9

./infra/scripts/bootstrap-terraform-state.sh project-a625d19b-de99-48e9-9a9 europe-west2
./infra/scripts/bootstrap-cloud-build-iam.sh project-a625d19b-de99-48e9-9a9 1055416779632

cd infra/terraform/environments/uk/dev
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
```

**Windows (PowerShell):**

```powershell
gcloud config set project project-a625d19b-de99-48e9-9a9
.\infra\scripts\bootstrap-terraform-state.ps1 -ProjectId "project-a625d19b-de99-48e9-9a9" -Location "europe-west2"
.\infra\scripts\bootstrap-cloud-build-iam.ps1 -ProjectId "project-a625d19b-de99-48e9-9a9" -ProjectNumber "1055416779632"
```

Then connect **GitHub** and create Cloud Build triggers — [`ci/cloud-build-terraform.md`](ci/cloud-build-terraform.md).

### Local Terraform (optional)

```bash
./infra/scripts/terraform-env.sh uk dev plan
```

### US stack

When you create a **US** GCP project, bootstrap it in `us-central1`, fill in `gcp-projects.yaml` under `jurisdictions.us`, and apply `infra/terraform/environments/us/dev`.

---

## Layout

```
infra/
  README.md                 ← you are here
  gcp-projects.yaml          ← project id / state bucket registry (dev filled in)
  scripts/
    bootstrap-terraform-state.sh
    bootstrap-terraform-state.ps1
    bootstrap-cloud-build-iam.sh
    bootstrap-cloud-build-iam.ps1
    terraform-env.sh
    terraform-env.ps1
  ci/
    README.md
    cloud-build-terraform.md   ← GitHub + Cloud Build + approvals (start here)
    cloudbuild.terraform.plan.yaml
    cloudbuild.terraform.apply.yaml
    cloudbuild.terraform.yaml  ← legacy single-file trigger
  terraform/
    modules/
      enable_apis/          ← Project API enablement
      network/              ← VPC, PSA peering, Serverless VPC connector
      kms/                  ← Key ring + crypto key for GCS bucket CMEK (SQL CMEK optional add-on)
      cloud_sql/            ← Private IP PostgreSQL + app database + user
      storage/              ← Export bucket (+ IAM for app SA + KMS for GCS SA)
      app_identity/         ← Cloud Run / runtime service account + roles
      artifact_registry/    ← Docker repository for Cloud Run images
    environments/
      uk/   dev | stage | prod
      us/   dev | stage | prod
```

## Wrapper scripts

From the repo root, after `cd infra` (or using full paths). These run `terraform init -backend-config-file=backend.hcl` automatically when `backend.hcl` exists (copy from `backend.hcl.example` first).

- **Windows:** `.\scripts\terraform-env.ps1 -Jurisdiction uk -Environment dev`
- **Unix:** `./scripts/terraform-env.sh uk dev plan`

---

## Prod vs dev defaults

| Setting | dev | stage | prod (example tfvars) |
|--------|-----|-------|------------------------|
| `deletion_protection` (SQL) | `false` | `true` | `true` |
| `min_backup_retained` | lower | medium | per policy / counsel |
| Engineer `Editor` on project | yes (team norm) | optional | **avoid** — use break-glass |

Tune `terraform.tfvars` per environment; do not commit real `terraform.tfvars`.

---

## Outputs

After `terraform apply`, note:

- `cloud_sql_instance_connection_name` — Cloud SQL Auth Proxy / connector string.
- `vpc_connector_name` — attach to Cloud Run (`vpc-access-connector`).
- `runtime_service_account_email` — Cloud Run **service account** (runtime identity).
- `artifact_registry_url` — `docker push` target.
- `models_bucket_name` — upload `gemma-3-27b-it/` weights before vLLM pod starts.
- `llm_cloud_tasks_queue_name` — async LLM worker target.
- `inference_vllm_openai_base_url` — Sona API `INFERENCE_OPENAI_BASE_URL` (after internal LB IP is assigned).

Database password is in **Secret Manager** (`db_app_password_secret_id` output); retrieve only with audited break-glass or inject via CI from Terraform → Secret (already created by apply).

### Inference prerequisites (`uk/dev`)

1. Request **NVIDIA L4** quota in `europe-west2-b` (or your `inference_zone`).
2. Mirror **vLLM** image to Artifact Registry (see `modules/inference/README.md`).
3. Upload **Gemma 3 27B IT** (AWQ recommended) to `inference_model_gcs_uri` output path.
4. Set `vllm_container_image` in `terraform.tfvars`.
5. `terraform apply` — GKE + vLLM deploy may take 15–25 minutes; re-run if `inference_vllm_openai_base_url` was empty on first pass (internal LB IP pending).

---

## Application deploy (planned)

Terraform today provisions **data plane + Artifact Registry** for the **Sona API** container. Application CI (not yet in repo) will add:

| Artifact | Build | Deploy target |
|----------|-------|----------------|
| **Sona API** | `docker build` → Artifact Registry | Cloud Run (regional) |
| **Inference** | vLLM + **Gemma 3 27B IT** weights (GCS CMEK) | GKE + L4 GPU, private subnet ([ADR-003](../docs/decisions/003-self-hosted-llm-air-gap.md)) |
| **Flutter web** | `flutter build web` | GCS + CDN or Firebase Hosting |
| **Flutter mobile** | `flutter build apk/ipa` | Stores (post-pilot) |

See [`apps/README.md`](../apps/README.md) and [`docs/decisions/002-flutter-genui-client.md`](../docs/decisions/002-flutter-genui-client.md).

---

## Related documentation

- [`docs/architecture-gcp-hipaa.md`](../docs/architecture-gcp-hipaa.md)
- [`docs/architecture-review-gcp-2026.md`](../docs/architecture-review-gcp-2026.md) — Google Developer Knowledge MCP cross-check
- [`docs/decisions/`](../docs/decisions/) — ADRs (residency, Flutter/A2UI, air-gap LLM, unified envs)
- **GCP-native CI:** [`ci/cloud-build-terraform.md`](ci/cloud-build-terraform.md) (Cloud Build + optional Infrastructure Manager)
