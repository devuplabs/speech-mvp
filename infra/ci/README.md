# CI / CD

## Infrastructure (Terraform) — use Google Cloud Build

**Recommended:** GitHub stores Terraform and Cloud Build YAML; **Cloud Build** in your GCP project runs plan/apply.

| Doc | Purpose |
|-----|---------|
| [`cloud-build-terraform.md`](cloud-build-terraform.md) | Connect GitHub, create **plan** + **apply** triggers, enable **approvals** on apply |
| [`../scripts/setup-cloud-build.ps1`](../scripts/setup-cloud-build.ps1) | Automated bootstrap + triggers (run after GitHub OAuth) |
| [`triggers/`](triggers/) | Trigger YAML templates for `uk/dev` |
| [`cloudbuild.terraform.plan.yaml`](cloudbuild.terraform.plan.yaml) | PR / plan-only |
| [`cloudbuild.terraform.apply.yaml`](cloudbuild.terraform.apply.yaml) | `main` + human approval → `terraform apply` |
| [`../gcp-projects.yaml`](../gcp-projects.yaml) | Dev project id, state bucket, Cloud Build SA |

**Dev project:** `project-a625d19b-de99-48e9-9a9` (SONA-MVP-DEV).

We do **not** run Terraform apply from GitHub Actions in this layout (avoids storing GCP credentials in GitHub).

---

## Application deploys (future)

**App deploy:** `cloudbuild.api.yaml` + trigger template `triggers/sona-api-dev-deploy.yaml`. Requires Terraform `cloud_run` module applied first.

When you add more **Cloud Run** services, you can either:

- Add Cloud Build steps / separate triggers in the same GitHub-connected project, or
- Use **GitHub Actions + Workload Identity Federation** to push images and deploy (no JSON keys).

WIF pattern (optional, for app only):

1. Workload Identity Pool + Provider bound to your GitHub org/repo.
2. Map to a deployer service account with `roles/run.admin`, `roles/artifactregistry.writer`, etc.
3. Restrict prod to `main` or release tags.

References:

- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [google-github-actions/auth](https://github.com/google-github-actions/auth)
