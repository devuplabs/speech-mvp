# Sona — GCP architecture & tech stack (HIPAA + UK)

**Document:** `architecture-gcp-hipaa.md`  
**Version:** 0.2 · 20 May 2026  
**Status:** Proposed — supersedes the “Neon / Vercel / multi-cloud sketch” in `mvp-brief.md` for teams standardising on Google Cloud.  
**Client stack:** Flutter + [GenUI](https://docs.flutter.dev/ai/genui) — see [`decisions/002-flutter-genui-client.md`](decisions/002-flutter-genui-client.md).  
**Doc review:** [`architecture-review-gcp-2026.md`](architecture-review-gcp-2026.md) (Google Developer Knowledge MCP, May 2026).

This document describes a **Google Cloud–centric** reference architecture for implementing the **Sona** MVP (intake → consult prep → triage → first-session plan → parent summary) as reflected in the [Figma design](https://www.figma.com/design/OBPcwy4hIS79EQYbK8URBM/Speech-Therapy-MVP-%E2%80%94-Intake---First-Session-Co-Pilot?node-id=0-1). It optimises for **responsive UI**, **clear separation of frontend / APIs / data**, and **regulated health-adjacent data** in both the **United States** and the **United Kingdom**.

---

## 1. Goals and non-goals

### 1.1 Goals

| Goal | Implication |
|------|-------------|
| **HIPAA alignment (US)** | Execute Google’s **Business Associate Agreement (BAA)**; use **only in-scope configurations** of [HIPAA-eligible Google Cloud services](https://cloud.google.com/security/compliance/hipaa) for PHI; documented safeguards (encryption, access control, audit, BAAs with subprocessors). |
| **UK / EU defensibility** | **UK GDPR**, **UK Data Protection Act 2018**, **Article 9** (special category — health) lawful basis, consent artefacts, DPIA, **UK/EU data residency** for UK tenants; subprocessors and SCCs where relevant. |
| **Performant parent + clinician UX** | Thin client, edge caching of static assets, fast API cold start profile, streaming LLM responses where useful, disciplined bundle size. |
| **Air-gapped LLM** | **Self-hosted** inference in tenant VPC only (ADR-003); single `LlmClient` implementation — no managed Vertex/OpenAI path in app code. |
| **Operational honesty** | “HIPAA compliant” is never a checkbox product feature; it is **organisational + technical** controls on top of eligible infrastructure. |

### 1.2 Non-goals (this document)

- Replacing legal counsel, a formal HIPAA security risk analysis, UK **DPIA**, or **NHS Data Security and Protection Toolkit (DSPT)** evidence packs.
- Prescribing every ADR (those live under `docs/decisions/` as numbered files).

---

## 2. Regulatory framing (short, actionable)

### 2.1 United States — HIPAA

- **Covered entity / BAA chain:** If you handle **PHI** on behalf of a covered clinician or clinic, you are typically a **business associate** (or need BAAs downstream). Google Cloud’s **BAA** covers **eligible services** only, in **eligible configurations** (e.g. **default encryption**, **no prohibited data flows** into non-eligible services without de-identification).
- **Shared responsibility:** Google secures the **cloud**; you secure **everything you build on it** (app auth, logging content, keys, prompts, exports, email bodies, admin access).
- **Practical rule:** Maintain an internal **“PHI may touch”** service list that is a **subset** of Google’s published HIPAA-eligible list, updated when Google updates the list.

### 2.2 United Kingdom — not “HIPAA equivalent,” but overlapping duties

UK law does not use the term HIPAA. For health-related personal data you typically care about:

| Topic | UK posture (high level) |
|-------|-------------------------|
| **Framework** | **UK GDPR** + **Data Protection Act 2018**; **Article 9** for special-category (health) data — explicit consent / employment, social protection, etc., as appropriate; document lawful basis. |
| **Accountability** | **DPIA** before live special-category processing; records of processing; **ICO** registration where required. |
| **International transfers** | If US services process UK personal data, ensure **UK GDPR transfer tools** (e.g. **IDTA / Addendum**) and **transfer risk assessment** as required. |
| **Clinical / sector norms** | **HCPC**, **RCSLT** professional standards; **NHS DSPT** if you later sell into NHS contexts (out of MVP scope per brief, but architecture should not block it). |

### 2.3 Serving **both** US and UK (v1 — **no global database**)

**Decision (ADR-001):** A **single global database** mixing US PHI and UK health data is **forbidden** in v1. Each jurisdiction gets its **own** Cloud SQL instance, GCS buckets, KMS keys, and (for production) **separate GCP project(s)**.

| Jurisdiction | Region (default) | Who lands here |
|--------------|------------------|----------------|
| **UK** | `europe-west2` (London) | UK/EU tenants; UK GDPR + pilot (Monal) |
| **US** | `us-central1` | US tenants; HIPAA + BAA |

**Routing:** At signup (or invite), each **tenant** is assigned immutable `jurisdiction = uk | us`. The API layer connects only to that jurisdiction’s data plane — no cross-jurisdiction SQL, backups, or analytics on raw clinical data.

**Marketing / docs site** may use a global CDN; **regulated payloads** never pass through a shared database.

See [`docs/decisions/001-data-residency-jurisdiction-stacks.md`](decisions/001-data-residency-jurisdiction-stacks.md) and [`infra/gcp-projects.yaml`](../infra/gcp-projects.yaml).

---

## 3. High-level architecture

**Two parallel stacks** (UK and US). Diagram shows one jurisdiction; the other is a **mirror** in its region.

```
                         ┌── Jurisdiction: UK (europe-west2) or US (us-central1) ──┐
                         │  One GCP project per (jurisdiction × environment)       │
                         ▼                                                       │
              ┌──────────────────────┐     ┌──────────────────────┐               │
              │ Flutter Web / mobile │     │ Sona API (Cloud Run) │               │
              │ (static / Firebase)  │────▶│ TypeScript · regional│               │
              └──────────────────────┘     └──────────┬───────────┘               │
                                                      │                           │
         ┌────────────────────────────────────────────┼───────────────┐           │
         ▼               ▼               ▼                ▼               ▼           │
  ┌─────────────┐ ┌─────────────┐ ┌──────────────┐ ┌──────────────┐ ┌─────────┐ │
  │ Cloud SQL   │ │ GCS exports │ │ vLLM + Gemma3│ │ Cloud Tasks  │ │ Worker  │ │
  │ PostgreSQL  │ │ (CMEK)      │ │ 27B (GKE/GPU)│ │ (same region)│ │ (Run)   │ │
  │ **UK-only   │ │ **no US     │ │ (same region)│ │              │ │ PDF/LLM │ │
  │  or US-only │ │  PHI here** │ │              │ │              │ │         │ │
  └─────────────┘ └─────────────┘ └──────────────┘ └──────────────┘ └─────────┘ │
                         └───────────────────────────────────────────────────────┘

              ┌── Other jurisdiction = separate diagram (separate project + SQL) ──┐
```

**Flow summary**

1. **Parents** (Flutter mobile/web) and **clinicians** (Flutter web) call the **Sona API** on **regional Cloud Run** (TLS 1.2+). Flutter web assets are served from **Firebase Hosting** or **GCS + Cloud CDN** (no PHI in static bundles).
2. **API** resolves **tenant → jurisdiction → DSN**; queries are scoped to that jurisdiction’s **Cloud SQL** and **GCS** only.
3. **GenUI (A2UI)** streams structured UI from the **Sona API**; the API calls **self-hosted inference** on private GKE/GCE (ADR-003) — no client LLM keys, no managed Vertex API for prompts.
4. **Long LLM jobs** (prep brief, plan draft) use **Cloud Tasks** → worker Cloud Run service; UI shows *Drafting → Ready* per Figma.
5. **Secrets** and **CMEK** are **per jurisdiction / per project**, not shared across UK and US.

---

## 4. Component choices (GCP)

### 4.1 Client — Flutter + GenUI

| Layer | Choice | Rationale |
|-------|--------|-----------|
| **Framework** | **Flutter** (Dart) — one codebase for parent mobile/web + clinician web | Matches Figma breakpoints (375 mobile, 1440 desktop); strong performance on parent mobile flow. |
| **Generative UI** | **[GenUI](https://docs.flutter.dev/ai/genui)** (`genui` package, alpha) | AI-drafted panels (probe areas, session plan sections, summary blocks) as **constrained widgets** from a Sona catalog — not free-form HTML. |
| **AI transport** | **`genui_a2a` / A2UI** → **Sona API** (all environments) | Same stack for demo and prod (ADR-004); PHI never on device; inference air-gapped (ADR-003). |
| **Hosting (web)** | **Firebase Hosting** or **GCS + Cloud CDN** after `flutter build web` | Per [Flutter web deployment](https://docs.flutter.dev/deployment/web). Separate from API Cloud Run service. |
| **Hosting (mobile)** | iOS / Android store builds (post-pilot) | Out of v0.1 submission scope; web covers pilot. |
| **Auth surfaces** | Parent: **signed, time-limited magic links** (deep link into Flutter). Clinician: **WebAuthn / passkeys** + optional TOTP; **Identity Platform** or API-issued sessions. |
| **Design system** | Figma tokens → Flutter `ThemeData` + shared widgets under `apps/sona/` | `#2D6A6E`, `#F2A878`, etc. from `mvp-brief.md`. |

**Note:** Marketing pages may use **Cloud Storage + Cloud CDN** globally; regulated flows stay on jurisdiction-scoped API + data plane.

### 4.2 APIs

| Concern | Choice |
|---------|--------|
| **Style** | **REST + JSON** (OpenAPI documented) for mobile-friendly, cache-friendly parent flows; optional **SSE** for streaming LLM to clinician UI. |
| **Runtime** | **Node.js 22 LTS** or **Bun** (only if team commits to support) on **Cloud Run** — **minimum instances ≥ 1** in pilot for predictable latency. |
| **Framework** | **Hono** or **Fastify** on **Cloud Run** (standalone service — not embedded in Flutter) | Clean boundary for OpenAPI → Dart client codegen; independent scale from static Flutter web. |
| **Validation** | **Zod** (or equivalent) at all ingress boundaries. |
| **AuthZ** | Row-level **tenant_id** + **clinician_id** + **jurisdiction** on every query; no cross-jurisdiction or “implicit global” queries. |

### 4.3 Database

| Concern | Choice |
|---------|--------|
| **Topology** | **One Cloud SQL instance per jurisdiction per environment** — never one shared instance for UK + US. |
| **Engine** | **Cloud SQL for PostgreSQL** — **regional HA** in pilot; **Point-in-Time Recovery** enabled. |
| **ORM / migrations** | **Drizzle** (as per brief) or **Prisma** — pick one and enforce migration review. |
| **Sensitive fields** | **Application-layer encryption** for highest-risk columns (parent/child identifiers, free-text) with keys in **Cloud KMS**; plus **database-level encryption at rest** (default). |
| **Audit** | Append-only **`audit_log`** table + **Cloud Audit Logs** for admin/data access; **7-year retention** policy aligned with clinical records practice (confirm with counsel). |

**Firestore / Spanner:** Useful at scale, but **Cloud SQL** is the simplest **HIPAA-eligible** default for relational MVP data with strong SQL reporting.

### 4.4 Object storage and documents

| Concern | Choice |
|---------|--------|
| **PDFs / exports** | **Cloud Storage** bucket per environment, **uniform bucket-level access**, **CMEK**, **versioning** optional; **signed URLs** with short TTL for clinician download. |
| **Virus scan** (if uploads allowed later) | Add **Cloud Run** + ClamAV or a commercial scanning API **with BAA** before MVP if accepting files. |

### 4.5 Async work and integrations

| Concern | Choice |
|---------|--------|
| **Queues** | **Cloud Tasks** for HTTP-push retries (simplest); **Pub/Sub** if multiple subscribers or fan-out. Both are common choices under Google’s **BAA** when used for PHI-adjacent workflows — **confirm current eligible list** before production. |
| **Email** | **Mailgun / SendGrid / SES** — for **non-PHI** transactional mail (e.g. clinician invites). Any PHI-bearing mail requires a vendor with a **BAA** (US) and appropriate **UK GDPR DPA** (UK), **regional** configuration, and **no PHI in provider dashboards** (templates + variables only). Mailgun (Sinch) is the current transactional provider; confirm DPA/BAA before sending PHI. |
| **Observability** | **Cloud Logging / Cloud Monitoring / Error Reporting**; **PII redaction** in log pipelines; **Sentry** (or similar) only with **server-side scrubbing** and BAA. |

### 4.6 LLM — self-hosted air-gap (ADR-003)

**Decision:** **One** `LlmClient` → **self-hosted [Gemma 3 27B IT](https://huggingface.co/google/gemma-3-27b-it)** (`google/gemma-3-27b-it`) via **vLLM** on **GKE + GPU** in the tenant region. **No** managed Vertex/OpenAI calls from Sona API for client data.

| Control | Implementation |
|---------|----------------|
| **Placement** | Same VPC as Cloud SQL (`europe-west2` / `us-central1`) |
| **Egress** | Deny internet from inference subnet; weights in **GCS (CMEK)** |
| **Callers** | Sona API + Cloud Tasks workers → **private** inference URL |
| **Perimeter** | VPC firewall; optional **VPC Service Controls** on prod |
| **Demo vs prod** | **Same** topology and code; dev uses synthetic data only (ADR-004) |

**Async:** Cloud Tasks → worker → same internal inference endpoint; UI shows *Drafting → Ready* per Figma.

**Not in scope for Sona v0.1:** Vertex Gemini API, Firebase AI Logic, third-party LLM APIs. (`speech-train` Whisper on Vertex remains a separate repo for future ASR.)

---

## 5. Security, privacy, and compliance controls

### 5.1 Identity and access

- **Google Cloud IAM:** least privilege; **break-glass** accounts documented; **MFA** enforced for all humans with production access.
- **VPC:** Serverless VPC connector from **Cloud Run** to **Cloud SQL private IP** (no public SQL).
- **Organization policies:** constrain **data residency**, **CMEK**, **domain restricted sharing** on buckets.
- **Cloud Armor** (optional pilot+): WAF + rate limits on magic-link endpoints.

### 5.2 Encryption

- **In transit:** TLS everywhere; **HSTS**; restrict cipher suites via load balancer / runtimes.
- **At rest:** Cloud SQL and GCS default encryption + **CMEK** for regulated buckets and backups where required.
- **Key management:** **Cloud KMS**; automatic key rotation where supported.

### 5.3 Logging and audit

- **Cloud Audit Logs** for infrastructure changes.
- **Application audit:** who opened which case, who exported PDF, who sent parent email — stored in **append-only** tables.
- **Log redaction:** structured logs with **field allowlists**; never log full intake payloads.

### 5.4 Data subject rights (UK GDPR)

- Implement **DSAR export** and **erasure** with **cryptographic erasure** strategy for backups (document retention vs. “right to erasure” tension with legal hold — **legal review required**).

### 5.5 HIPAA “eligible services only” discipline

Maintain a **living internal matrix**:

| Service | PHI allowed? | Notes |
|---------|----------------|-------|
| Cloud Run (API + workers) | Yes (if in BAA scope) | Min instances for API latency; separate service for async LLM/PDF workers. |
| Firebase Hosting (Flutter web) | **Confirm** | Static assets only; PHI flows API-only. |
| Cloud SQL | Yes | Private IP, backups encrypted, IAM DB auth optional. |
| Cloud Storage | Yes | Bucket policies, no public ACLs. |
| GKE / GCE (inference) | Yes (if in BAA scope) | GPU nodes private; no prompt egress; separate from managed Vertex API. |
| BigQuery | Often for analytics | **Do not** stream raw PHI into analytics until assessed. |
| Firebase (various) | Mixed | Many teams use **Identity Platform**; verify **each** Firebase product’s HIPAA eligibility before use with PHI. |

---

## 6. Environments and delivery

| Axis | Values | Notes |
|------|--------|--------|
| **Jurisdiction** | `uk`, `us` | Separate Cloud SQL + projects; see ADR-001. |
| **Environment** | `dev`, `stage`, `prod` | Within each jurisdiction. |

Example GCP projects: `sona-uk-dev` (pilot), `sona-us-dev` (when US work starts), then `*-stage`, `*-prod` per jurisdiction.

**Environment parity (ADR-004):** Dev, stage, and prod run the **same** services (Flutter → API → private inference → SQL). Only **data** (synthetic vs PHI) and **IAM** (engineers on dev, not on prod) differ.

**CI/CD:** **GitHub** + **Cloud Build** **per jurisdiction × environment** (e.g. trigger for `uk/dev` only) — [`infra/ci/cloud-build-terraform.md`](../infra/ci/cloud-build-terraform.md).

**IaC:** Terraform roots at `infra/terraform/environments/{uk|us}/{dev|stage|prod}` — [`infra/`](../infra/README.md), [`infra/gcp-projects.yaml`](../infra/gcp-projects.yaml).

---

## 7. Tech stack summary (implementation)

| Area | Stack |
|------|--------|
| **UI** | **Flutter** + **GenUI**; Figma design tokens in `ThemeData` |
| **API** | TypeScript, Hono or Fastify on Cloud Run, Zod, OpenAPI → Dart client |
| **DB** | PostgreSQL (Cloud SQL), Drizzle (or Prisma), migrations in CI |
| **Cache / rate limit** | Memorystore (Redis) — **no PHI** in cache; session IDs and ephemeral tokens only |
| **PDF** | **Cloud Run worker** (HTML→PDF or headless Chromium) or Dart `pdf` in worker |
| **Infra** | Terraform, Cloud Run (API/worker), GKE/GCE inference, Flutter web CDN, Secret Manager, KMS |
| **Observability** | Cloud Logging + Monitoring; optional Sentry with scrubbing |

---

## 8. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| **Accidental use of non-BAA service** | Terraform modules **whitelist** resources; code review checklist. |
| **Cross-border transfers** | **Hard tenant→jurisdiction** mapping; **separate Cloud SQL per jurisdiction** (ADR-001); no shared DB. |
| **LLM leakage in logs** | Hash prompts; store only clinician-approved final text in DB; redact monitoring. |
| **Magic-link abuse** | Short TTL, single-use tokens, rate limits, anomaly alerts. |
| **Vendor concentration** | `LlmClient` abstraction + documented fallback (e.g. second region or degraded non-AI mode). |

---

## 9. Relationship to existing brief

- **`mvp-brief.md`** product scope, Figma frames, and **design system** remain authoritative for **what** to build.
- **This document** is the default **where and how** to host on **GCP** when the organisation chooses Google as the primary cloud.
- Conflicts (e.g. “Neon + Vercel” vs “Cloud SQL + Cloud Run”) should be resolved by new **ADRs** under `docs/decisions/`, not by silent drift.

---

## 10. Next steps (before writing production PHI)

1. Execute **Google Cloud BAA** and capture **eligible services** snapshot date.  
2. Complete **DPIA** (UK) and **HIPAA security risk analysis** (US).  
3. ~~Fix tenant residency model~~ — **Done:** ADR-001 + jurisdiction Terraform roots (`uk/`, `us/`).  
4. ~~Lock LLM provider~~ — **Done:** ADR-003 self-hosted air-gap; add GKE/GPU Terraform in `uk/dev`.  
5. Enforce **ADR-004** prod IAM (no standing developer access on prod projects).  
6. Pen-test scope for **pilot go-live** (`mvp-brief.md` already calls for pre-scale pen test).

---

## References (external)

- [Google Cloud HIPAA compliance overview](https://cloud.google.com/security/compliance/hipaa)  
- [Google Cloud regions](https://cloud.google.com/about/locations)  
- [ICO guide to UK GDPR](https://ico.org.uk/for-organisations/guide-to-data-protection/guide-to-the-general-data-protection-regulation-gdpr/)  

---

_End of document._
