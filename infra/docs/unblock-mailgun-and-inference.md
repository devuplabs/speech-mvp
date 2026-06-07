# Unblock: Mailgun email + Phase 2 inference (this week)

Monal co-design and DPIA sign-off are **deferred to next week**. This runbook covers the two items you can unblock now.

**GCP project:** `project-a625d19b-de99-48e9-9a9`  
**Region:** `europe-west2` · GPU zone: `europe-west2-b`  
**Models bucket:** `project-a625d19b-de99-48e9-9a9-sona-models-uk-dev`

Work **Mailgun first** (same day), then **GPU/inference** (quota + upload can run in parallel).

> Email today is the **clinician invite** only (set-password link — no patient data / PHI). Parent-summary delivery stays portal-first per `docs/decisions/005-portal-first-patient-communications.md`. Confirm a **DPA/BAA** with Mailgun (Sinch) before sending anything containing PHI.

---

## A — Mailgun (transactional email)

### A1. Mailgun account + sending domain

1. [Mailgun](https://www.mailgun.com) (Sinch) → add a **sending domain** (e.g. `mg.yourdomain.com`).
2. Choose the **region** that matches your data-residency needs — **EU** (`api.eu.mailgun.net`) for UK/EU.
3. Add the DNS records Mailgun shows (SPF/TXT, DKIM, and the tracking CNAME); wait for the domain to go **Verified / Active**.
4. Copy the **API key** (Sending API key) — keep it offline until A3.

### A2. Set domain / from / region in tfvars

In `infra/terraform/environments/uk/dev/terraform.tfvars` (gitignored):

```hcl
mailgun_domain     = "mg.YOUR-VERIFIED-DOMAIN"
mailgun_from_email = "no-reply@YOUR-VERIFIED-DOMAIN"
mailgun_base_url   = "https://api.eu.mailgun.net" # omit for US
```

### A3. Supply the API key at apply (never Notion / chat / git)

The key is passed as a **sensitive Terraform variable** at apply time; Terraform then
creates the Secret Manager secret `sona-mailgun-api-key-dev`, stores the value, grants
the runtime service account access, and wires `MAILGUN_API_KEY` into the API service.

```powershell
$env:TF_VAR_mailgun_api_key = Read-Host "Mailgun API key" -AsSecureString | ConvertFrom-SecureString -AsPlainText
# then run the approved sona-terraform-dev-apply (or local: terraform apply)
```

For the CI apply trigger, store the key as a Cloud Build / Secret Manager secret and
expose it as `TF_VAR_mailgun_api_key` for the apply step — do not put it in a committed
tfvars file.

With `mailgun_api_key` empty, no secret is created and email stays disabled (the app
still works; invites just don't send).

### A4. Deploy API + smoke test

Push `apps/api/**` to `main` → **sona-api-dev-deploy** runs automatically.

```powershell
$API = "https://sona-api-dev-3rhenudy6a-nw.a.run.app"
curl "$API/health"   # email: "configured"
```

Then create a practice and invite a clinician (or hit the invite endpoint); the invited
address should receive the set-password email. Reply here with: domain verified ✓,
apply done ✓, **From address** (not the key).

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
| Mailgun domain verified | ☐ | |
| `TF_VAR_mailgun_api_key` set + apply | ☐ | Creates `sona-mailgun-api-key-dev` |
| `mailgun_domain` / `mailgun_from_email` in tfvars + apply | ☐ | Deploy API route |
| L4 quota requested/approved | ☐ | |
| vLLM image mirrored | ☐ | |
| Gemma weights in GCS | ☐ | |
| `inference_enabled=true` + approved apply | ☐ | Enable real LLM prep |
