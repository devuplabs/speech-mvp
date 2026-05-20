# Cloud Run (Sona API + worker)

Provisions:

- `sona-api-{env}` — public API (`SONA_MODE=api`), VPC connector, DB via private IP + Secret Manager password
- `sona-worker-{env}` — task handler (`SONA_MODE=worker`), invoked by Cloud Tasks OIDC
- API enqueues tasks with per-task URL + OIDC (`WORKER_SERVICE_URL` env); queue stays rate/retry only

First `terraform apply` uses `cloud_run_bootstrap_image` (public hello image) because `sona-api` is not in Artifact Registry yet. Run `infra/ci/cloudbuild.api.yaml` next to deploy the real image. Terraform ignores image tag changes after create.
