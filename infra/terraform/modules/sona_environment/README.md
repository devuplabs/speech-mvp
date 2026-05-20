# Sona environment stack

Single Terraform module wired for every `environments/{uk|us}/{dev|stage|prod}` root. Same topology in all environments ([ADR-004](../../../../docs/decisions/004-unified-environments-access.md)).

## Modules composed

| Module | Purpose |
|--------|---------|
| `enable_apis` | GCP APIs including GKE + Cloud Tasks |
| `network` | VPC, PSA, Serverless VPC connector |
| `kms` | CMEK for GCS |
| `app_identity` | Cloud Run runtime SA |
| `artifact_registry` | Docker images (API, vLLM) |
| `storage` | Clinical exports bucket |
| `model_storage` | Gemma weights bucket |
| `cloud_sql` | PostgreSQL |
| `cloud_tasks` | Async LLM job queue |
| `inference` | GKE + vLLM (Gemma 3 27B) |

## Usage

Environment roots only pass variables:

```hcl
module "stack" {
  source = "../../../modules/sona_environment"
  # ...
}
```

See [`environments/uk/dev/terraform.tfvars.example`](../../environments/uk/dev/terraform.tfvars.example).
