# Care Journey + Swimlane Diagram — Agent Prompt

**Status:** v2 · 6 June 2026
**Purpose:** A ready-to-use prompt for an Opus 4.8 agent (with access to Notion, Figma,
and this repo) to build a healthcare **care journey / patient-pathway map** in **FigJam**
for the Sona product — the "customer journey" equivalent in a healthcare context. It asks
for **three tiers of abstraction**: a clean, template-style **executive overview** (the
priority), a **team/product working swimlane**, and a **full-detail build/agent reference**.

**Changelog:** v2 restructures the deliverable into three abstraction tiers after a v1
board came out too detailed for executives — density now lives in the bottom tier, and
the top tier is an abstract, slide-like "journey at a glance".

**How to use:** Copy everything in the prompt block below and hand it to the agent.
The prompt is self-contained but instructs the agent to verify against the live sources.

**Provenance:** Anchored in the primary-source design-partner interview
("Monal Interview Notes - 30th May 2026") plus `docs/mvp-brief.md`,
`docs/strategy/sona-product-strategy-2026-05.md`, and
`docs/design/v1-interface-redesign-brief.md`. Deliberately generalised across the whole
ASLTIP market rather than tailored to a single SLT.

---

## Prompt

```markdown
# Task: Build a Care Journey + Swimlane Diagram for "Sona" in FigJam

You are a senior product designer + healthcare service designer. Produce a **care
journey (patient/care-pathway) map with swimlanes** in **FigJam** for a product
codenamed **Sona** — an AI co-pilot for private Speech & Language Therapy (SLT)
practice in the UK. The diagram is the "customer journey" equivalent for a
healthcare context.

Produce **three tiers at different levels of abstraction**, as separate frames on
one board. They are ordered by importance — **Tier 1 is the star deliverable**:

1. **Executive overview (highest abstraction — the priority).** A clean,
   template-quality "journey at a glance" a non-technical founder or investor can
   absorb in **30–60 seconds**. ~5 grouped phases across the top, one headline line
   per phase, a single emotion/sentiment curve, 2–3 "moments that matter", a
   before→after contrast, and one hero value metric. **No swimlanes, no system
   actions, no AI internals.** Lots of whitespace, big readable type — it must look
   like a polished published journey-map template, not a working board.
2. **Team / product working view (mid abstraction).** The swimlane journey: ~9
   stages, the pain today, the Sona intervention, and the real-vs-vision split.
   Human-readable; used in product discussions and as the working "product view".
3. **Build / agent reference (full detail).** The exhaustive swimlaned map of every
   stage, actor, touchpoint, system action, AI artifact, data handoff, and state.
   **Label it explicitly as a developer/agent reference — not for human
   presentation.** This is where all the dense detail lives so the other tiers stay
   clean.

> The previous version of this board was too detailed at the top: the high-detail
> map is useful for build work but is not human-readable for executives. Push all
> density **down** into Tier 3, and make Tier 1 genuinely abstract and beautiful.

You have access to **Notion**, **Figma**, and this **code repository**. Use all three.

---

## Step 1 — Read the sources before drawing anything

**Primary source (the most recent design-partner conversation):**
- Notion page: "Monal Interview Notes - 30th May 2026 (Sat)"
  → `https://app.notion.com/p/377c6894396e807380b9da9087509f9c`
  Fetch it with the Notion tools and treat it as the lived-experience ground truth.

**Repo context (read these to understand product scope & state):**
- `docs/mvp-brief.md` — the product, the loop, principles, scope/out-of-scope.
- `docs/strategy/sona-product-strategy-2026-05.md` — generalisation seams,
  single-therapist tailoring leaks, competitor/market context, "real vs vision" split.
- `docs/design/v1-interface-redesign-brief.md` — current screen inventory and the
  move from one therapist to many.
- `apps/sona/lib/features/clinician/**` and `apps/sona/lib/features/parent/**`
  (or equivalent) — the actually-implemented screens, to ground "real today".
- `apps/api/**` — what the backend actually persists vs. what is still stubbed.

Also search Notion for any related pages (intake spec, day-in-the-life, KPIs/SLAs)
and the existing Figma file "Sona — Speech Therapy MVP design"
(`figma.com/design/OBPcwy4hIS79EQYbK8URBM`) for visual/vocabulary alignment.

Do **not** invent clinical detail. If the sources are silent, mark it as an
assumption sticky in a distinct colour rather than presenting it as fact.

---

## Step 2 — Framing & guardrails (critical — read carefully)

**Generalise across the whole ASLTIP market, do NOT tailor to one therapist.**
ASLTIP = Association of Speech and Language Therapists in Independent Practice
(~1,800 UK members). The interview is with one design partner (Monal Gajjar,
paediatric private SLT). Use her experience as *evidence*, but the journey must hold
for **all UK private SLTs**, including adult specialties.

Apply these neutralisations everywhere on the board:
- **Vocabulary-neutral:** use "**client / parent / carer**" not just "parent";
  "**clinician / SLT**" not a named person; "**practice**" not "Speech Sanctuary".
  No real names, no HCPC numbers, no single brand.
- **Specialty-neutral:** cover **paediatric AND adult** (e.g. speech sound, language,
  stutter/fluency, social communication, voice incl. gender-affirming, AAC,
  dysphagia/feeding, post-stroke). The product wedge is paediatric, but the journey
  shape generalises — note specialty branch points instead of hard-coding paediatric.
- **No statutory hard-wiring:** treat EHCP as one example of a statutory-plan branch
  (others: IDP/CSP/Statement/none), not a fixed step.
- **No PHI / no real client data.** Use clearly-synthetic personas only.
- **Honesty split:** visually distinguish **"Real today"** vs **"Vision / roadmap"**
  using the strategy doc's split — Real today: adaptive intake, case management,
  status tracking, audit trail, design system, slot booking. Vision: AI prep brief,
  AI session plan, AI client/family summary, progress portal, calendar/video sync.
  Executives must not be misled into thinking vision items already ship.

**Anchor principles (from the briefs) — surface them on the board:**
- "AI drafts, clinician decides" — every AI artifact wears a **draft / clinician-review**
  badge. Trust is the moat.
- "No screen time for children" — all interfaces are adult-facing (parent/carer/clinician).
- "UK data residency + audit trail by construction."
- "Augment the clinician, don't automate them" (explicitly welcomed by the partner).

---

## Step 3 — The care journey to map (the spine = columns)

Map the **first ~30 days of a new SLT case** as ordered stages (left → right).
Use this spine, adjusting names to be vocabulary-neutral, and add specialty branch
markers where the path forks:

1. **Referral / first contact** — enquiry arrives via *any* channel (phone, email,
   web, WhatsApp, ASLTIP directory). Goal: capture every enquiry for traceability.
2. **Smart intake** — magic-link / portal adaptive questionnaire to the family/client;
   branches by age band & presenting concern; consent captured; **status visible**
   (not started / in progress / complete).
3. **Intake review & overview** — clinician sees the whole picture in one place
   (summary view), instead of stitching documents and handwritten notes.
4. **Consult prep** — AI-drafted prep brief: probe areas, red flags, references —
   readying the (often free, ~20-min) consultation.
5. **Consultation** — the live call/session (out-of-band).
6. **Triage decision** — outcome chosen (e.g. strategy-only / short block /
   full assessment / refer out) + rationale; per-practice configurable.
7. **First session plan** — AI-drafted, clinician-edited plan (goals, activities,
   home practice, materials).
8. **Client/family summary** — tone- and reading-level-adjustable summary delivered
   via secure portal/app; closes the loop same-day.
9. **Carryover & progress** — between-session resources (a curated/uploadable
   resources area the clinician controls visibility on), progress visible to the
   family via mobile, feedback fed back into the next plan. Show the **assessment-report**
   sub-loop here too (long, painful, high-value).

For each stage, also capture the **before vs after**: the manual baseline today vs.
the Sona-assisted flow.

**For the Tier 1 executive overview, collapse the 9 stages into ~5 plain-English
phases** (avoid product jargon). Suggested grouping:

1. **Find & enquire** (referral / first contact)
2. **Understand** (smart intake → intake review & overview)
3. **Meet & decide** (consult prep → consultation → triage)
4. **Plan & share** (first session plan → client/family summary)
5. **Progress together** (carryover, resources, progress, report turnaround)

Use the detailed 9 stages only in Tiers 2 and 3.

---

## Step 4 — Swimlanes (the rows) and analytical layers

These swimlanes and layers apply to **Tiers 2 and 3** (the working and reference
views). **Tier 1 stays abstract — do not put swimlanes on it.** Lay these tiers out
as a **swimlane journey map**: stages as columns, lanes as rows.

**Actor lanes (frontstage → backstage):**
- **Client / Parent / Carer** (the family or adult client)
- **Clinician / SLT**
- **Sona — frontstage** (the app/portal UI the actors touch)
- **Sona — backstage / AI** (async drafting, schema-validated outputs, worker jobs)
- **External systems** (calendar, video, payments, PMS e.g. Cliniko — mostly *vision*)

**Analytical layers to include (as labelled rows or sticky bands per stage):**
- **Actions / touchpoints** (who does what, on what device)
- **Mindset / emotions** — especially the family's anxiety and the clinician's
  admin-burden/burnout; show the relief Sona is meant to create.
- **Pain points today** (manual baseline) — anchor with partner evidence, e.g.:
  - "30-min session → ~20 min of admin after, but only the 30 min is billable."
  - "Initial assessment ≈ 3-hr session, report writing 2–2.5 hrs, ~3-week lead time."
  - Chasing families for questionnaire completion status.
  - "Everything is manual today"; juggling documents + handwritten notes.
- **Sona intervention** — what the product does at this stage (mark Real vs Vision).
- **AI artifacts** — each tagged "DRAFT — clinician to review".
- **Trust / compliance checkpoints** — consent capture, audit-trail entry,
  clinician sign-off gate, UK data residency.
- **Value / KPI / time saved** — quantify where possible (the partner expects Sona to
  free **≥4 productive hours/month**; faster report turnaround builds family confidence;
  more free time → better care, less burnout, more capacity). Flag KPIs/SLAs as
  "to be confirmed" where the sources say they're still open.

---

## Step 5 — Build it in FigJam

- **Before any `use_figma` call, load the Figma skills** `/figma-use` and
  `/figma-use-figjam` (and `/figma-create-new-file` before creating a file). Follow them.
- Create a **FigJam board** (or update the existing one) titled
  **"Sona — Care Journey & Swimlanes (v1)"**. Lay out the three tiers top-to-bottom
  as clearly separated, titled sections: **Tier 1 at the top**, then Tier 2, then Tier 3.

### Tier 1 — Executive overview (the priority; make it template-beautiful)

Model this on a **polished, published customer-journey-map template** — the kind of
clean "journey at a glance" you find as a sample online — not on a working swimlane.
Aim for something an executive grasps in **30–60 seconds**.

- **One horizontal row of ~5 grouped phases** (use the Step 3 grouping). Big phase
  titles, generous whitespace, minimal words.
- **Per phase, at most:** a one-line "what happens", a one-line "what Sona changes",
  and an emotion marker. No system actions, no AI internals, no data, no states.
- **A single emotion/sentiment curve** flowing left→right across the phases (the
  classic journey-map line — from anxious/overloaded → relieved/confident).
- **2–3 "moments that matter"** called out as highlights (e.g. the first overview in
  one place; the same-day summary; fast report turnaround).
- **A before→after strip** (manual today vs. Sona-assisted) and **one hero metric**
  (e.g. "**frees ≥4 productive hours / month**").
- Keep it **abstract**: no swimlanes, no Real-vs-Vision colour coding, no jargon.
  If it looks like a working board, it's wrong — simplify until it reads like a slide.

### Tier 2 — Team / product working view

- A readable **swimlane journey**: ~9 stages as columns, actor lanes + a few key
  analytical bands as rows (actions, pain today, Sona intervention, value).
- Apply the **Real-today vs Vision** colour split here. Keep cells to short phrases,
  not paragraphs — this is a working view, but still skimmable.

### Tier 3 — Build / agent reference (full detail)

- The **exhaustive swimlane** with every analytical layer from Step 4: system/AI
  actions, data handoffs, states, branch points, compliance checkpoints, edge cases.
- Add a visible banner: **"Developer / agent reference — not for executive
  presentation."**

### Visual system (all tiers)

- Consistent sticky/section colours with a **legend** — one colour each for
  Real-today, Vision/roadmap, Pain, AI-draft artifact, and Assumption/open-question.
  (The legend and Real-vs-Vision coding apply to Tiers 2–3; keep Tier 1 monochrome-clean.)
- Use the Sona palette if easily available (teal primary `#2D6A6E`, apricot accent
  `#F2A878`) so it feels on-brand.
- Each tier gets a title block: name, one-line purpose, date, and a "synthetic data,
  generalised across ASLTIP" disclaimer.

---

## Step 6 — Write up & verify

- Add a short **methodology / sources note** on the board (or a linked Notion page):
  what you used as primary source, the generalisation guardrails, and the
  real-vs-vision split — so reviewers trust it.
- Optionally create a brief companion page in Notion (or `docs/design/`) summarising
  the journey in text, linking to the FigJam board.
- **Self-check before finishing:**
  - [ ] No single-therapist / single-brand / paediatric-only tailoring leaked in.
  - [ ] Every AI artifact is marked as a clinician-reviewed draft.
  - [ ] Real-today vs Vision is unambiguous to a non-technical reader (Tiers 2–3).
  - [ ] Partner pain points appear as evidence, generalised (not "Monal-specific").
  - [ ] **Tier 1 reads like a clean template/slide** — abstract, ~5 phases, no
        swimlanes or jargon, graspable in under a minute. (This is the main fix:
        the prior board was too detailed at the top.)
  - [ ] Tier 3 is clearly labelled as a developer/agent reference, not for executives.
  - [ ] All three tiers are present, aligned, and tell the same story at their level.
  - [ ] No PHI / real names; adult-facing only.

**Deliverable:** the FigJam board URL, a 5-bullet summary of the journey, and a list
of the open questions / assumptions you flagged for the founders to resolve.
```
