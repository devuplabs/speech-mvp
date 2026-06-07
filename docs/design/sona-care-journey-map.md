# Sona — Care Journey & Swimlanes (v1)

**Companion notes for the FigJam board.**
**Board:** https://www.figma.com/board/n0T7y2Kcrb6s1A6XzqXniw
**Date:** 7 Jun 2026 · **Data:** synthetic only · **Scope:** generalised across the whole ASLTIP market (~1,800 UK private SLTs).

A care-pathway ("customer journey") map for **Sona** — the AI co-pilot for UK private
Speech & Language Therapy — covering the **first ~30 days of a new case**. The board has
two coordinated views on one canvas:

1. **Executive view** — the 9 stages, one line of narrative each, the headline pain today,
   where Sona creates value (Real vs Vision), a before→after row, and a time-saved band.
   Skimmable in ~2 minutes by a non-technical founder.
2. **Product view** — the detailed swimlane: actor lanes (frontstage→backstage) × the 9
   stages, plus six analytical layers (mindset/emotion, pain today, Sona intervention,
   AI artifacts, trust/compliance, value/KPI), with branch points and Real/Vision tags.

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
