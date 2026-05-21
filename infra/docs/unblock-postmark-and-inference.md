# Unblock: Postmark + Phase 2 inference (this week)

Monal co-design and DPIA sign-off are **deferred to next week**. This runbook covers the two items you can unblock now.

**GCP project:** `project-a625d19b-de99-48e9-9a9`  
**Region:** `europe-west2` · GPU zone: `europe-west2-b`  
**Models bucket:** `project-a625d19b-de99-48e9-9a9-sona-models-uk-dev`

Work **Postmark first** (same day), then **GPU/inference** (quota + upload can run in parallel).

---

## A — Postmark (parent emails)

### A1. Postmark account

1. [Postmark](https://postmarkapp.com) → create **Server** (e.g. `Sona uk-dev`).
2. Copy the **Server API token** (keep offline until A4).

### A2. Verify sending domain

1. **Sender Signatures** → **Add Domain**.
2. Add DNS: DKIM, Return-Path, SPF as shown.
3. Wait for **Verified** in Postmark.

### A3. Terraform secret shell (if not applied yet)

Merge infra changes and run approved **sona-terraform-dev-apply** (or local apply). This creates Secret Manager secret `sona-postmark-api-token` (empty until you add a version).

### A4. Store token (never Notion / chat)

```powershell
$PROJECT = "project-a625d19b-de99-48e9-9a9"
$token = Read-Host "Postmark server API token"
$token | gcloud secrets versions add sona-postmark-api-token `
  --project=$PROJECT `
  --data-file=-
```

If the secret does not exist yet, use `gcloud secrets create` instead (see previous session notes).

### A5. Set From address

In `infra/terraform/environments/uk/dev/terraform.tfvars` (gitignored):

```hcl
postmark_from_email = "noreply@YOUR-VERIFIED-DOMAIN"
```

Re-apply Terraform (or approve apply trigger) so Cloud Run gets `POSTMARK_FROM_EMAIL` + `POSTMARK_API_TOKEN` from Secret Manager.

### A6. Deploy API + smoke test

Push `apps/api/**` to `main` → **sona-api-dev-deploy** runs automatically.

```powershell
$API = "https://sona-api-dev-3rhenudy6a-nw.a.run.app"
curl "$API/health"   # email: "configured"

# After a case exists with parentEmail:
curl -X POST "$API/v1/cases/CASE_ID/parent-summary/send" -H "Content-Type: application/json" -d "{}"
```

Reply here with: domain verified ✓, secret version added ✓, **From address** (not the token).

---

## B — Phase 2 inference (L4 + Gemma + vLLM)

### B1. Request L4 GPU quota

1. [GCP Console → IAM & Admin → Quotas](https://console.cloud.google.com/iam-admin/quotas?project=project-a625d19b-de99-48e9-9a9).
2. Filter: **NVIDIA L4 GPUs**, location **europe-west2-b** (or run `infra/scripts/check-gpu-quota.ps1`).
3. Request **≥ 1** GPU for dev.

Quota approval can take hours–days.

### B2. Mirror vLLM image to Artifact Registry

```powershell
.\infra\scripts\mirror-vllm-image.ps1
```

Target: `europe-west2-docker.pkg.dev/project-a625d19b-de99-48e9-9a9/sona-sona/vllm-openai:latest`

### B3. Upload Gemma weights to GCS

1. Accept license on Hugging Face: [`google/gemma-3-27b-it`](https://huggingface.co/google/gemma-3-27b-it).
2. **AWQ quantized** weights are recommended (smaller/faster).
3. Upload so the bucket prefix exists:

   `gs://project-a625d19b-de99-48e9-9a9-sona-models-uk-dev/gemma-3-27b-it/`

   Example (with `huggingface-cli` installed):

   ```powershell
   huggingface-cli download google/gemma-3-27b-it --local-dir ./gemma-3-27b-it
   gcloud storage cp -r ./gemma-3-27b-it/* gs://project-a625d19b-de99-48e9-9a9-sona-models-uk-dev/gemma-3-27b-it/
   ```

   Upload time depends on model size and bandwidth (AWQ ~tens of GB).

### B4. Enable inference in Terraform

In `terraform.tfvars`:

```hcl
inference_enabled     = true
inference_zone        = "europe-west2-b"
vllm_container_image  = "europe-west2-docker.pkg.dev/project-a625d19b-de99-48e9-9a9/sona-sona/vllm-openai:latest"
```

On the **sona-terraform-dev-apply** trigger, set substitution `_INFERENCE_ENABLED=true` (or update `setup-cloud-build.ps1` and refresh triggers).

Approve apply in Cloud Build. GKE + vLLM may take **15–25 minutes**. If `inference_vllm_openai_base_url` is empty after first apply, run apply again once the internal LB has an IP.

### B5. Verify

```powershell
terraform output inference_vllm_openai_base_url   # from uk/dev after apply
curl "$API/ready"   # inference check should become ok
```

Reply when: quota approved ✓, weights in GCS ✓, vLLM image pushed ✓ — we can flip apply and wire `INFERENCE_OPENAI_BASE_URL`.

---

## Checklist (reply as you go)

| Step | You | Us |
|------|-----|-----|
| Postmark domain verified | ☐ | |
| Secret `sona-postmark-api-token` version added | ☐ | |
| `postmark_from_email` in tfvars + apply | ☐ | Deploy API route |
| L4 quota requested/approved | ☐ | |
| vLLM image mirrored | ☐ | |
| Gemma weights in GCS | ☐ | |
| `inference_enabled=true` + approved apply | ☐ | Enable real LLM prep |
