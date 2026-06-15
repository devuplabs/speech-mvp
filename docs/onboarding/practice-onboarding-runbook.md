# Practice onboarding runbook

**Linear:** DEV-43 — Customer onboarding runbook & go-live checklist
**Audience:** the person onboarding a practice (non-engineer). No code required.
**Scope:** Sona v1 pilot — a solo UK private SLT practice (the design partner) evaluating
Sona in their own environment. Covers first-run setup through one full client loop
(referral → intake → consult prep → triage → session plan → family summary → carryover).

> **Read this first — two hard rules**
>
> 1. **No real family data until the [go-live gate](go-live-checklist.md) is green.** Every
>    dry-run in this runbook uses **synthetic / test data only**. A real, consented family
>    is onboarded *only after* every gate item passes (DPIA signed, Vertex safeguards live,
>    consent wording final, prod env, etc.). If any gate item is open, the answer to "can a
>    real family's data flow?" is **no** (DPIA §7).
> 2. **AI is a clinician-reviewed DRAFT, never autonomous.** Every AI artefact (prep brief,
>    session plan, family summary, clinical report) is labelled "DRAFT — clinician must
>    review", is gated by a `reviewed_at` timestamp before it counts as record material, and
>    is **never auto-sent** to a family. The clinician decides; AI drafts (mvp-brief
>    principle #2; ADR-007 §9; DPIA §3.4).

---

## 0. Current-state honesty box (what is and isn't wired today)

So you set expectations correctly, here is the gap between the *intended* flow and what the
repo actually does **today**. None of these block a synthetic dry-run; several block a real
go-live (see [go-live-checklist.md](go-live-checklist.md)).

| Capability | Intended | Today | Linear |
|---|---|---|---|
| **AI drafts** | Live Vertex Gemini, region-pinned, data-minimised | **Stub drafts.** The API gracefully degrades to canned/stub content when no inference endpoint is set; live inference is **not wired** | DEV-13 (wire live AI), DEV-52 (Vertex safeguards) |
| **Inference client** | Vertex AI Gemini (ADR-007) | Code targets an **OpenAI-compatible** endpoint (`INFERENCE_OPENAI_BASE_URL`, default model `google/gemma-3-27b-it` — the ADR-003 self-hosted shape). The Vertex swap is config + safeguards, not done | DEV-13, ADR-007 |
| **Video consult** | Clinician's own Zoom for the 20-min call | **Not in the app at all.** Zoom is referenced only in compliance docs as *planned*. The consult is booked in Sona (date/time + `.ics`); the video link is arranged **out of band** by the clinician | DEV-17, DEV-51 |
| **Clinician auth / RBAC** | Firebase/Identity Platform login, role-gated case API | Auth scaffolding + onboarding API exist and **fail closed** until Firebase is wired; the **case journey API is currently unauthenticated by design** (`TODO(DEV-31/auth)`) | DEV-31, DEV-30 |
| **Identity provider** | Auth0 (planned) | Repo provisions **Firebase Auth / Identity Platform**; Auth0 is a planned decision | DEV-30 |
| **Family comms** | Portal-first; email is notification-only | Implemented as designed — summary/report render **only in the authenticated portal**; email never carries clinical content | ADR-005 |

Where a step below cannot be exercised in this sandbox (no full stack / no live AI / no
Zoom), it is written **from the code** and marked **"verify on first real onboarding."**

---

## 1. Prerequisites

Have these ready before you start. Items the *practice* owns are marked **(practice)**.

| # | Prerequisite | Notes |
|---|---|---|
| 1 | **Admin email + device** **(practice)** | The practice admin (for a solo practice, the SLT herself) needs a working email and a modern browser. Sona is a **web app** — adults only, no kid-facing UI (mvp-brief principle #3). |
| 2 | **Clinician email(s)** **(practice)** | One email per seat. For a solo practice this is just the admin's, who is also the clinician. |
| 3 | **The clinician's own Zoom (or equivalent) for the 20-min video consult** **(practice)** | The video call is **out of band** — Sona does not host or record it. The clinician sends the family their own Zoom link separately. Zoom is *planned* as an integration (DEV-17 booking UX / DEV-51 Zoom app + DPA); until then, treat the meeting link as a manual step. |
| 4 | **A calendar (optional)** **(practice)** | Sona produces an `.ics` file per booked consult (`GET /v1/cases/:caseId/consult.ics`) the clinician can import into any calendar. No live calendar sync in v1. |
| 5 | **A synthetic test family** | Made-up child + parent details and a parent email **you control** (e.g. a personal inbox) to receive the magic link. **Never a real family for a dry-run.** |
| 6 | **The environment URL + that it is the right environment** | Dry-runs happen in **dev/stage**, never the production environment that will hold real data (ADR-004; DEV-39). Real onboarding happens only in prod, after the gate. |

What you do **not** need in v1: appointment-booking/payments integration, an ESP account
(email is notification-only via Mailgun, configured by ops), or any LLM API key (AI is
stubbed until DEV-13).

---

## 2. First-run: practice setup (admin)

This is the in-app onboarding wizard (`apps/sona/lib/features/auth/onboarding_flow.dart`).
The progress header shows **4 steps — Account · Plan & seats · Practice · Clinicians** —
followed by a "you're live" screen. It is backed by `POST/PATCH /v1/practices*`
(`apps/api/src/routes/practices.ts`).

> **A tenant is a practice.** Every clinician seat in a practice shares the same patients —
> cases are tenant-scoped, not siloed per clinician (auth-onboarding-implementation.md).

### Step 1 — Admin sign-up (screen 01)
`admin_signup_screen.dart` → `POST /v1/practices`.
- Admin enters their email + a password and the **practice name**. This creates the admin's
  login and the practice (tenant), and signs the admin in.
- **Today:** sign-in requires Firebase, which fails closed until wired (DEV-31/Auth·01). In
  the demo/test build (`firebase_options.isConfigured == false`) the auth gate falls through
  to the app so the flow can be walked without a live login. **Verify on first real
  onboarding** that the admin can create an account and sign in against the prod identity
  provider.

### Step 2 — Plan & seats (screen 02)
`plan_seats_screen.dart` → `PATCH /v1/practices/:id/plan`.
- Choose the plan and number of **seats** (one row in `users` per seat). For a solo practice,
  **1 seat** is correct. Seat limits are enforced server-side.

### Step 3 — Configure the practice (screen 03)
`practice_config_screen.dart` → `PATCH /v1/practices/:id`.
- Set **location** and **specialties** (the areas the practice covers — e.g. speech sound,
  language, stutter, voice, feeding, social communication). Stored on the tenant
  (`location`, `specialties` jsonb).

### Step 4 — Invite clinician(s) (screen 04)
`invite_clinicians_screen.dart` → `POST /v1/practices/:id/clinicians`
(or `.../clinicians/import` for CSV).
- Add each clinician's name + email + role (`admin` / `clinician`). For a solo practice the
  admin **invites herself** as the clinician (or is already the seat). On invite, the system
  creates/links the Firebase user, generates a **set-password** link, and **emails** it via
  Mailgun (notification-only — no PHI). If Firebase/Mailgun is not configured it returns
  `emailSent:false` without losing the seat; an admin can re-send
  (`.../clinicians/:userId/resend`).
- The invited clinician opens the email, sets a password (`set_password_screen.dart` →
  `/auth/accept-invite`), and can sign in. **Verify on first real onboarding.**

### Step 5 — Go live (screen 05)
`practice_live_screen.dart` → `POST /v1/practices/:id/activate` → admin dashboard
(`admin_home_screen.dart`).

### Set availability rules
There is **no separate availability step in the onboarding wizard** — availability is managed
from the clinician side, and the system seeds **default availability** the first time slots
are requested (`ensureDefaultAvailability`). To customise:
- `GET /v1/clinicians/me/availability/rules?tenantId=…` to view, then
  `PUT /v1/clinicians/me/availability/rules` to replace them (weekday + start/end minute
  windows). These rules drive the bookable slots shown in the consult slot picker.
- **Finding:** the onboarding brief lists "set availability rules" as an onboarding step, but
  in the build it is a clinician-settings action that also auto-seeds a sensible default, not
  a wizard screen. Walk the practitioner through it from settings after go-live.

---

## 3. One full client loop (clinician + family)

This is the core loop from `docs/mvp-brief.md` and `docs/design/sona-care-journey-map.md`,
backed by `apps/api/src/routes/v1.ts`. Do this end-to-end with your **synthetic test
family** first.

### 3.1 Register the first patient (clinician)
- From **Today** (`clinician_today_screen.dart`) the clinician opens **register patient** via
  the **new patient sheet** (`new_patient_sheet.dart`) →
  `POST /v1/clinicians/me/patients` and/or `POST /v1/cases`.
- Enter the (synthetic) child display name + parent email. Creates a `case` in status
  `intake_pending` and writes a `case.created` audit row.

### 3.2 Send the magic link to the (test) family
- The case has an **intake link** (`case_intake_links.token` — 256-bit, **14-day** TTL,
  reusable, rate-limited). Resend / revoke via
  `POST /v1/cases/:caseId/intake-links/resend|revoke`.
- The family receives a **notification-only** email (link, no PHI) and opens it. Use a
  test inbox **you** control.

### 3.3 Family completes intake (parent, magic link)
- Parent lands on **Welcome** (`parent_welcome_screen.dart`), then walks the **adaptive,
  branching intake** (`parent_intake_step_screen.dart`, `difficulty_checklist.dart`):
  branches by age band and presenting concern (e.g. fussy-eater → dentist/sensory/OT
  follow-ups), with an EHCP toggle.
- Token resolves via `GET /v1/intake-links/:token`; progress saves as a draft
  (`PUT /v1/cases/:caseId/intake/draft`).
- **Review & consent** (`parent_review_screen.dart`, `intake_review_summary.dart`): the
  parent reviews summary cards, ticks consent, and submits
  (`POST /v1/cases/:caseId/intake`, carrying `consentVersion`).
- **Consent wording is not final** — it is finalised under **DEV-28** and must be wired to
  `consent_version` before a real family. For a dry-run, the placeholder wording is fine;
  for real data this is a **go-live gate**.

### 3.4 AI prep brief is drafted (automatic, DRAFT)
- On submit, the case moves `intake_submitted` → `prep_drafting`, and a **prep brief draft**
  is generated (`enqueueLlmPrep` async + an inline `draftPrepBrief` fallback so it works
  without the worker).
- **Today this is a STUB.** `isLlmConfigured` is false until `INFERENCE_OPENAI_BASE_URL` is
  set, so the brief is canned/stub content, not live Gemini (DEV-13). The case shows the
  brief moving "Drafting" → "Ready" regardless. Identifiers are stripped before any real
  prompt (`llm/redact.ts`, DEV-53) — relevant once live AI is wired.

### 3.5 Clinician reviews intake + prep brief (consult prep)
- **Intake review** (`clinician_intake_review_screen.dart`) and **Consult prep**
  (`clinician_prep_screen.dart`) via `GET /v1/cases/:caseId` (returns case + intake +
  drafts). Opening a case writes a de-duped `case.viewed` audit row.
- The prep screen shows AI-drafted **probe areas**, red flags, and references — all under the
  **"AI-drafted · clinician-reviewed" DRAFT** marker. The clinician reads/edits before the
  call.

### 3.6 Book the consult (slot picker)
- **Slot picker** (`consult_slot_picker.dart`): `GET /v1/clinicians/me/availability` lists
  bookable slots (default availability is auto-seeded); book via
  `POST /v1/cases/:caseId/consult` (start + duration; defaults to the free 20-min consult).
  Case → `consult_booked`.
- Download `GET /v1/cases/:caseId/consult.ics` to add the slot to any calendar.
- **The video link is out of band.** Sona books the *time*; the clinician sends the family
  their **own Zoom** link separately (DEV-17/DEV-51). **Verify on first real onboarding.**

### 3.7 Triage (outcome + rationale)
- **Triage** (`clinician_triage_screen.dart`) → `POST /v1/cases/:caseId/triage` with one of
  four outcomes (**strategy only / short block / full assessment / refer out**) + a free-text
  reason. Case → `triaged`.
- Guard: triage is blocked while `intake_pending` (must have a submitted intake); a consult
  is **optional**, so you may triage with or without a booked consult (DEV-10/DEV-34).

### 3.8 Session plan (DRAFT, clinician-edited)
- The first **session plan** draft (goals / activities / home practice / materials) is an
  AI draft in `ai_drafts` carrying the **DRAFT** label; the clinician edits the editable
  sections. **Stub until DEV-13.** Nothing in the plan reaches the family until the clinician
  shapes and publishes the family summary (next step).

### 3.9 Shape & publish the family summary
- **Parent summary editor** (`clinician_parent_summary_screen.dart`): the clinician tunes
  tone (warm ↔ clinical), reading level, and included sections, reviews the DRAFT, then
  **publishes** (`POST /v1/cases/:caseId/parent-summary/publish`). "Publish" — not "send
  email" — is the deliberate UX (ADR-005). Case → `summary_sent`.
- The family reads it in the **authenticated portal only**
  (`GET /v1/cases/:caseId/parent-summary`); any email is a notification ("a summary is
  ready" + sign-in link), **never** the clinical content (ADR-005, enforced in
  `services/email.ts`).

### 3.10 Share carryover resources / open the portal
- The clinician shares **carryover resources** (`clinician_carryover_screen.dart` →
  `POST/GET/PATCH/DELETE /v1/cases/:caseId/carryover/resources`).
- The family gets a **portal link** (`case_portal_links.token` — 256-bit, **90-day** TTL,
  revocable, rate-limited; `POST /v1/cases/:caseId/portal-links`, revoke with
  `.../revoke`). Family view: `parent_portal_screen.dart` → `GET /v1/portal/:token`.

### 3.11 Family logs progress (carryover loop)
- The family posts progress from the portal (`POST /v1/portal/:token/progress`); the
  clinician sees it (`clinician_carryover_screen.dart`,
  `GET /v1/cases/:caseId/carryover/progress`). This closes the first carryover loop that
  feeds the next session.

---

## 4. The AI-as-reviewed-DRAFT principle (say this to the clinician)

- Every AI artefact is a **DRAFT**: prep brief (3.4), session plan (3.8), family summary
  (3.9), clinical report (`/clinical-report/generate`). Each is labelled and gated by
  `reviewed_at` before it counts as a clinical record (ADR-006; DPIA §3.4).
- **Nothing is auto-sent.** The clinician publishes the summary explicitly; AI never reaches
  a family on its own (ADR-007 §9).
- HCPC accountability stays with the clinician. Sona reduces admin; it does not make clinical
  decisions (mvp-brief principle #2).
- When live AI is wired (DEV-13/52), prompts are **data-minimised** first — child name → a
  `[CHILD]` placeholder re-inserted in our layer, DOB → age band, identifiers stripped
  (`llm/redact.ts`, DEV-53). Today the drafts are stubs, so this is forward-looking.

---

## 5. FAQ / known rough edges

- **"The AI output looks generic / the same every time."** Expected today — drafts are
  **stubs** until live inference is wired (DEV-13). The inference client currently targets an
  OpenAI-compatible endpoint (`INFERENCE_OPENAI_BASE_URL`, default `google/gemma-3-27b-it`);
  the move to Vertex Gemini is ADR-007 + DEV-13/52, not yet done.
- **"Where's the video call button?"** There isn't one. Zoom is **not wired** — only
  referenced as planned (DEV-17 booking UX, DEV-51 Zoom app + DPA). Sona books the slot and
  emits an `.ics`; the clinician shares their own Zoom link out of band.
- **"Do I get an email with the summary?"** No clinical content is ever emailed. Summaries
  and reports live **only in the authenticated portal** (ADR-005); email is a notification +
  sign-in link.
- **"Login isn't required to open a case."** Correct today, and a known gap — the case
  journey API is **unauthenticated by design in the MVP** (`TODO(DEV-31/auth)`). Auth/RBAC
  on case routes (DEV-31/30) is a **go-live gate** before any real data.
- **"Auth0 or Firebase?"** The repo provisions **Firebase Auth / Identity Platform** today;
  Auth0 is a *planned* decision (DEV-30). The controller decides which ships, and its DPA
  must be in place first.
- **"Can I onboard my first real client now?"** Only after the
  [go-live checklist](go-live-checklist.md) is fully green. Until then: **synthetic data
  only.**

---

## References

- Product & flow: [`docs/mvp-brief.md`](../mvp-brief.md),
  [`docs/design/sona-care-journey-map.md`](../design/sona-care-journey-map.md)
- Decisions: ADR-001 (residency), ADR-005 (portal-first comms), ADR-007 (Vertex inference)
- Compliance: [`docs/compliance/dpia-v1.md`](../compliance/dpia-v1.md),
  [`docs/compliance/subprocessors.md`](../compliance/subprocessors.md)
- Security: [`docs/security/hardening-checklist.md`](../security/hardening-checklist.md),
  [`docs/security/token-lifecycle.md`](../security/token-lifecycle.md)
- Auth/onboarding backend: [`docs/auth-onboarding-implementation.md`](../auth-onboarding-implementation.md)
- Code: `apps/sona/lib/features/auth/`, `apps/sona/lib/features/clinician/`,
  `apps/sona/lib/features/parent/`, `apps/api/src/routes/v1.ts`,
  `apps/api/src/routes/practices.ts`
- **Go-live gate:** [`go-live-checklist.md`](go-live-checklist.md)
