# Sona — Subprocessors

**Last updated:** 2026-06-15 · **Owner:** Data Protection lead (practice admin)

Sona ("the operator") engages a small set of third-party processors ("subprocessors") to
deliver the service. This is the published-style list referenced by the
[DPIA](dpia-v1.md) (§2.5) and the mvp-brief privacy stack. It is updated whenever a
subprocessor is added, removed, or its role changes.

**Controller / processor roles.** For patient data the **SLT practice (design partner) is the
data controller**; the Sona operator processes on the controller's behalf; the vendors below
are **subprocessors**. (If controllership is determined to be joint, that is documented in the
controller arrangement — see DPIA §6.) The controller must positively accept each subprocessor
below before real family data is processed.

**Hard rules that constrain this list**
- **UK data residency** — UK tenants' data stays in `europe-west2` / EU; no cross-jurisdiction
  processing (ADR-001).
- **No PHI by email** — email is notification-only, permanently; clinical content lives only in
  the authenticated portal (ADR-005).
- **No model training on our data** — required of any AI provider (ADR-007).
- **No subprocessor receives PHI** without a signed BAA/DPA **and** a backing ADR.

| # | Subprocessor | Purpose | Data processed | Region | International transfer | DPA / BAA status |
|---|---|---|---|---|---|---|
| 1 | **Google Cloud Platform** (Cloud SQL, Cloud Run, Cloud Storage, Cloud Tasks, Secret Manager, Cloud Logging) | Core infrastructure & hosting | **All PHI** at rest and in transit (intake, drafts, audit), credentials (Secret Manager). PHI-free logs only in Cloud Logging | `europe-west2` (London) | None for storage (region-pinned). SCCs/UK IDTA to cover any support/key-access transfer — **to confirm** | Google Cloud **DPA + HIPAA BAA** — **execution = TODO (human)**; CMEK + VPC-SC applied |
| 2 | **Google Cloud — Vertex AI (Gemini)** | AI inference **processor** — drafts prep brief, session plan, parent summary, clinical report | **Data-minimised clinical prompts** (PHI with direct identifiers stripped/pseudonymised per DEV-53) + model responses | `europe-west2` | As GCP above (SCCs/UK IDTA for residual) — **to confirm** | Enterprise Vertex only; **no-training**, **Zero Data Retention** (confirm enabled), PSC + VPC-SC, CMEK, covered by GCP DPA/BAA. **Not yet fully live — go-live gate (DEV-52)** |
| 3 | **Mailgun (Sinch)** | Transactional email — **notification-only** (clinician invites, "a summary/report is ready" + sign-in link) | **Metadata only**: recipient email address, send timing, message subject/notification text. **Never PHI / clinical content** | EU sending region preferred — **confirm** | EU region preferred; SCCs if US processing involved — **to confirm** | DPA preferred for metadata (DEV-51 scope). **Active** integration; email is notification-only by hard design (ADR-005) |
| 4 | **Zoom** | Tele-therapy video for the out-of-band 20-minute free consult | Live audio/video of the consult between clinician and family. **Not captured, stored, or transcribed by Sona** | EU data residency — **to confirm** | EU residency + SCCs as applicable — **to confirm** | **Planned.** Unlisted OAuth app. **Zoom DPA = TODO (DEV-51, human)** before real consults |
| 5 | **Identity provider** — **Firebase Auth / Identity Platform** (current) / **Auth0** (planned, DEV-30) | Clinician / practice-admin authentication | Clinician account identity (email, auth state). **No patient PHI** | EU/UK — **confirm** | Per provider; SCCs as applicable | Firebase/Identity Platform covered by GCP DPA (active). If **Auth0** is adopted (DEV-30), a **separate Auth0 DPA is required** before it handles real clinician accounts |

## Notes & honesty flags

- **Vertex is the headline residual risk.** Google processes children's (minimised) PHI as our
  processor — not air-gapped. This is the knowing trade-off accepted in ADR-007 for pilot-scale
  cost/speed; the self-hosted air-gap (ADR-003) remains the documented fallback for any customer
  who contractually requires it. Disclosed in the DPIA (risk R1) and here.
- **Identity provider discrepancy.** The repo currently provisions Firebase Auth / Identity
  Platform, while DEV-30 tracks a *planned* Auth0 adoption. Whichever ships, its DPA must be in
  place before it handles real accounts. The controller decides (DPIA §7, item 6/9).
- **"To confirm" entries are deliberate.** Region and transfer-mechanism confirmations for
  Mailgun, Zoom, and the identity provider are open items a human must close before go-live;
  they are not assumed.

## Change log

| Date | Change |
|---|---|
| 2026-06-15 | Initial published list created for DEV-32 (DPIA). Vendors: GCP, Vertex AI, Mailgun, Zoom (planned), identity provider. |

## References

- [DPIA v1](dpia-v1.md) · [DSAR runbook](dsar-runbook.md) · [Audit retention](audit-retention.md)
- ADR-001 (residency) · ADR-005 (portal-first comms) · ADR-007 (Vertex inference)
- [`docs/integrations/README.md`](../integrations/README.md) — integration runbooks & wiring
