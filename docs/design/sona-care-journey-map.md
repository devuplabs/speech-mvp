# Sona — Care Journey & Swimlanes (v1)

**Companion notes for the FigJam board.**
**Board:** https://www.figma.com/board/n0T7y2Kcrb6s1A6XzqXniw
**Date:** 7 Jun 2026 · **Data:** synthetic only · **Scope:** generalised across the whole ASLTIP market (~1,800 UK private SLTs).

A care-pathway ("customer journey") map for **Sona** — the AI co-pilot for UK private
Speech & Language Therapy — covering the **first ~30 days of a new case**. The board has
**two tiers at different levels of abstraction** on one canvas:

1. **Executive view (highest abstraction — the priority).** A slide-quality "journey at a
   glance", graspable in **under a minute**, with five elements only: **journey stages**
   (the 9 detailed stages collapsed into ~5 plain-English phases), an **emotion curve**
   (anxious → confident), **top pain points** (one per phase), **business metrics** (hero
   numbers), and **strategic opportunities**. Deliberately monochrome-clean — no swimlanes,
   no Real-vs-Vision colour coding, no jargon.
2. **Product view (working swimlane).** Actor lanes (frontstage→backstage) × the 9 stages,
   plus analytical bands (mindset/emotion, pain today, Sona intervention, AI artifacts,
   trust/compliance, value/KPI), with branch points and the Real/Vision colour split. The
   team's working map — short phrases per cell, not a system/data/state dump.

The five executive phases map onto the nine product stages as: **Find & enquire** (1) ·
**Understand** (2–3) · **Meet & decide** (4–6) · **Plan & share** (7–8) ·
**Progress together** (9).

---

## Methodology & sources

- **Primary source (ground truth):** design-partner interview *"Monal Interview Notes —
  30 May 2026"* (Notion). Used as **evidence**, then **generalised** — not tailored to one
  therapist.
- **Repo context:** `docs/mvp-brief.md`, `docs/strategy/sona-product-strategy-2026-05.md`,
  `docs/intake-form-spec.md`, and the implemented `apps/sona` (Flutter) + `apps/api` screens.
- **Real-vs-Vision split** taken from the strategy doc.

### Generalisation guardrails (applied everywhere on the board)

- **Vocabulary-neutral:** *client / parent / carer*, *clinician / SLT*, *practice* — no real
  names, no single brand, no HCPC numbers.
- **Specialty-neutral:** paediatric **and** adult (speech sound, language, fluency/stutter,
  social communication, voice incl. gender-affirming, AAC, dysphagia/feeding, post-stroke).
  The wedge is paediatric; the journey *shape* generalises — specialty forks are shown as
  branch points, not hard-coded.
- **No statutory hard-wiring:** EHCP shown as **one example** of a statutory plan
  (others: IDP / CSP / Statement / none).
- **No PHI:** clearly-synthetic personas only; all interfaces adult-facing.

### Anchor principles surfaced on the board

1. **"AI drafts, clinician decides"** — every AI artifact wears a DRAFT / clinician-review badge.
2. **No screen time for children** — all interfaces are adult-facing (parent / carer / clinician).
3. **UK data residency + audit trail by construction.**
4. **Augment the clinician, don't automate them** (explicitly welcomed by the design partner).

---

## The 9-stage journey (spine)

| # | Stage | Pain today (generalised evidence) | Sona value | Real / Vision |
|---|-------|-----------------------------------|-----------|---------------|
| 1 | Referral / first contact | Enquiries scattered across channels; no traceability | One queue for every enquiry | Manual case logging **Real**; auto omni-channel capture **Vision** |
| 2 | Smart intake | Chasing families for questionnaire status | Adaptive intake + status (not started/in progress/complete) + consent | **Real** |
| 3 | Intake review & overview | Stitching documents + handwritten notes; "everything is manual" | Whole-client overview on one screen | **Real** |
| 4 | Consult prep | Prep manual/skipped; free consult under-prepared | AI prep brief (probe areas, red flags, references) — DRAFT | **Vision** |
| 5 | Consultation | 30-min session → ~20 min admin after, only 30 min billable | Slot booking; calendar/video sync | Booking **Real**; sync **Vision** |
| 6 | Triage decision | No funnel data; decision undocumented | Configurable triage capture + rationale | **Real** |
| 7 | First session plan | Built by hand, often via ChatGPT-in-a-browser (PHI leaves practice) | AI session plan — DRAFT, clinician edits & signs | **Vision** |
| 8 | Client / family summary | Report writing 2–2.5 hrs; ~3-wk lead time dents confidence | Tone/reading-level summary via portal, same-day — DRAFT | UI **Real**; AI draft **Vision** |
| 9 | Carryover & progress | Assessment ≈ 3-hr session; carryover via ad-hoc email/WhatsApp | Resources control + progress portal + report sub-loop | **Vision** |

**Time saved:** target **≥ 4 productive hours / month** freed (partner-confirmed); faster
report turnaround builds family confidence; more free time → better care, less burnout,
more capacity.

---

## 5-bullet summary

- Sona owns the **first ~30 days** of a private SLT case as one reviewed loop:
  referral → smart intake → overview → consult prep → consultation → triage →
  session plan → family summary → carryover.
- **The trust posture is the moat:** every AI output is a clinician-reviewed **DRAFT**,
  with consent capture, append-only audit, UK data residency, and a clinician sign-off gate.
- **Real today** = adaptive intake, status tracking, case management, intake overview,
  triage capture, audit trail, slot booking, design system. **Vision** = AI prep brief,
  AI session plan, AI family summary, progress portal, calendar/video & PMS sync.
- The **biggest pains are admin-shaped** and quantified: the ~20-min post-session admin tax,
  the 2–2.5-hr report with ~3-week lead time, and chasing families for intake status.
- The journey is **generalised across ASLTIP** (paediatric *and* adult), with specialty,
  age-band, triage-outcome, and statutory-plan **branch points** rather than paediatric
  hard-coding.

---

## Open questions / assumptions flagged for the founders

1. **KPIs / SLAs are TBC** — the sources explicitly leave these open (intake completion rate,
   consult→engagement rate, report turnaround SLA, hours-saved measurement). Marked as
   assumption stickies on the board.
2. **Omni-channel enquiry capture** (stage 1) is **not built** today — manual case logging is.
   How automatic do we make capture, and which channels first?
3. **Paediatric-only vs all-of-SLT** at launch — the truthful framing today is paediatric;
   the board generalises, but personas/templates for adult specialties don't exist yet.
4. **AI triage suggestion** and **AI overview highlights** are shown as optional Vision items —
   confirm whether they're in scope or out (the partner welcomes augmentation, not automation).
5. **Statutory-plan handling** — EHCP is one branch; confirm which jurisdictions/plans the
   v1 template pack must cover.
6. **Channel / portal vs app** for family delivery — partner says either is fine "so long as
   it's secure"; confirm the default for v1.

---

## Review against the Customer-Journey-Map skill (Dean Peters) — improvements applied

The board was reviewed against the [customer-journey-map skill](https://github.com/deanpeters/Product-Manager-Skills/blob/main/skills/customer-journey-map/SKILL.md)
rubric and Definition of Done. Strong already: two-tier abstraction, specific
numeric pain points, explicit Real-vs-Vision honesty, and a visual emotion curve.
The following gaps were closed:

- **Worked persona** (skill: "one persona, consistent") — added a synthetic
  worked-example card ("Priya", parent of Aanya (4), speech-sound delay; solo
  paediatric SLT) to the Executive view, with a note that the journey shape
  generalises across ASLTIP.
- **Touchpoint inventory** (skill: "comprehensive, specific channels") — added a
  **Touchpoints / channel** lane to the Product view naming the channel + device
  per stage (phone/email/web/WhatsApp/ASLTIP directory, magic-link SMS, web
  dashboard, video, secure portal/app, etc.).
- **Prioritization framework** (skill DoD: "rank improvements by impact/feasibility")
  — added an **impact × effort 2×2** plus a **sequenced-bets** ranked list to the
  Executive view.
- **Substantiated emotion** (skill: "authentic, preferably with quotes") — added a
  **Voice of the field** band with verbatim (anonymised, synthetic) partner quotes.
- **Measurable KPIs** (skill: "trackable, stage-appropriate") — replaced several
  "(TBC)" KPIs with directional targets (e.g. intake completion ≥ 80%, consult →
  engagement ≥ 50%, report turnaround < 72 h vs the ~3-wk baseline).
- **Update cadence / ownership** (skill anti-pattern: "one-time exercise") — added a
  footer with owner, source, last-updated, quarterly review date, and a validation
  TODO (corroborate with 3–5 more ASLTIP SLTs).

**Informed divergences from the skill (kept on purpose):** the artifact is a
healthcare **care-pathway / service blueprint**, not a B2B marketing funnel, so it
uses care stages (not Awareness→Loyalty), keeps **two actor lanes** rather than a
single buyer persona, and represents "teams" via frontstage/backstage actors
(solo-practitioner context).
