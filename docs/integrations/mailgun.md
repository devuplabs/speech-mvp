# Mailgun integration

**Purpose:** Transactional email — **notification-only** (clinician invites today; "your
report is ready" alerts later).
**Status:** Active (wiring merged; activate per environment by supplying the API key).
**Owner:** Sona platform team (holds the Mailgun/Sinch account + DNS).
**Managed outside repo:** Mailgun account, sending domain + DNS records, and the API key
live in the Mailgun console / your DNS / Secret Manager. This repo only wires the env.

## 1. Overview

Mailgun (a Sinch product) sends Sona's transactional email over its HTTPS API (no SMTP —
Cloud Run blocks outbound SMTP). It is called from `apps/api/src/services/mailgun.ts` via
the provider-agnostic `email.ts`.

**Design rule — no PHI, ever.** Email is notification-only and never carries clinical
content, regardless of any BAA/DPA. Clinical content is rendered only in the
authenticated portal (see [ADR-005](../decisions/005-portal-first-patient-communications.md)).
A BAA/DPA is preferred for email **metadata** (recipient, timing) but is never a gate to
emailing content — that simply doesn't happen.

## 2. Account setup (Mailgun console — outside this repo)

1. **Account:** create / use the team Mailgun (Sinch) account.
2. **Region:** choose **EU** for UK/EU tenants (data residency). The EU API base is
   `https://api.eu.mailgun.net`; US is `https://api.mailgun.net` (the default).
3. **Sending domain:** add a subdomain, e.g. `mg.yourdomain.com` (a subdomain keeps the
   root domain's reputation separate).
4. **DNS:** add the records Mailgun shows — **SPF** (TXT), **DKIM** (TXT), the
   **tracking CNAME**, and MX records if you want inbound/receipts. Wait for the domain
   to show **Verified / Active**.
5. **API key:** copy the **Sending API key** (Mailgun → Send → API keys). This is the
   secret consumed below — keep it offline until apply.

## 3. Configuration in this repo (wiring)

| What | Where | Notes |
|---|---|---|
| Terraform vars | `infra/terraform/environments/<jur>/<env>` (e.g. `uk/dev`) | `mailgun_api_key` (sensitive), `mailgun_domain`, `mailgun_from_email`, `mailgun_base_url` |
| Secret | Secret Manager `sona-mailgun-api-key-<env>` | created by the `sona_environment` module **only when** `mailgun_api_key` is supplied; runtime SA granted `secretAccessor` |
| Service env | API Cloud Run: `MAILGUN_API_KEY` (`secret_key_ref`), `MAILGUN_DOMAIN`, `MAILGUN_FROM_EMAIL`, `MAILGUN_BASE_URL` | wired in `infra/terraform/modules/cloud_run` |
| Code | `apps/api/src/services/mailgun.ts` (adapter), `email.ts` (config + senders) | `getEmailConfig` reports `configured` only when key + domain + from are all set |

Non-secret config (`mailgun_domain`, `mailgun_from_email`, `mailgun_base_url`) goes in the
environment's gitignored `terraform.tfvars`:

```hcl
mailgun_domain     = "mg.yourdomain.com"
mailgun_from_email = "no-reply@yourdomain.com"
mailgun_base_url   = "https://api.eu.mailgun.net" # omit for US
```

## 4. Secrets & rotation

The API key is **never committed**. Supply it as a sensitive Terraform variable at apply;
Terraform creates the secret, stores the value, grants the runtime SA access, and wires
`MAILGUN_API_KEY` into Cloud Run:

```bash
export TF_VAR_mailgun_api_key='<mailgun-sending-api-key>'
# then run the approved sona-terraform-<env>-apply (or local: terraform apply)
```

For CI applies, store the key as a Cloud Build / Secret Manager secret and expose it as
`TF_VAR_mailgun_api_key` for the apply step only.

**Rotate:** issue a new Sending API key in Mailgun → re-run apply with the new
`TF_VAR_mailgun_api_key` (adds a new Secret Manager version) → revoke the old key in
Mailgun. Cloud Run reads `version = "latest"`, so the next revision picks it up.

With `mailgun_api_key` unset, no secret is created and email is disabled — the app still
works; invites just don't send (graceful no-op).

## 5. Verification

```bash
API="https://sona-api-<env>-….a.run.app"
curl "$API/health"      # email: "configured" once key + domain + from are set
```

Then create a practice and invite a clinician (or call the invite endpoint); the invited
address should receive the set-password email.

## 6. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `health` shows email not configured | one of key/domain/from missing | set all three (`MAILGUN_*`) and re-apply |
| `401`/`Forbidden` from Mailgun | wrong/rotated key, or **region mismatch** | verify the Sending API key; set `mailgun_base_url` to the region the domain lives in |
| Email never arrives, no error | domain not verified, or in Mailgun sandbox | finish DNS verification; use your verified domain, not the sandbox |
| Works in US, 401 in EU (or vice-versa) | base URL ≠ domain region | align `mailgun_base_url` with the domain's region |

## 7. Compliance notes

- **PHI:** none — email is notification-only by design (ADR-005). Do not add senders that
  put clinical content in an email body; the only senders in `email.ts` are
  notification-style (invite link).
- **Residency:** use the EU region/endpoint for UK tenants.
- **BAA/DPA:** preferred for metadata; confirm with Mailgun/Sinch. Not a prerequisite for
  the current invite email (no PHI).

## Related

- Operational this-week checklist: [`infra/docs/unblock-mailgun-and-inference.md`](../../infra/docs/unblock-mailgun-and-inference.md)
- Email design rule: [`apps/api/src/services/email.ts`](../../apps/api/src/services/email.ts)
- [ADR-005 — portal-first parent communications](../decisions/005-portal-first-patient-communications.md)
