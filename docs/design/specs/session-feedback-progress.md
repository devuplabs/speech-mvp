# Session Feedback & End-of-Block Progress Reports — Design Spec

*Design spec for Linear **DEV-106**. Turns the design partner's per-session write-up and
end-of-block (5/10) progress summary into a fast structured capture that rolls up into a
clinician-reviewed report, delivered portal-first. No code.*

**Date:** 2026-07-01 · **Status:** Draft → In Review · **Data:** structure only, **no PII, no publisher content**

Builds on **DEV-101** (data model: `TherapyBlock`, `SessionFeedback`, `ReportTemplate`,
versioned `GeneratedReport`), **DEV-105** (report engine: template model + Gemini-on-Vertex
draft + clinician sign-off), **ADR-005** (portal-first, non-forwardable delivery), **DEV-107**
(resource hub / video clips) and **DEV-108** (parent portal + separate school-access path).
Grounded in `docs/research/assessment-forms-teardown.md` templates **2.4 Target Setting**,
**2.5 Therapy Block Summary**, and **2.6 Therapy Session Feedback Notes**.

---

## 1. Problem & goal

A real **satisfaction gap**, not a new capability. The clinician should write a short
parent-facing note after every session, but a 30-minute session followed by a ~20-minute
write-up is not sustainable, so she dropped per-session feedback to WhatsApp. That
work-around also starves her **end-of-block progress report** (a block is 5 or 10 sessions),
because there is no structured record to roll up from — she is reconstructing a block from
memory and a scattered chat thread.

**v1 goal.** Make per-session feedback a **~5-minute structured capture** (voice-note /
quick-note / tick against the block's target areas) that produces an **AI-drafted,
parent-friendly session summary** the clinician reviews, and let a **block's worth of those
summaries auto-compose the end-of-block progress report**. Deliver both through the **secure
portal**, never WhatsApp, with **carryover/homework** and **video-clip** ties.

**Non-goals (v1).** No session-audio capture / ASR (roadmap; depends on `speech-train`). No
new report *engine* — reuse DEV-105. No autonomous sending — every artefact is a
clinician-reviewed draft. No child-facing UI (adults only). No re-hosting of any licensed
instrument content.

**Principles carried in.** AI drafts, the clinician decides; portal-first and
non-forwardable; augment, do not replace; UK data residency + audit trail by construction.

---

## 2. Terminology — Program vs Plan (do not blur)

From the deep-dive terminology. The distinction is **first-class in the data model and the
UI copy**, because it changes what a client is entitled to and what reports they receive.

| Term | Who it is for | What it contains | Reports it drives |
|---|---|---|---|
| **Therapy Plan** | An **active-therapy** client in a block of intervention | Target areas + measurable targets + per-session feedback + progress across the block | Target Setting (2.4) + per-session feedback (2.6) + end-of-block progress (2.5) |
| **Therapy Program** | A **review-only** client (monitoring, advice, discharge-watch, no active block) | A set of strategies / recommendations to run at home / school, reviewed periodically | Program document + Target Setting–style carryover; **no** per-session block feedback, **no** end-of-block progress report |

**Rules.**
- A **review-only client gets a Program, not a Plan.** The UI never offers "start a block" or
  "session feedback" for a program; it offers "review" and "update strategies".
- A client can move **Program → Plan** (a review escalates into a block of therapy) and
  **Plan → Program** (a completed block steps down to monitoring). This is a status change on
  the case, logged in the audit trail; history is retained, not overwritten.
- Copy must say **"program"** and **"plan"** consistently; the AI draft prompts receive the
  mode so the summary language matches ("strategies to continue" vs "targets we worked on").

---

## 3. Therapy plan / block structure

A **Therapy Plan** owns one or more **Therapy Blocks**. A block is the unit progress is
measured over.

**Therapy Block (`TherapyBlock`, DEV-101).**
- `blockLength` — **5** or **10** sessions (the "N of 10" in template 2.6; also 5-of-5).
- `dateRange` — start / expected end.
- `targetAreas[]` — the block's goals, taken from **Target Setting (2.4)**. Each target area
  carries a **measurable target statement** (e.g. "in 4/5 opportunities, with visual
  modelling") plus **Carryover for School** and **Carryover for Home** (the 2.4 split — see §7).
- `sessions[]` — ordered `SessionFeedback` records, positioned "k of N".
- `progressState` per target area — a lightweight rating the clinician nudges each session
  (e.g. *emerging → developing → generalising → met*), used to draw the progress arc across
  the block. This is a clinician-entered clinical judgement, never computed.

**Boilerplate-left / personalised-right authoring.** Following the partner's own template
layout, every plan/report surface is a **two-column composition**:

- **Left column = boilerplate** — standing, template-owned text: the strategy/target
  *explainers*, the "why it helps" rationale, the credentials/format blurb. Not generated,
  not editable per client (edited at the template level in DEV-105's `ReportTemplate`).
- **Right column = personalised** — this client, this block: what was worked on, how they did,
  the specific next step. AI-drafted from captured feedback, clinician-edited.

This is the same skeleton across the Target Setting pack, the session feedback note, and the
block summary, so a Figma component (`TwoColumnSection`) can be reused throughout.

---

## 4. Lightweight per-session capture (the ~5-minute loop)

The core of DEV-106. Immediately after a session the clinician opens the block, lands on the
**current session ("k of N")**, and captures feedback in whichever mode is fastest to hand.
Any mix of the three inputs is valid; none is mandatory beyond picking the target areas touched.

**Capture modes (all optional, combinable):**

1. **Tick against target areas.** The block's `targetAreas[]` render as a checklist. For each
   area she touched: mark *worked on*, set/adjust the `progressState`, and (optional) tap a
   quick chip (*good day · needs revisiting · introduced · generalising*). This alone is
   enough to draft a note.
2. **Quick-note.** A short free-text box per target area or one for the whole session. This is
   the "What We Worked On" content (2.6): activity/strategy → notes.
3. **Voice-note.** Record a short spoken note; it is **transcribed to text** for the clinician
   to confirm, then treated exactly like a quick-note. *(v1 uses the platform transcription
   path; domain-adapted ASR via `speech-train` is roadmap. If no transcription is available,
   the voice-note is stored as an audio attachment the clinician types up — never sent to a
   parent as raw audio.)*

**"What We Worked On" table (2.6).** Rendered as rows of *activity/strategy → notes → outcome
chip*, one row per target area worked on. Pre-filled from the ticks; editable.

**Video-clip references (2.6, DEV-107).** She can attach short clips ("see video clip 5") to a
session. Clips live in the **resource hub (DEV-107)**; the session note **references** them by
handle and renders them inline in the portal. Clips are **non-forwardable** (§7) and consent-
gated. The note stores a reference, never an exported/embedded file.

**Next Steps + next session (2.6).** A short "next steps" free-text and the next
session date/time. Next steps seed the *homework/carryover* surface (§7).

**AI-drafted session summary (reuses DEV-105).** From the captured ticks + notes +
transcribed voice + outcome chips + target areas, the report engine drafts a
**parent-friendly session summary**:
- Same DEV-105 pipeline: template-bound sections + Gemini(Vertex) draft + **clinician sign-off
  gate**. The draft carries the standing **"AI-drafted · clinician-reviewed"** marker until
  signed.
- Tone/reading-level controls mirror the existing parent-summary surface (warm ↔ clinical).
- **Left/right composition:** left = the target-area explainer boilerplate; right = "what your
  child worked on today and how it went", plus next steps and any clip references.
- Nothing is sent until the clinician **reviews and signs**. On sign-off a **versioned
  `GeneratedReport`** is written (DEV-101) and released to the portal (DEV-108).

**Time budget.** Target end-to-end ≤ 5 minutes: ticks (~1 min) → optional voice/quick-note
(~1–2 min) → review AI draft (~1–2 min) → sign & release. The 20-minute write-up is gone
because the clinician *edits a draft* instead of *composing prose*.

---

## 4a. Session workspace — open with context (DEV-122 addition, 02 Jul)

Founder review: session N must open **in the context of sessions 1…N-1** — on paper she flips
back a page; digitised, the system must do the flipping. When the clinician opens a session
(Figma **D112-07**), before capture starts she sees:

- **Last session recap** — the previous **signed** note's summary, with its **"Next steps"
  auto-carried in** as this session's starting plan (auto-carried, clearly labelled, editable).
- **Target trend** — each block target with its `progressState` arc across the sessions so far
  (met / improving / emerging chips), so drift is visible before the session, not at block end.
- **Since last session** — home-practice tick-offs (and what was left untouched), any family
  note from the portal, anything flagged by the school view.
- **Start session capture →** — drops straight into the ~5-minute loop (§4).

A compact **"Previously — session N-1"** strip also appears on the case overview (Figma
D114-01) linking here. Data: everything above is already captured (signed SessionFeedback,
`targetAreas[].progressState`, HomeworkAssignment tick state, portal notes) — this is a read
composition, no new entities.

---

## 5. End-of-block progress report (auto-composed)

Template **2.5 Therapy Block Summary** — the 5/10 end-of-block report — is **auto-composed
from the block's session feedback**, so it is never rebuilt from memory.

**Trigger.** When the last session of a block is signed, or the clinician taps **"Compose
block summary"**, the report engine assembles a draft from **all signed `SessionFeedback` in
the block** plus the block's `targetAreas[]` and their `progressState` arc.

**Structure (2.5 "Summary of Strategies Taught").** For each target area / strategy worked
across the block, a block with the partner's three-part shape:
- **Purpose** — what this strategy/target is for. *(Boilerplate-left, template-owned.)*
- **How to Continue at Home** — the carryover action for the family. *(Personalised-right,
  drawn from the sessions' next-steps + home carryover.)*
- **Why It Helps** — the rationale. *(Boilerplate-left.)*

Plus a **progress-across-the-block** view per target area (the `progressState` arc:
emerging → … → met), a short **overall summary** (AI-drafted from the session notes,
clinician-edited), and a **recommendation / next-block-or-discharge** decision (clinician).

**Roll-up mechanics.**
- The engine **cites which sessions** contributed to each strategy line, so the clinician can
  trace a claim back to a session note (provenance, not just prose).
- Progress claims are **grounded in captured `progressState` + outcome chips**, never invented
  by the model. The model rewrites captured signal into readable prose; it does not assert new
  clinical facts.
- If the block is thin (few signed sessions), the draft flags the gaps rather than
  fabricating continuity ("2 of 10 sessions recorded — summary covers those").

**Sign-off & versioning.** Same DEV-105 gate: draft → clinician edit → sign → versioned
`GeneratedReport`. Re-composing after more sessions are signed produces a **new version**;
prior versions are retained (audit trail).

**Program note.** A **review-only Program produces no end-of-block progress report** (§2). Its
periodic output is a Program review document (strategies + carryover), composed the same way
but without block/session mechanics.

---

## 6. Target Setting report (2.4) — carryover School / Home

The **Target Setting** pack (2.4) is where a block's targets originate and is a report in its
own right. Each `TARGET 1..N`:
- a **measurable target statement** (criterion, e.g. "in 4/5 opportunities, with visual
  modelling"),
- **Carryover for School**, and
- **Carryover for Home**.

**Design signal (carried from the teardown).** The **School vs Home split is first-class**. It
maps directly onto:
- the **parent portal** (DEV-108) for the Home carryover, and
- the **separate school-access path** (DEV-108) for the School carryover — the school sees the
  school-facing carryover, not the family's private note.

Target Setting is authored with the same **boilerplate-left / personalised-right** two-column
layout, signed via DEV-105, and released to the portal. Its targets populate the block's
`targetAreas[]` (§3), closing the loop: **Target Setting defines the targets → per-session
feedback works them → block summary reports progress against them.**

---

## 7. Delivery, carryover & video clips

**Portal-first, non-forwardable (ADR-005 · DEV-108).** All three artefacts — session
summaries, the block progress report, and the Target Setting pack — are delivered through the
**secure authenticated portal**, **not WhatsApp / email attachments**. Email/SMS is
**notification-only** ("A new session summary is ready — sign in to view"); it never carries
PHI or the content itself.

**Non-forwardable.**
- Portal access is per-recipient and authenticated; content is not a shareable link or an
  exported PDF that can be forwarded on.
- **Video clips (DEV-107)** stream inside the portal only — no download, no forward, consent-
  gated, tied to the resource hub. The session/block report **references** a clip by handle;
  the clip itself is never embedded in an outbound message.

**Two audiences, two views (DEV-108).**
- **Parent portal** — the family sees session summaries, the block progress report, the
  **Home** carryover, and referenced clips.
- **School-access path** — a separate, scoped access that sees the **School** carryover and
  the school-relevant summary, and **not** the family's private content.

**Carryover / homework tie-in (DEV-107).** "Next Steps" (2.6) and "How to Continue at Home"
(2.5) become the **homework/carryover** items on the portal, each optionally linked to a
**resource-hub** resource or a **video clip**. Carryover is where the work travels off-screen
into home and school — the product's core purpose. Carryover assigned to a client shows on
their portal with a simple "done / had a go" acknowledgement the clinician can see next session
(feeding the next session's ticks).

---

## 8. Data model touchpoints (DEV-101, no schema here)

| Entity | Role in DEV-106 |
|---|---|
| `TherapyBlock` | Owns `blockLength` (5/10), `dateRange`, `targetAreas[]`, ordered `sessions[]`, per-area `progressState`. Belongs to a **Plan**. |
| `SessionFeedback` | One per session ("k of N"): touched target areas + ticks/outcome chips, quick-notes, transcribed voice-note, "What We Worked On" rows, next-steps, next-session, clip references. |
| `ReportTemplate` | Reused from DEV-105. New template variants: **Session Feedback (2.6)**, **Block Summary (2.5)**, **Target Setting (2.4)**, all two-column (boilerplate/personalised). |
| `GeneratedReport` | Versioned artefact per signed session summary and per composed block summary. Re-compose ⇒ new version; history retained. |
| Case / Plan / Program status | Program-vs-Plan mode + Program↔Plan transitions, logged in the append-only audit trail. |

Provenance rules carried in: `progressState` and outcome chips are **clinician-entered**;
the AI **rephrases captured signal**, it does not assert new clinical facts; nothing is
released without the **clinician sign-off gate**.

---

## 9. Screen / flow list (for the Figma task)

Web = clinician workspace (`apps/sona` clinician shell). Portal = parent + school (DEV-108).
Reuse the existing design system (Inter, deep-teal primary `#2D6A6E`, coral AI-marker
`#F2A878`, "AI-drafted · clinician-reviewed" pill).

**Clinician (web):**

| # | Screen | Purpose |
|---|---|---|
| C1 | **Plan / Block overview** | The plan's blocks, each block's target areas, the `progressState` arc, session list "k of N", and "Compose block summary". Program clients show the review/strategy variant instead. |
| C2 | **Session feedback — capture** | Landing on "k of N". Target-area checklist with outcome chips + `progressState`; quick-note boxes; **voice-note recorder**; "What We Worked On" table; clip attach (from resource hub); next-steps + next-session. The ~5-min surface. |
| C3 | **Session summary — AI draft review** | Two-column draft (boilerplate-left / personalised-right), tone & reading-level controls, AI marker, clip references inline, **Sign & release** gate. |
| C4 | **Block summary — compose & review** | Auto-composed 2.5 draft: per-strategy Purpose / How to Continue at Home / Why It Helps, progress-across-block, overall summary, recommendation. Session-citation traceback. Sign & release. |
| C5 | **Target Setting — author** | 2.4 pack: `TARGET 1..N` with measurable statement + Carryover School + Carryover Home; two-column; feeds block `targetAreas[]`. Sign & release. |
| C6 | **Program review — author** *(review-only)* | Program variant: strategies + carryover, periodic review; no block/session mechanics. |
| C7 | **Empty / thin-block state** | "2 of 10 recorded" messaging; prompts to record more before composing, or compose-with-gaps. |

**Family / school (portal, DEV-108):**

| # | Screen | Purpose |
|---|---|---|
| P1 | **Portal home** | Latest session summary, block progress report, carryover to-dos, referenced clips. Notification-only email deep-links here. |
| P2 | **Session summary (read)** | Parent-friendly summary; inline **non-forwardable** clip player; Home carryover with "had a go" acknowledgement. |
| P3 | **Block progress report (read)** | End-of-block summary; strategies to continue at home; progress across the block. |
| P4 | **Carryover / homework** | Home carryover items, each optionally linked to a resource-hub resource or clip; acknowledgement control. |
| S1 | **School-access view** | Scoped view: School carryover + school-relevant summary only; not the family's private content. |

**Shared components to extract:** `TwoColumnSection` (boilerplate/personalised),
`TargetAreaChecklistRow` (tick + chip + progressState), `WhatWeWorkedOnTable`,
`VoiceNoteRecorder`, `ClipReference` (non-forwardable player + attach), `AiDraftBanner` +
`SignAndReleaseBar`, `ProgressArc` (emerging → met), `CarryoverItem`.

**Happy path (flow):**

```
Target Setting authored (C5) → block created with target areas (C1)
      ↓  (each session, k of N)
Session feedback capture (C2, ~5 min: ticks · voice/quick-note · clips · next steps)
      ↓
AI-drafted session summary (C3) → clinician signs → versioned report → portal (P1/P2)
      ↓  parent/school see summary + Home/School carryover + clips (P2/P4/S1)
   … repeat to end of block …
      ↓  (last session signed, or "Compose block summary")
Block progress report auto-composed from signed sessions (C4)
      ↓  clinician edits/signs → versioned report → portal (P3)
      ↓
Recommendation: next block (Plan continues) · step down to Program (review-only)
```

---

## 10. Open questions / follow-ups

1. **Voice-note transcription in v1** — platform transcription vs deferred `speech-train`
   ASR; confirm UK-region, no-training handling for spoken clinical notes before any parent-
   facing use. (Ties to teardown §5 Q4 on clip handling.)
2. **Block length** — confirm 5 and 10 are the only lengths, or allow arbitrary N.
3. **`progressState` scale** — confirm the partner's preferred labels (emerging / developing /
   generalising / met vs a numeric or RCSLT outcome measure such as TOM).
4. **Carryover acknowledgement** — how much parent/school feedback to capture ("had a go" vs a
   richer check-in) without adding burden or child screen time.
5. **School-access identity** — how a school recipient authenticates on the separate access
   path (DEV-108), and consent scope for what the school may see.
6. **Clip constraints** — max clip length + consent expectations (teardown §5 Q4), enforced at
   attach time.

---

## 11. Cross-references

- Teardown & templates: `docs/research/assessment-forms-teardown.md` (§2.4 / §2.5 / §2.6)
- Data model: **DEV-101** · Report engine: **DEV-105** · Resource hub: **DEV-107** ·
  Parent portal + school access: **DEV-108**
- Portal-first, non-forwardable delivery: **ADR-005**
- Journey map (stage 9, "Progress together"): `docs/design/sona-care-journey-map.md`
- Guardrails: `AGENTS.md → Guardrails` (PHI safety, clinician-in-the-loop, licensed instruments)
