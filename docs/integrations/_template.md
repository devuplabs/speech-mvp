<!-- Copy to docs/integrations/<provider>.md and fill in. Keep the section order. -->

# <Provider> integration

**Purpose:** <what it does for Sona>
**Status:** Planned | Active
**Owner:** <team / person who holds the account>
**Managed outside repo:** <provider console, DNS, billing — what lives where>

## 1. Overview

One paragraph: what this provider does, the design constraints (e.g. data
residency, PHI rules), and which Sona services use it.

## 2. Account setup (provider console — outside this repo)

Step-by-step to stand up the account/app: org, domain/app registration, DNS,
region selection, scopes/keys to copy. Note anything that needs DNS or billing.

## 3. Configuration in this repo (wiring)

| What | Where | Notes |
|---|---|---|
| Terraform vars | `infra/terraform/environments/<jur>/<env>` | … |
| Secret(s) | Secret Manager `…` (created by Terraform) | value supplied at apply |
| Service env vars | `<SERVICE>_*` consumed in `apps/…` | … |
| Code | `apps/…` | … |

## 4. Secrets & rotation

How the credential is supplied (`TF_VAR_…` at apply / `gcloud secrets versions add`),
and how to rotate it (issue new in console → update version → apply; Cloud Run reads
`version = "latest"`).

## 5. Verification

How to confirm it works (health endpoint, smoke test, expected response).

## 6. Troubleshooting

Common failures and fixes (auth errors, region mismatch, unverified domain, missing
config → graceful no-op, etc.).

## 7. Compliance notes

PHI handling, BAA/DPA status, residency, links to the relevant ADR.
