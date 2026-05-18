# ADR 001 — Data residency: separate stacks per jurisdiction (no global database)

**Status:** Accepted  
**Date:** 2026-05-18

## Context

Sona targets **UK** and **US** markets. UK health-related personal data (UK GDPR Art. 9) and US PHI (HIPAA) must not share a single database, backup set, or incident-response boundary.

## Decision

**v1 uses physically separate data planes per jurisdiction:**

| Jurisdiction | Default region | GCP layout |
|--------------|----------------|------------|
| **UK** | `europe-west2` | One **Cloud SQL** instance per **GCP project**; UK tenants only |
| **US** | `us-central1` | Separate **GCP project(s)** and **Cloud SQL**; US tenants only |

Dimensions:

1. **Jurisdiction** (`uk` | `us`) — determines region, DPA/BAA posture, and which Cloud SQL instance a tenant uses.
2. **Environment** (`dev` | `stage` | `prod`) — lifecycle within that jurisdiction.

Terraform roots: `infra/terraform/environments/{uk|us}/{dev|stage|prod}`.

Application rules (when built):

- Every **tenant** has immutable `jurisdiction` (`uk` or `us`).
- API and workers resolve **DB connection from jurisdiction** (no runtime “pick any region”).
- **No cross-jurisdiction queries**, replication, or shared analytics on raw clinical payloads.

## Consequences

- **More GCP projects** than a single global stack (e.g. `sona-uk-dev`, `sona-us-dev`, …).
- **Duplicate Terraform applies** per jurisdiction (separate Cloud Build triggers).
- **Pilot (Monal / UK)** uses **UK stack only**; US stack can stay unprovisioned until needed.

## Not in scope

- Multi-region active-active within one jurisdiction (future).
- Cross-border “follow the user” routing (forbidden for v1).

## References

- [`docs/architecture-gcp-hipaa.md`](../architecture-gcp-hipaa.md) §2.3, §3
- [`infra/gcp-projects.yaml`](../../infra/gcp-projects.yaml)
