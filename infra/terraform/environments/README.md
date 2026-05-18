# Environment stacks (jurisdiction × lifecycle)

Terraform is split by **jurisdiction** first, then **environment**. This enforces **no shared Cloud SQL** between UK and US data.

```
environments/
  uk/
    dev/      ← SONA-MVP-DEV (project-a625d19b-de99-48e9-9a9), europe-west2
    stage/
    prod/
  us/
    dev/      ← separate US GCP project, us-central1
    stage/
    prod/
```

Registry: [`../../gcp-projects.yaml`](../../gcp-projects.yaml) · ADR: [`../../../docs/decisions/001-data-residency-jurisdiction-stacks.md`](../../../docs/decisions/001-data-residency-jurisdiction-stacks.md)

## Commands

```bash
cd infra/terraform/environments/uk/dev
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
terraform init -backend-config-file=backend.hcl
terraform plan
```

Or: `infra/scripts/terraform-env.sh uk dev plan`

## Pilot

UK-only for v0.1 (Monal). Provision **`uk/dev`** only; leave **`us/*`** until a US GCP project exists.
