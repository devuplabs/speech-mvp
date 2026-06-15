# Go-live checklist — real family data gate

**Linear:** DEV-43 — Customer onboarding runbook & go-live checklist
**Companion:** [`practice-onboarding-runbook.md`](practice-onboarding-runbook.md)
**Authority:** the project "Go-Live Compliance Gate" + the DPIA open items
([`docs/compliance/dpia-v1.md`](../compliance/dpia-v1.md) §7) + ADR-007 mandatory safeguards.

> **The rule (DPIA §7).** Every item below MUST be true before **any real, consented
> family's data** is processed. **If any item is open, the answer to "can real family data
> flow?" is _no_.** Synthetic-only dry-runs (per the runbook) are fine before the gate; real
> data is not.
>
> Items marked **[HUMAN]** cannot be completed by an agent — they need a person with legal /
> repo-admin / infra / clinical authority (sign a contract, accept risk, toggle a repo
> setting, provision prod). An agent can prepare them but not close them.

**Status legend:** **DONE** · **OPEN** · **OPEN [HUMAN]**

---

## Summary — done vs open (today, 2026-06-15)

| Bucket | Count |
|---|---|
| **DONE** (proven in repo today) | **4** |
| **OPEN — engineering** (agent-closable) | **4** |
| **OPEN — [HUMAN]** (legal / infra / repo-admin / clinical) | **9** |
| **Total gates** | **17** |

**Verdict: NOT cleared for real family data.** 13 of 17 gates are open (9 of them require a
human). The four engineering items (live AI, Vertex safeguards code-side, prompt-minimisation
verification, auth gating) and all nine human items must close first. This is expected — the
product is built and dry-run-ready, but the compliance/infra/contract layer is deliberately
not self-certifiable by an agent.

---

## A. Data protection & lawful basis

| # | Gate | Status | Proving artifact | Notes |
|---|---|---|---|---|
| A1 | **DPIA signed** by Controller + DPO (+ clinical & eng leads) | **OPEN [HUMAN]** | DPIA §6 sign-off table (DEV-32) | The DPIA **draft is done** (DEV-32); the signatures are blank. An agent cannot accept risk for the controller. |
| A2 | **Lawful basis & Art. 9 condition confirmed + documented** (likely Art. 9(2)(h) + explicit parental consent); **parental-responsibility verification** agreed | **OPEN [HUMAN]** | DPIA §3.1, §7 item 2 (R11) | DPO/controller decision. |
| A3 | **Consent wording finalised + wired to `consent_version`**; privacy notice published | **OPEN [HUMAN]** | DEV-28; intake submit carries `consentVersion` (`POST /v1/cases/:caseId/intake`) | Placeholder wording is used in dry-runs; real data needs final, GDPR-grade wording. |
| A4 | **Contracts executed** — Google Cloud **DPA + BAA** (Vertex region/services), **Mailgun DPA** (metadata), **Zoom DPA**, identity-provider DPA | **OPEN [HUMAN]** | DPIA §2.5/§7 item 6; DEV-51 (Zoom + vendor DPAs); DEV-30 (identity) | Subprocessor list published ([subprocessors.md](../compliance/subprocessors.md)) marks all as "execution = TODO". |
| A5 | **International-transfer mechanism confirmed** — region-pin + SCCs / UK IDTA for any residual transfer | **OPEN [HUMAN]** | DPIA §7 item 7 (R10); ADR-007 §5 | e.g. provider support / CMEK key access. |
| A6 | **Subprocessor list published + accepted by controller** | **DONE** (published) / **OPEN [HUMAN]** (acceptance) | [`docs/compliance/subprocessors.md`](../compliance/subprocessors.md) (published 2026-06-15) | The **list is published** — that half is done. The **controller must positively accept** each subprocessor (esp. Google/Vertex processing children's PHI). Acceptance is the open human half (DPIA §7 item 8). |

---

## B. AI / Vertex inference (ADR-007)

| # | Gate | Status | Proving artifact | Notes |
|---|---|---|---|---|
| B1 | **Live AI wired** — drafts come from the real model, not stubs | **OPEN** | DEV-13; `apps/api/src/llm/chat.ts#isLlmConfigured` (false until `INFERENCE_OPENAI_BASE_URL` set); `generate-drafts.ts` returns `null` → stub | Today all AI drafts are **stubs**. Client targets an OpenAI-compatible endpoint (default `google/gemma-3-27b-it`), not yet Vertex. |
| B2 | **Vertex safeguards live** — enterprise Vertex on invoiced billing; no-training; **ZDR / abuse-logging exemption confirmed enabled** for the chosen Gemini model in `europe-west2` (incl. input cache); **PSC + VPC-SC**; **CMEK**; least-privilege SA | **OPEN [HUMAN]** | DEV-52; ADR-007 §1–6, §3 (confirm, not assume); DPIA §7 item 3 | Mix of infra + contract; needs human confirmation of ZDR/BAA scope. |
| B3 | **Prompt data-minimisation verified end-to-end** — `redact.ts` covers the live intake field set; spot-check no direct identifier reaches a prompt | **OPEN** | DEV-53; `apps/api/src/llm/redact.ts` (exists); DPIA §7 item 4 (R1, R5) | Code exists; the *verification against the live field set* is the open work, and only meaningful once B1 is wired. |
| B4 | **No PHI in inference logs / inference audited** — model/case/latency only, never content | **DONE** (logger) / re-verify with B1 | ADR-007 §8/§11; `apps/api/src/logger.ts` allowlist (DEV-23) | Allowlist logger is in place; re-confirm once live AI flows. |

---

## C. Security, auth & access control

| # | Gate | Status | Proving artifact | Notes |
|---|---|---|---|---|
| C1 | **Auth / RBAC on case routes** — case API gated; DSAR export → admin/clinician; erasure & legal-hold → admin-only | **OPEN** | DEV-31 (auth), DEV-30; `TODO(DEV-31/auth)`; auth scaffolding fails closed (`auth_not_configured` 503) but case journey routes are unauthenticated by design today | The biggest engineering gate (DPIA R8). Onboarding/practice routes already RBAC-guarded; the **case journey routes are not**. |
| C2 | **Security hardening** — rate limiting, security headers, token lifecycle, dependency audit | **DONE** | [`docs/security/hardening-checklist.md`](../security/hardening-checklist.md) (DEV-31); `rate-limit.ts`, `security-headers.ts`, `npm-audit` CI job | Note residual human items in that doc: web-bundle CSP, secret-scanning/push-protection, Cloud Armor edge rate limiting. |
| C3 | **Tenant-isolation tests green** | **DONE** | DEV-34; automated tenant-isolation tests (DPIA R6) | Keep green in CI. |
| C4 | **Branch protection on `main`** — required review + CI | **OPEN [HUMAN]** | DEV-47; DPIA §7 item 10 | Repo-admin toggle only; protects the integrity of every control above. |
| C5 | **Penetration test** completed + material findings remediated | **OPEN [HUMAN]** | DPIA §7 item 12 (R7); mvp-brief "pen-test before pilot scale-out" | External engagement. |

---

## D. Production environment & operations

| # | Gate | Status | Proving artifact | Notes |
|---|---|---|---|---|
| D1 | **Production environment provisioned & hardened (IAM-locked, no dev access)** | **OPEN [HUMAN]** | DEV-39; ADR-004; DPIA §7 item 13 | Real data lives in **prod**, not the demo/dev environment used for dry-runs. |
| D2 | **Monitoring / alerting live** | **OPEN [HUMAN]** | DEV-40 | Observability for the prod service. |
| D3 | **Backup / restore drilled** — encrypted, in-region, tested restore | **OPEN [HUMAN]** | DEV-41; mvp-brief privacy stack ("tested restore") | A *drilled* restore, not just configured backups. |
| D4 | **Prod-safety: demo / maintenance routes off in prod** | **OPEN** | DEV-45; `apps/api/src/demo/dev-maintenance.ts#isDevMaintenanceAllowed` | `seed-canonical` & `cleanup-e2e-test-cases` are already guarded (403 outside dev). **Finding:** `POST /v1/demo/bootstrap` is **not** gated by that guard — it creates a tenant in any environment. Confirm under DEV-45 that all demo routes (incl. `bootstrap`) are disabled/locked in prod. |

---

## E. Incident response

| # | Gate | Status | Proving artifact | Notes |
|---|---|---|---|---|
| E1 | **Incident / breach runbook finalised** — 72-hour ICO notification path tested | **OPEN [HUMAN]** | DEV-44; DPIA §5 + §7 item 14 | mvp-brief commits to a documented breach runbook; not yet finalised in `docs/`. |

---

## What's already DONE (proven in the repo today)

These four gates are demonstrably in place now:

1. **C2 — Security hardening** ([hardening-checklist.md](../security/hardening-checklist.md),
   DEV-31): rate limiting, security headers, token lifecycle, `npm audit` CI gate.
2. **C3 — Tenant-isolation tests** (DEV-34).
3. **A6 (published half) — Subprocessor list published**
   ([subprocessors.md](../compliance/subprocessors.md), 2026-06-15) — controller *acceptance*
   still open.
4. **B4 — PHI-free logging** (allowlist logger, DEV-23) — re-verify once live AI (B1) flows.

Supporting machinery also present (not gates themselves but underpin them): DPIA **draft**
(DEV-32), DSAR/erasure endpoints + runbook (DEV-24, [dsar-runbook.md](../compliance/dsar-runbook.md)),
audit retention/purge (DEV-25, [audit-retention.md](../compliance/audit-retention.md)),
auth scaffolding that fails closed (DEV-31/Auth·03), `redact.ts` (DEV-53), demo-route guard
for seed/cleanup (DEV-45 partial).

---

## Findings to surface (contradictions between intent and the current build)

1. **`POST /v1/demo/bootstrap` is not behind the dev-maintenance guard.** Unlike
   `seed-canonical` and `cleanup-e2e-test-cases`, it has no `isDevMaintenanceAllowed` check,
   so it can create a tenant in any environment. Bring it under DEV-45 (D4).
2. **Live AI is stubbed and the client is not Vertex.** ADR-007 chose Vertex Gemini, but the
   inference client targets an OpenAI-compatible endpoint with a `google/gemma-3-27b-it`
   default (the ADR-003 self-hosted shape). The Vertex swap is DEV-13 + DEV-52 (B1/B2).
3. **Case journey API is unauthenticated by design (MVP).** Onboarding/practice routes are
   RBAC-guarded and the verifier fails closed, but the case routes carry `TODO(DEV-31/auth)`.
   This is the single biggest engineering gate (C1, DPIA R8).
4. **Zoom is not in the app.** The runbook's "clinician's own Zoom" step is real, but there
   is no in-app video integration — Zoom appears only in compliance docs as *planned*
   (DEV-17 / DEV-51). The video link is an out-of-band manual step today.
5. **Identity provider mismatch.** Repo provisions Firebase Auth / Identity Platform; DEV-30
   tracks a *planned* Auth0 move. Whichever ships needs its DPA before real accounts (A4).

---

## References

- [`docs/compliance/dpia-v1.md`](../compliance/dpia-v1.md) §6 (sign-off), §7 (open items)
- [`docs/compliance/subprocessors.md`](../compliance/subprocessors.md)
- ADR-007 [Vertex Gemini managed inference](../decisions/007-vertex-gemini-managed-inference.md)
  (§ mandatory safeguards), ADR-001 (residency), ADR-004 (unified envs / prod IAM),
  ADR-005 (portal-first comms)
- [`docs/security/hardening-checklist.md`](../security/hardening-checklist.md),
  [`docs/security/token-lifecycle.md`](../security/token-lifecycle.md)
- [`docs/compliance/dsar-runbook.md`](../compliance/dsar-runbook.md),
  [`docs/compliance/audit-retention.md`](../compliance/audit-retention.md)
- Code: `apps/api/src/routes/v1.ts`, `apps/api/src/demo/dev-maintenance.ts`,
  `apps/api/src/llm/chat.ts`, `apps/api/src/llm/redact.ts`, `apps/api/src/logger.ts`
- [`practice-onboarding-runbook.md`](practice-onboarding-runbook.md)
