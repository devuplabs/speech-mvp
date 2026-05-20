# Cloud Run (Sona API + worker)

Provisions:

- `sona-api-{env}` — public API (`SONA_MODE=api`), VPC connector, DB via private IP + Secret Manager password
- `sona-worker-{env}` — task handler (`SONA_MODE=worker`), invoked by Cloud Tasks OIDC
- Cloud Tasks queue HTTP target → `POST /internal/tasks/llm-prep`

Image updates are done by `infra/ci/cloudbuild.api.yaml` (Terraform ignores image tag changes).
