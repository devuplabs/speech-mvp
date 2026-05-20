# Cloud Run (Sona API + worker)

Provisions:

- `sona-api-{env}` — public API (`SONA_MODE=api`), VPC connector, DB via private IP + Secret Manager password
- `sona-worker-{env}` — task handler (`SONA_MODE=worker`), invoked by Cloud Tasks OIDC
- Cloud Tasks HTTP target on existing queue (`cloud_tasks` module, after worker URI is known)

Image updates are done by `infra/ci/cloudbuild.api.yaml` (Terraform ignores image tag changes).
