# Cloud Build trigger templates

Templates for **2nd gen GitHub** triggers. Placeholders are substituted by `infra/scripts/setup-cloud-build.ps1` or `.sh`:

| Placeholder | Example (uk/dev) |
|-------------|-------------------|
| `REPLACE_PROJECT_ID` | `project-a625d19b-de99-48e9-9a9` |
| `REPLACE_CLOUD_BUILD_SA` | `projects/.../serviceAccounts/sona-cloudbuild@....iam.gserviceaccount.com` |
| `REPLACE_REPOSITORY_RESOURCE` | `projects/.../connections/sona-github/repositories/devuplabs-speech-mvp` |

Do not use legacy `PROJECT_NUMBER@cloudbuild.gserviceaccount.com` — it may not exist.

Create/update triggers with the setup script (REST API), not raw `gcloud builds triggers create github` without `serviceAccount`.

See [`../../BOOTSTRAP-MANUAL-STEPS.md`](../../BOOTSTRAP-MANUAL-STEPS.md) for human-only steps (OAuth, approvals, quotas).
