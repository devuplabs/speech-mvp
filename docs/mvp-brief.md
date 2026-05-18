# Sona — Intake & First-Session Co-Pilot

**MVP brief · v0.1 · 11 May 2026**

A focused web app for solo private Speech & Language Therapy (SLT) practice that owns the **first 30 days of every client relationship**: referral → smart parent intake → 20-minute free consultation prep → triage → first session plan → parent-friendly summary.

> **Codename:** Sona. **Working positioning:** "Speech & language therapy, less admin."

---

## TL;DR

- **Problem.** Private-practice SLTs lose hours per week to admin around intake, triage, session planning and between-session carryover. Off-the-shelf AI tools (ChatGPT/Gemini) are useful but not trustworthy for clinical PII under UK GDPR + HCPC/RCSLT regulation.
- **Wedge.** Start at the periphery, not the clinical core. The single highest-leverage entry point — explicitly named by our design partner — is the **pre-consultation intake** and the **20-minute free consult** that follows it.
- **MVP slice.** Smart adaptive intake form for parents → clinician prep dashboard for the consult → triage decision → AI-drafted first session plan (clinician-reviewed) → parent-friendly email/PDF summary. Self-contained loop with day-one value.
- **Out of scope (intentionally).** Session-audio capture/ASR, full report generation, invoicing, appointment booking, marketplace for carryover resources, multi-therapist clinic features.
- **Validation target.** A 4–6 week pilot with one paying private practitioner (our design partner) using real (consented) families.

---

## Context — what we heard from the field

Source: 1.5 hour interview with **Monal Gajjar** (private-practice SLT, 23+ years, ex-NHS) on 8 May 2026. Full notes are in the linked Notion page; the points below are the ones that materially shape this MVP.

### 1. Tech has barely touched speech therapy
- Therapy is high-customisation: autism, ADHD, stuttering, voice, language, feeding — each with multiple regulated frameworks and therapist-specific approaches. There is no "tick all boxes" tool.
- The 2011–2015 wave of speech-therapy apps were engaging but failed on **carryover** — kids learned the app, not the real-world skill.
- Implication: an MVP must produce artifacts (notes, summaries, plans) that work **off-screen** with real humans (parent, TA, carer). Not another kid-facing app.

### 2. Start at the periphery
- "**Admin is the killer.** Sometimes people think of leaving the profession due to the extent of admin." The clinical core is too varied to standardise as a v1 product.
- Highest-impact periphery items, in Monal's order:
  1. Report writing (she already trains ChatGPT for this — confirms willingness to pay for AI assist)
  2. Target setting (clinical + parent-friendly + EHCP-aware)
  3. Clinical notes (consults, parent calls)
  4. Appointment booking
  5. T&Cs
  6. Invoicing
  7. Purchase orders (minor)

### 3. The two best entry points
- **"Initial stages of patient consultation is where your app could be of great help to start with — identifying what exactly needs to be done."**
  Smart pre-consultation intake makes the free 20-min consult dramatically more useful and serves as the front of the funnel.
- **Feedback / carryover** is her second biggest pain — what happens at home and school between sessions. Email + WhatsApp + school comms today; needs structured templates and dissemination.
- The MVP picks **intake → first session** because it's a self-contained loop with day-one value. Carryover comes in v0.2 (see roadmap).

### 4. AI is welcome but with caveats
- She already uses ChatGPT for report drafting. AI is acceptable.
- Generic LLMs are **not acceptable** for PII. UK data residency, no-training contracts, audit trails are mandatory.
- Every AI artifact must be a **clinician-reviewed draft**, never autonomous.

### 5. Regulatory and ethical
- Bodies to be aware of: **HCPC** (registration), **RCSLT** (clinical standards), **ASLTIP** (private-practice association), **NHS DSPT** if pursuing NHS pathway.
- Tone caveat from Monal: kids are already disadvantaged by screen time. The MVP **must not add screen time for children**. Adult interfaces only (parents / TAs / clinicians).

### 6. Commercial signal
- "I wouldn't mind paying for it so far as it saves me time & admin effort."
- Sole practitioners are growing — new grads going straight to private practice. Market is broader than just one persona.
- NHS may eventually buy if the product is credible.

---

## Product principles

These are the constraints we evaluate every feature against. Lifted directly from the interview, not invented.

1. **Periphery before clinical core.** Build what saves admin time first. Earn the right to touch clinical decisions later.
2. **Clinician in the loop, always.** AI drafts. Therapist decides. Every AI artifact is labelled.
3. **No screen time for children.** The product helps adults help children.
4. **GDPR-defensible by construction.** UK data residency, parental consent, no model training on client data, audit logs.
5. **Carryover is the goal.** Even MVP outputs (the parent summary, the home practice list) should make the work travel out of the session into the home and school.
6. **Solo-practitioner first.** Build for one person running a whole practice. Multi-therapist comes later.
7. **One credible loop beats five mediocre features.** Ship a single coherent flow rather than a half-built admin suite.

---

## MVP scope

### In scope (v0.1)

| Capability | Why |
|---|---|
| **Magic-link parent intake form** with branching by age band (0–3 / 3–7 / 7–11 / 11+) and presenting concern (speech sound / language / stutter / voice / feeding / social communication) | Monal's #1 stated wish. Reclaims the 20-min consult. |
| **Conditional branches** (e.g., fussy eater → dentist seen? sensory profile? OT involved?) | Triages out before the call; differentiates from a static Typeform. |
| **EHCP awareness** (toggle + EHCP-aware language helpers downstream) | Monal called this out explicitly. |
| **Clinician prep dashboard** with intake summary, suggested probe areas, red flags, linked references (RCSLT / SLI.org.uk / NICE where applicable) | Turns intake into prepared questions for the call. |
| **Triage capture** with one of four outcomes: *strategy only / short block / full assessment / refer out* + free-text reason | Justifies the form; gives Monal data on her own funnel. |
| **AI-drafted first session plan** with editable sections (goals, activities, home practice, materials, parent goals) — labelled "DRAFT — clinician must review" | Demonstrates AI value safely; mirrors what she does manually with ChatGPT today. |
| **Parent-friendly summary email/PDF** with tone slider (warm ↔ clinical), reading level, included-sections toggles | Closes the loop same-day. Carryover starts here. |
| **Privacy stack** — UK region, encryption at rest + in transit, audit log, parental consent capture, DSAR / erasure endpoints, no training on client data | GDPR + HCPC defensibility; non-negotiable. |

### Out of scope (v0.1)

| Excluded | Why we're deferring |
|---|---|
| Appointment booking / payments | Cliniko, Jane App, Power Diary already solve this. Integrate later if friction is real. |
| Session audio capture, ASR, dictation | High consent bar; depends on the [`speech-train`](../../speech-train) Whisper work maturing. Domain-adapted ASR is roadmap. |
| Full clinical report generation | Bigger surface area. Comes after notes + plan are trusted. |
| Carryover activity marketplace | Roadmap v0.2. Needs license clarity per resource. |
| Multi-therapist / clinic features | Solo practitioner first. |
| NHS integration | Possible later. Different procurement, different threat model. |
| Kid-facing UI / gamified activities | Principle #3: no screen time for children. |
| Invoicing, T&Cs e-sign | Roadmap. Cliniko already covers most of this. |

---

## User flows (mapped to the Figma design)

Figma file: **[Sona — Speech Therapy MVP design](https://www.figma.com/design/OBPcwy4hIS79EQYbK8URBM)**

| # | Frame | Surface | Role |
|---|---|---|---|
| 00 | Cover | — | Brand, principles, screen index |
| 01 | Parent · Welcome | Mobile 375×812 | Magic-link landing; trust badges (UK residency, HCPC, parent-fills-not-child); "Get started" |
| 02 | Parent · Form (branching) | Mobile | Step 4/8 with progress bar; multi-select chips; live branching example (fussy eater → dentist follow-up) |
| 03 | Parent · Review & consent | Mobile | Three summary cards (About, Concerns, Strengths) with Edit; consent checkboxes; submit & book |
| 04 | Clinician · Today | Web 1440×900 | Sidebar nav, KPI tiles, today's free consultations table, up-next + recent-activity rail |
| 05 | Clinician · Consult prep | Web | Countdown banner, client card, **AI-drafted probe areas** with prompts, red flags, references panel, quick actions |
| 06 | Triage & first session plan | Web | 4 triage cards (short block selected), AI-draft session plan with editable sections, materials list |
| 07 | Parent summary preview | Web | Edit panel (tone, reading level, sections, AI-disclosure toggle) + live email/PDF preview |

Walking the happy path:

```
Referral → Magic-link sent to parent
   ↓
Parent · Welcome  →  Parent · Form (8 adaptive steps)  →  Parent · Review & consent
   ↓
Submission generates: intake record + AI prep brief (queued)
   ↓
Clinician · Today (parent appears in the list, prep brief = "Drafting" → "Ready")
   ↓
Clinician · Consult prep (Monal walks into the 20-min call with probe questions ready)
   ↓
20-min Zoom call (out of band)
   ↓
Triage & first session plan (Monal picks pathway; AI draft plan; she edits)
   ↓
Parent summary preview (Monal tweaks tone, reviews, sends)
   ↓
Anna (parent) receives clear next-step email → first session booked
```

---

## Design system

- **Type.** Inter — Regular / Medium / Semi Bold / Bold.
- **Primary** `#2D6A6E` (deep teal). Calming, healthcare-credible.
- **Accent** `#F2A878` (warm coral). Reserved for AI-draft markers and warm parent-facing moments.
- **Background** `#FAFAF7` (warm off-white). Surface `#FFFFFF`. Borders `#E5E7EB`.
- **Semantic** success `#16A34A`, warning `#F59E0B`, danger `#DC2626`, info `#2563EB`, plus soft-tinted variants for badges/banners.
- **Radii.** 8 / 10 / 12 / 16. **Spacing scale.** 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48.
- **AI marker.** A consistent "AI-drafted · clinician-reviewed" pill (accent-soft background, accent-dark text) wherever AI text appears — and a footer line on every outbound email/PDF, visible to both clinician and parent.

The Figma file is built with auto-layout; components are not yet extracted into a shared library — that's the first task when wiring up the codebase.

---

## Architecture sketch (proposed)

The detail goes into ADR-001…N. This is the headline:

```
┌──────────────────┐      ┌──────────────────────────────┐
│  Parent (mobile) │──→  │  /parents/[token]            │
└──────────────────┘      │  (Next.js · magic link only) │
                          └──────────────────────────────┘
                                       │
                                       ▼
┌──────────────────┐      ┌──────────────────────────────┐
│  Clinician (web) │──→  │  /clinician (passkey auth)   │
└──────────────────┘      │  (Next.js · server actions)  │
                          └──────────────────────────────┘
                                       │
                                       ▼
                          ┌──────────────────────────────┐
                          │  Sona API                    │
                          │  (TypeScript · Hono or Next) │
                          └──────────────────────────────┘
                                       │
              ┌────────────────────────┼──────────────────────────┐
              ▼                        ▼                          ▼
   ┌──────────────────┐    ┌────────────────────┐    ┌──────────────────────┐
   │  Postgres (UK)   │    │  Object store (UK) │    │  LLM provider (EU/UK)│
   │  (Neon/Supabase  │    │  PDFs, exports     │    │  no-training DPA     │
   │   europe-west2)  │    │                    │    │                      │
   └──────────────────┘    └────────────────────┘    └──────────────────────┘
```

### Likely picks (to be confirmed in ADRs)
- **Frontend & API.** Next.js 14 app router + TypeScript + Tailwind. Server actions for clinician writes; route handlers for the parent magic-link surface.
- **Database.** Postgres in `europe-west2` (or AWS `eu-west-2`). Drizzle ORM. Field-level encryption on PII columns (parent name/email, child name/DOB, free-text concerns).
- **Auth.** Magic link for parents (no account). WebAuthn / passkeys for clinicians. NextAuth.js or Lucia.
- **LLM.** Single swappable provider behind an interface. First pick: **Azure OpenAI UK South** or **AWS Bedrock EU** with no-training DPA. Vertex AI (GCP `europe-west2`) is the fallback so we stay aligned with the [`speech-train`](../../speech-train) infra.
- **PDF generation.** Server-side React → PDF (e.g., `@react-pdf/renderer`) for parent summaries.
- **Email.** Postmark or AWS SES UK region. Plain text + branded HTML.
- **Observability.** Structured logs with PII redaction; audit trail in DB; Sentry with PII scrubbing.

### What we're explicitly **not** building day one
- A microservice mesh — single Next.js app + Postgres covers it.
- Custom auth — use a library.
- A vector store — RAG over RCSLT/SLI references is roadmap, not v0.1.
- A queue system — the AI prep brief can run synchronously inside a server action with a loading state.

---

## Privacy, regulatory, and security

| Concern | Approach |
|---|---|
| **UK GDPR — lawful basis** | Consent (parent), legitimate interest (clinician). Captured on intake review screen. |
| **Special-category data** (child health) | Explicit consent + minimal collection. Children's data only at the level needed for clinical triage. |
| **Data residency** | All storage in UK/EU. LLM calls go to EU/UK regions only. |
| **No model training on client data** | Required clause in every LLM vendor DPA. |
| **DSAR / right to erasure** | First-class API endpoints. SLAs documented. |
| **HCPC standards** | All clinician outputs flagged "DRAFT" until the clinician saves them; clinician HCPC number stamped on every outbound artifact. |
| **RCSLT clinical references** | Cited inline in the prep dashboard (not regurgitated as own content). |
| **Audit log** | Append-only log of who accessed which client record, when, and what changed. 7-year retention. |
| **Backups** | Encrypted backups in same region; tested restore; documented retention. |
| **Breach response** | Documented runbook; 72-hour ICO notification path. |
| **Subprocessor list** | Public page listing every vendor; updated when changed. |
| **Pen-test** | Before pilot scale-out (post-v0.1). |

---

## Roadmap after MVP

Each item is one increment. Prioritised by clinical leverage × design-partner pull.

1. **Session-by-session loop.** Clinical notes template → auto parent-friendly summary → curated carryover activities → parent / TA feedback → fed back into the next session plan. *This is Monal's #2 biggest pain.*
2. **Report generator.** Triggers from accumulated session notes; clinician edits and signs; exports as PDF. Replaces her current ChatGPT-in-a-browser workaround in a PII-safe way.
3. **Resource hub.** Curated, license-respecting carryover materials with direct-buy / affiliate links. Solves the "where do I buy this?" question that TAs and parents always ask.
4. **Domain-adapted Whisper.** Hooks into the [`speech-train`](../../speech-train) project for clinical note dictation and (with high-bar consent) parent-call transcription. UK-region inference.
5. **Light admin layer.** T&Cs e-sign + invoicing export to her accounting tool. Only if friction with Cliniko/Jane is real.
6. **Carryover parent app.** Push notifications, weekly home-practice check-ins, simple prompts (carefully designed to *limit* screen time, not increase it).
7. **NHS pathway.** DSPT certification, NHS-specific intake variations, RCSLT outcome measures (TOM, COM-B).

---

## Validation plan (next 2–3 weeks before significant code)

- **Co-design session #1** — Walk through 3 anonymised real recent intakes with Monal. Design the question tree together.
- **NHS comparison** — Talk to 2–3 NHS SLTs (Monal's own action item). Confirm intake differs but isn't incompatible. Keeps the B2B path open.
- **Paper prototype** — Parent welcome + form + clinician prep screen, click-through in Figma. Test with 1 real parent.
- **LLM vendor decision** — Region, DPA, no-training clause, fallback strategy → ADR-002.
- **Data-protection impact assessment (DPIA)** — Draft before any client data touches the system.
- **Build v0.1** — Target 4–6 weeks to first paying-user pilot (Monal herself).

---

## Open questions

The big ones that need answers before code:

1. **Vendor & region for the LLM** — Azure OpenAI UK South vs. AWS Bedrock EU vs. Vertex AI `europe-west2`. Drives auth, infra, and DPA structure. → ADR-002.
2. **Database host** — Neon vs. Supabase vs. RDS in `eu-west-2`. Cost vs. ops trade-off. → ADR-003.
3. **Hosting** — Vercel EU vs. self-host on GCP (same project as `speech-train`)? Vercel is faster to start; GCP unifies IAM. → ADR-004.
4. **Question-tree authoring** — JSON spec we edit by hand, or a small DSL with a CMS later? Starts as JSON; tracked in ADR-005.
5. **Pricing model** — Per-clinician monthly subscription vs. per-case. Need ~3 SLT conversations before deciding.
6. **B2C vs. B2B2C identity** — Does the parent ever have an account beyond a magic link? Default no in v0.1; revisit when carryover lands.

---

## Working agreements

- **Decisions go in ADRs.** `docs/decisions/NNN-title.md`. New consequential decision = new ADR. Don't delete old ones; supersede.
- **No PII in repo.** Sample data is generated. Real screenshots in `_review/` are gitignored.
- **No model training on client data** is a hard rule, not a preference.
- **AI outputs are drafts** — never auto-sent, never auto-saved as clinical record.
- **Solo-practitioner first.** If a feature needs a "team" concept to make sense, it's too early.

---

## Related work in sibling repos

- [`speech-train`](../../speech-train) — Whisper fine-tuning on Vertex AI. Long-term, this produces the clinical-domain ASR model that powers dictation features in Sona v0.4+. Out of scope for v0.1.

---

## Status

| Section | Status |
|---|---|
| Interview synthesis | Done |
| MVP scope | Drafted, awaiting design-partner sign-off |
| Figma screens (7) | Done — see file link above |
| Architecture decisions | Sketch only — ADRs pending |
| Code | Not started |
| Pilot agreement | Not started |
| DPIA | Not started |

_Next action: schedule co-design session #1 with Monal to walk through the Figma flow and finalise the intake question tree._
