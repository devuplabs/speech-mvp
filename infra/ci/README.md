# CI / CD

## Infrastructure (Terraform) — use Google Cloud Build

**Recommended:** GitHub stores Terraform and Cloud Build YAML; **Cloud Build** in your GCP project runs plan/apply.

| Doc | Purpose |
|-----|---------|
| [`cloud-build-terraform.md`](cloud-build-terraform.md) | Connect GitHub, create **plan** + **apply** triggers, enable **approvals** on apply |
| [`../scripts/setup-cloud-build.ps1`](../scripts/setup-cloud-build.ps1) | Automated bootstrap + triggers (run after GitHub OAuth) |
| [`triggers/`](triggers/) | Trigger YAML templates for `uk/dev` |
| [`cloudbuild.terraform.plan.yaml`](cloudbuild.terraform.plan.yaml) | PR / plan-only |
| [`cloudbuild.terraform.apply.yaml`](cloudbuild.terraform.apply.yaml) | `main` + `infra/**` + human approval → `terraform apply` |
| [`cloudbuild.api.yaml`](cloudbuild.api.yaml) | `main` + `apps/api/**` → build image + deploy Cloud Run |
| [`../gcp-projects.yaml`](../gcp-projects.yaml) | Dev project id, state bucket, Cloud Build SA |

**Dev project:** `project-a625d19b-de99-48e9-9a9` (SONA-MVP-DEV).

We do **not** run Terraform apply from GitHub Actions in this layout (avoids storing GCP credentials in GitHub).

---

## Application deploys (Cloud Run)

**Policy: no direct deploys.** Do not run `gcloud builds submit`, `gcloud run deploy`, or `flutter build` + manual push from a laptop to change dev/prod. All releases go through a **pull request → merge to `main` → Cloud Build trigger**.

| Trigger | Config | When |
|---------|--------|------|
| **sona-api-dev-deploy** | [`cloudbuild.api.yaml`](cloudbuild.api.yaml) | Push to `main` when `apps/api/**` or `infra/ci/cloudbuild.api.yaml` changes |
| **sona-web-dev-deploy** | [`cloudbuild.web.yaml`](cloudbuild.web.yaml) | Push to `main` when `apps/sona/**` or `infra/ci/cloudbuild.web.yaml` changes |

Requires Terraform `cloud_run` applied first. Triggers created/updated by [`../scripts/setup-cloud-build.ps1`](../scripts/setup-cloud-build.ps1) `-UpdateTriggers` (run once after merging trigger YAML to `main`).

**Verify both app triggers exist** (Console → Cloud Build → Triggers, region `europe-west2`):

- `sona-api-dev-deploy`
- `sona-web-dev-deploy`

If `sona-web-dev-deploy` is missing, merges that only touch `apps/sona/**` will **not** update [sona-web-dev](https://sona-web-dev-3rhenudy6a-nw.a.run.app). Run `setup-cloud-build.ps1 -SkipBootstrap -UpdateTriggers` after merging infra changes (requires Owner/project admin), or create the trigger from [`triggers/sona-web-dev-deploy.yaml`](triggers/sona-web-dev-deploy.yaml) in Console. Then run the trigger once on `main` (Console **Run** or `gcloud builds triggers run sona-web-dev-deploy --branch=main`) — do **not** use `gcloud builds submit` from a laptop.

Merging CI YAML alone does **not** create the trigger in GCP; terraform apply on `infra/**` also does not create Cloud Build triggers.

**Hosted dev URLs** (after CI deploy): see [`../../docs/DEMO.md`](../../docs/DEMO.md).

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
