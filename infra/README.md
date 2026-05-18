# Sona — GCP infrastructure (Terraform)

Terraform layout for the stack described in [`docs/architecture-gcp-hipaa.md`](../docs/architecture-gcp-hipaa.md): **VPC + private Cloud SQL (PostgreSQL)**, **Serverless VPC Access** (for Cloud Run → SQL), **GCS** (exports) with optional **CMEK**, **Secret Manager** (app DB password), **Artifact Registry**, and **least-privilege service accounts**.

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
| **dev** | `project-a625d19b-de99-48e9-9a9` | Engineers; Cloud Build applies after approval |
| **stage** | TBD | Engineers + release automation |
| **prod** | TBD | Break-glass + Cloud Build apply SA only |

All three can sit under the **same Organisation** and even the **same billing account**; **IAM is per project**, so granting `roles/editor` on the **dev** project does **not** grant access to **prod** unless someone explicitly adds you there.

### When to use multiple billing accounts or organisations

- **Separate billing accounts** (e.g. prod vs non-prod): finance / cost centre separation; still use **separate projects** for IAM.
- **Separate organisations**: strongest isolation (e.g. regulated prod org vs dev shop); more overhead. Uncommon for an early MVP unless policy demands it.

This repo assumes **one GCP project per environment** (dev configured; stage/prod when created). See [`gcp-projects.yaml`](gcp-projects.yaml).

| Environment | Status | Project ID |
|-------------|--------|------------|
| **dev** | **Active** — SONA-MVP-DEV | `project-a625d19b-de99-48e9-9a9` |
| **stage** | Not created yet | `REPLACE_WHEN_CREATED` in `gcp-projects.yaml` |
| **prod** | Not created yet | `REPLACE_WHEN_CREATED` in `gcp-projects.yaml` |

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

### Dev (`project-a625d19b-de99-48e9-9a9`)

```bash
gcloud config set project project-a625d19b-de99-48e9-9a9

./infra/scripts/bootstrap-terraform-state.sh project-a625d19b-de99-48e9-9a9 europe-west2
./infra/scripts/bootstrap-cloud-build-iam.sh project-a625d19b-de99-48e9-9a9 1055416779632
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
cd infra/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
terraform init -backend-config-file=backend.hcl
terraform plan
```

### Other environments

When stage/prod projects exist, update [`gcp-projects.yaml`](gcp-projects.yaml), repeat bootstrap scripts with the new `project_id`, and add Cloud Build triggers with matching substitutions.

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
      dev/
      stage/
      prod/
```

## Wrapper scripts

From the repo root, after `cd infra` (or using full paths). These run `terraform init -backend-config-file=backend.hcl` automatically when `backend.hcl` exists (copy from `backend.hcl.example` first).

- **Windows:** `.\scripts\terraform-env.ps1 -Environment dev -Operation plan`
- **Unix:** `./scripts/terraform-env.sh dev plan`

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

Database password is in **Secret Manager** (`db_app_password_secret_id` output); retrieve only with audited break-glass or inject via CI from Terraform → Secret (already created by apply).

---

## Related documentation

- [`docs/architecture-gcp-hipaa.md`](../docs/architecture-gcp-hipaa.md)
- **GCP-native CI:** [`ci/cloud-build-terraform.md`](ci/cloud-build-terraform.md) (Cloud Build + optional Infrastructure Manager)
