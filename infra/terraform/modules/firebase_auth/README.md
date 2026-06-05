# firebase_auth

Provisions **Firebase Authentication (Identity Platform)** for an environment —
entirely in Terraform, no console steps (Auth·01 / Feature 2).

## What it creates
- Enables `identitytoolkit.googleapis.com` and `firebase.googleapis.com`.
- `google_identity_platform_config` with **email/password** and passwordless
  **email-link (Magic Link)** sign-in (`password_required = false`).
- A Firebase **project** + **web app** registration (`google-beta`) so the
  Flutter client can initialise the SDK; the client config is exposed as
  outputs (`web_api_key`, `web_app_id`, `auth_domain`, `messaging_sender_id`).
- Grants the Cloud Run runtime SA `roles/firebaseauth.admin`.

## Secrets posture
There are **no secrets** to store. Backend token verification and invite-link
generation use **Application Default Credentials** (the runtime service
account) — no service-account JSON key. The Firebase Web API key is public
client config (shipped in the browser bundle), so it is a plain output, not a
Secret Manager entry. Genuine secrets elsewhere (e.g. the DB password) continue
to use the Secret Manager pattern in `modules/cloud_sql`.

## Providers
Requires both `google` and `google-beta`. The caller must configure a
`google-beta` provider and pass it through (see `environments/uk/dev`).

## Inputs
| Name | Description |
| --- | --- |
| `project_id` | GCP project id. |
| `runtime_service_account_email` | Cloud Run runtime SA (from `app_identity`). |
| `authorized_domains` | Domains allowed to complete sign-in / email-link. |
| `web_app_display_name` | Firebase Web App display name. |

## Wiring a new environment
1. Add the `google-beta` provider to the env `versions.tf` + a
   `provider "google-beta"` block in `main.tf`.
2. Call this module, passing `providers = { google, google-beta }`, the
   project id, and `module.stack.runtime_service_account_email`.
3. Surface the `firebase_*` outputs for the web build.

Currently wired in **uk/dev** (pilot). Stage/prod follow the same pattern once
the dev flow is validated.
