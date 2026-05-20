# Cloud Build + GitHub — troubleshooting

**Routine deploys:** GitHub triggers only (no `gcloud builds submit`). One-time human steps: [`infra/BOOTSTRAP-MANUAL-STEPS.md`](../infra/BOOTSTRAP-MANUAL-STEPS.md).

## “I authorized OAuth but never saw the GitHub App install prompt”

That is **often normal**. On the current connection:

| Field | Value |
|-------|--------|
| `installationState.stage` | **COMPLETE** |
| `githubConfig.appInstallationId` | `134099335` (org: [devuplabs install](https://github.com/organizations/devuplabs/settings/installations/134099335)) |
| Linked repository name | `devuplabs-speech-mvp` |
| OAuth user | Your GitHub account (shown in connection `githubConfig`) |

OAuth and app install can happen in one flow, or the app was **already installed** on your GitHub user/org from a previous GCP project. You do **not** need a second prompt if `stage` is `COMPLETE`.

Verify anytime:

```powershell
gcloud builds connections describe sona-github `
  --region=europe-west2 --project=project-a625d19b-de99-48e9-9a9 `
  --format="yaml(installationState,githubConfig)"
```

## Terraform apply: VPC connector failures

**409 — entity already exists:** A partial apply left `sona-vpc-cn` in GCP but not in Terraform state. Delete and re-apply:

```powershell
gcloud compute networks vpc-access connectors delete sona-vpc-cn `
  --region=europe-west2 --project=project-a625d19b-de99-48e9-9a9 --quiet
```

**Error code 3 — must specify max_throughput or max_instances:** The connector resource needs `min_instances` / `max_instances` (fixed in `infra/terraform/modules/network/main.tf`).

**Cloud SQL — Invalid Tier for ENTERPRISE_PLUS:** `db-f1-micro` is not valid on Postgres 16’s default edition. Use `edition = "ENTERPRISE"` in the Cloud SQL module (or a `db-perf-optimized-*` tier).

## Build starts then fails immediately (`invalid build.service_account`)

Some projects **do not have** the legacy `PROJECT_NUMBER@cloudbuild.gserviceaccount.com` account. Triggers must use an existing user-managed SA (e.g. `sona-cloudbuild@PROJECT_ID.iam.gserviceaccount.com`) with:

- `roles/iam.serviceAccountUser` for `service-PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com`
- `roles/logging.logWriter` (build configs use `logging: CLOUD_LOGGING_ONLY`)
- Terraform permissions (`roles/editor` for bootstrap; narrow later)

Run `.\infra\scripts\bootstrap-cloud-build-iam.ps1` to create/configure `sona-cloudbuild`.

## Triggers must match the linked repository name

Console link creates names like **`devuplabs-speech-mvp`**, not `speech-mvp`. Stale trigger repository paths fail silently or reject events.

Triggers must include  
`serviceAccount: projects/PROJECT_ID/serviceAccounts/sona-cloudbuild@PROJECT_ID.iam.gserviceaccount.com`.

## What you still must do: grant repo access to the app

The app can be installed but **not allowed to read** `devuplabs/speech-mvp` (common for **org-owned private** repos).

1. Open **GitHub → Settings → Applications → Installed GitHub Apps**  
   Or org admins: **devuplabs → Settings → GitHub Apps → Google Cloud Build**
2. Click **Configure** on **Google Cloud Build**.
3. Under **Repository access**, choose **Only select repositories** and add **`speech-mvp`** (or “All repositories” for dev only).
4. Save.

Direct link (user installation — adjust if your org uses an org-level install):

https://github.com/settings/installations/134099335

## Link the repo in GCP (done once per project)

```powershell
**Prefer the Console** (Repositories → 2nd gen → `sona-github` → **Link repository**) and pick `devuplabs/speech-mvp` from GitHub so webhooks are registered. CLI-only create may not wire events:

```powershell
gcloud builds repositories list `
  --connection=sona-github --region=europe-west2 `
  --project=project-a625d19b-de99-48e9-9a9
```

You should see a row like `devuplabs-speech-mvp` (name is auto-generated; triggers must use that **exact** resource name, not `speech-mvp`).

## Create triggers

Triggers must specify **`sona-cloudbuild@PROJECT_ID.iam.gserviceaccount.com`** (full resource path). The setup script creates them via the Cloud Build REST API. Legacy `1055416779632@cloudbuild.gserviceaccount.com` does not exist in this project.

After repo access is configured:

**A. Script (recommended)**

```powershell
.\infra\scripts\setup-cloud-build.ps1 -SkipBootstrap
```

**B. Console**

1. [Cloud Build → Triggers](https://console.cloud.google.com/cloud-build/triggers;region=europe-west2?project=project-a625d19b-de99-48e9-9a9)
2. **Create trigger** → Repository: **speech-mvp** (2nd gen)
3. **Service account:** `sona-cloudbuild@project-a625d19b-de99-48e9-9a9.iam.gserviceaccount.com`
4. **Plan trigger:** Event = Pull request → `main`, Config = `infra/ci/cloudbuild.terraform.plan.yaml`
5. **Apply trigger:** Event = Push → `main`, Config = `infra/ci/cloudbuild.terraform.apply.yaml`, enable **Require approval**

## PR builds and `/gcbrun`

For the plan trigger, Cloud Build only runs on PRs from **forks/external contributors** unless a collaborator comments **`/gcbrun`** on the PR (default `COMMENTS_ENABLED`). As repo owner, comment `/gcbrun` on your PR to start the plan build.

If `/gcbrun` does nothing after ~1 minute, the **Google Cloud Build** GitHub App likely does not have access to `devuplabs/speech-mvp` (org-owned repo). Fix at:

- User install: https://github.com/settings/installations/134099335
- **Org install (preferred):** https://github.com/organizations/devuplabs/settings/installations → **Google Cloud Build** → add **speech-mvp**

Enable **Cloud Build data sharing** if status checks never appear: [Cloud Build → Settings → Data sharing](https://console.cloud.google.com/cloud-build/settings/data-sharing?project=project-a625d19b-de99-48e9-9a9).

## Connection region

Use **`europe-west2`** everywhere (connection, repositories, triggers). Do not use `global` for 2nd gen repos.
