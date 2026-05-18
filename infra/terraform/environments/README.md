# Environment stacks

Each subdirectory is a **standalone Terraform root** for one **GCP project**. Project ids are listed in [`../../gcp-projects.yaml`](../../gcp-projects.yaml).

| Directory | GCP project (current) |
|-----------|------------------------|
| `dev/` | `project-a625d19b-de99-48e9-9a9` (SONA-MVP-DEV) |
| `stage/` | Not created — update `gcp-projects.yaml` when ready |
| `prod/` | Not created — update `gcp-projects.yaml` when ready |

## Commands

From any environment directory (after copying `terraform.tfvars.example` → `terraform.tfvars` and `backend.hcl.example` → `backend.hcl`):

```bash
terraform init -backend-config-file=backend.hcl
terraform plan
terraform apply
```

Use a **different GCP `project_id` and state bucket** per directory so state and IAM never cross environments.

For **GitHub → Cloud Build** (plan on PR, apply with approval on `main`), see [`../../ci/cloud-build-terraform.md`](../../ci/cloud-build-terraform.md).
