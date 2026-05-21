# Cloud Run (Sona API + worker + web)

Provisions:

- `sona-api-{env}` — public API (`SONA_MODE=api`), VPC connector, DB via private IP + Secret Manager password
- `sona-worker-{env}` — task handler (`SONA_MODE=worker`), invoked by Cloud Tasks OIDC
- `sona-web-{env}` — public Flutter web (static nginx), no VPC/DB
- API `CORS_ORIGINS` is set to the web service URI when `enable_web` is true (browser calls from hosted UI)
- API enqueues tasks with per-task URL + OIDC (`WORKER_SERVICE_URL` env); queue stays rate/retry only

First `terraform apply` uses bootstrap images (`cloud_run_bootstrap_image` / `web_bootstrap_image`) because `sona-api` / `sona-web` may not be in Artifact Registry yet. Run Cloud Build triggers **sona-api-dev-deploy** and **sona-web-dev-deploy** after merge to `main`. Terraform ignores image tag changes after create.

**Adopting an existing `sona-web-dev` service** (created before this module): one-time import in `uk/dev`:

```bash
terraform import 'module.stack.module.cloud_run.google_cloud_run_v2_service.web[0]' \
  projects/PROJECT_ID/locations/REGION/services/sona-web-dev
```

Then `terraform apply` aligns IAM, env on API (`CORS_ORIGINS`), and metadata without replacing the service URL.
