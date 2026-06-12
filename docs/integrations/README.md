# External integrations

Sona relies on a small set of **external SaaS providers**. Each has its own runbook
here covering account setup, where the configuration lives, verification, secret
rotation, and ownership.

> **Most of this is managed _outside_ this repo.** The provider account, DNS, and
> credentials live in the provider console / your DNS / Secret Manager. This repo holds
> only the **wiring** — Terraform variables + the env vars the services read. Each
> runbook is the bridge between the two.

## Index

| Integration | Purpose | Status | Runbook | Wiring in repo |
|---|---|---|---|---|
| **Mailgun (Sinch)** | Transactional email — **notification-only** (invites, "report ready"); never PHI | **Active** | [`mailgun.md`](./mailgun.md) | `infra/terraform` (`mailgun_*` vars) · `MAILGUN_*` env · `apps/api/src/services/mailgun.ts` |
| Zoom / Google Meet | Tele-therapy / video sessions | Planned | _todo_ | — |
| Google / Microsoft Calendar | Appointment scheduling | Planned | _todo_ | — |

Identity (Firebase Auth / Identity Platform) is provisioned fully in Terraform and
documented under [`infra/terraform/modules/firebase_auth`](../../infra/terraform/modules/firebase_auth/README.md), so it is not duplicated here.

## Adding a new integration

1. Copy [`_template.md`](./_template.md) to `docs/integrations/<provider>.md` and fill it in.
2. Add a row to the **Index** table above (status: Planned → Active when wired).
3. Keep the same section order across runbooks so they're predictable to scan.
4. Put repo wiring (Terraform vars, env, Secret Manager) under `infra/terraform`; never
   commit provider credentials — supply them at apply via `TF_VAR_*` or add a Secret
   Manager version out of band.

## Conventions

- **Secrets** are referenced by Cloud Run via Secret Manager (`secret_key_ref`), created
  by Terraform when a value is supplied. Values are never committed.
- **Data residency:** prefer the provider's **EU** region/endpoint for UK tenants.
- **PHI:** no external provider receives PHI/clinical content unless covered by a signed
  BAA/DPA **and** an ADR. Email specifically is notification-only by design (see
  [`docs/decisions/005-portal-first-patient-communications.md`](../decisions/005-portal-first-patient-communications.md)).
