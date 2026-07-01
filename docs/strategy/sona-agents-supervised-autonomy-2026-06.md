---
title: "Sona — Where AI Agents Fit (Supervised Autonomy)"
subtitle: "June 2026"
date: "2026-06-12"
lang: en-GB
---

> Internal strategy memo. Companion to the May 2026 differentiation review and the June 2026 venture
> thesis. Question answered here: **do AI agents fit a product whose first principle is "the clinician
> reviews everything," and if so, where and how?**

# TL;DR — answers in 60 seconds

- **Yes, agents fit — because autonomy is a dial per task, not a property of the product.** "Not fully
  autonomous" is not a limitation to apologise for; it is the design contract. The rule that makes agents
  safe in Sona: **every agent loop terminates in either (a) a clinician-reviewed artifact, (b) a reversible
  internal action, or (c) an escalation to a human.** Nothing else is permitted to be an endpoint.
- **Sona is already agent-shaped.** The append-only audit trail, the review gate on every AI artifact,
  Cloud Tasks async workers, and the A2UI server-fed UI are exactly the substrate an agent platform
  needs: a place to log every tool call, a UI surface for "approve / edit / reject" proposals, and an
  async execution lane. Competitors will have to retrofit this; we have it by construction.
- **The first agents should not touch a patient.** The highest-value, zero-risk agents are *internal*:
  eval agents that run the 54-persona harness on every prompt or model change, persona-generation agents,
  and red-team agents. Full autonomy is fine there because the data is synthetic. This can start now,
  pre-DPIA, and it strengthens the safety case rather than testing it.
- **The product-facing sequence is: draft → chain → bounded agent.** v0.1 is single-call drafting (already
  scoped). v0.2 chains steps without new permissions (gap-check the intake, fetch guidance, assemble the
  prep brief). v0.3 introduces the first genuinely agentic behaviours: chasing missing information from
  parents, and practice-ops automation — both inside hard conversational and action boundaries.
- **Strategically, "supervised autonomy with a published safety case" is the 2026–27 differentiation.**
  The scribe category is racing from transcription to agents; the losers will bolt supervision on after
  an incident. A clinical product that can say *"our agents are certified against a public benchmark and
  every action is audit-logged and review-gated"* is the version of agentic AI that schools, ICBs, and
  eventually the NHS can buy.

# 1. The autonomy contract

One rule, stated once and enforced everywhere:

> **An agent in Sona may plan, gather, draft, and propose without limit. It may *act* only when the
> action is internal and reversible, or pre-approved by template, or signed off by the clinician.
> When uncertain, its terminal action is escalation — never a guess.**

This maps onto four autonomy tiers. Every agent capability is assigned a tier at design time, recorded in
the audit log at run time:

| Tier | What the agent may do | Examples | Review point |
|---|---|---|---|
| **T0 — Draft** | Produce artifacts only | Prep brief, session plan, parent summary, triage suggestion | Clinician reviews before anything leaves the system |
| **T1 — Internal & reversible** | Act inside Sona where undo is trivial | Flag a case, order the worklist, schedule a reminder, pre-fill a form, attach guidance citations | Visible in audit log; clinician can revert |
| **T2 — Bounded external** | Send pre-approved, template-constrained communications | "We're missing the school report — upload here"; appointment reminders; consent-form chase | Templates approved once by the clinician; every send logged; free-text generation outside template scope is blocked |
| **T3 — Clinical judgement** | Decide triage, give advice to a parent, alter a plan unilaterally | — | **Never.** Not a roadmap item. This is the line that keeps Sona out of autonomous-SaMD territory and inside HCPC norms |

Two properties make this regulatory armour rather than overhead: the tier is *enforced in code* (tool
permissions per agent, not prompt instructions), and the audit trail already records who/what/when for
every action — agents simply become a new actor type (`agent:<name>` alongside `clinician:<id>`), with
every tool call logged the way clinician actions already are.

# 2. Where agents fit — the case lifecycle, revisited

The May memo's nine-step lifecycle, now annotated with the agent that serves each step and its tier:

**Steps 1–2: Enquiry & basic details → the *front-door agent* (T1/T2).**
Today inbound is ad-hoc (email, phone, web form) and the May memo flagged the missing light-touch funnel.
An agent that reads inbound enquiries, extracts child age / presenting concern / location, drafts the
"book a free consult" reply from an approved template, and places the case on the clinician's worklist
in priority order is classic agent work: multi-source, messy input, structured output, low stakes.
Out-of-scope enquiries (adult voice for a paediatric practice) get a drafted signpost reply — sent only
on approval. *This is probably the highest clinician-delight agent: it attacks the inbox, which no
competitor in the SLT space touches.*

**Step 5: Deep intake → the *intake-completion agent* (T1/T2).**
After the parent submits, the agent: checks the submission for gaps and internal contradictions (age vs
milestones, "no concerns" boxes vs free-text red flags); requests missing documents (hearing test, school
report, EHCP excerpt) via template-bounded portal messages; and answers parents' *administrative*
questions ("what happens next?", "how do I upload?"). Hard boundary, enforced by an output classifier and
a topic allow-list: the moment a parent asks anything clinical ("does this mean autism?"), the agent's
only legal move is T0+escalate — "that's an important question for [clinician name]; I've flagged it for
your consultation," with the question pinned to the prep brief. This boundary is what keeps a
parent-facing agent inside GDPR/HCPC comfort and outside MHRA software-as-medical-device scope.

**Step 6: Consult prep & triage → the *case-preparation agent* (T0 + T1).**
This is the upgrade from "drafting" to "agentic reasoning," and it is where the eval harness pays off
directly. Instead of one LLM call over the intake JSON, the agent: retrieves the nearest persona
archetypes from the library; pulls the relevant RCSLT/NICE/SLI guidance passages; checks the statutory
context (EHCP stage, school involvement); runs the safeguarding-flag checklist; then composes the prep
brief and a *triage recommendation with a cited reasoning chain*. Everything is T0 — the clinician still
clicks the triage outcome — but the draft now shows its working, and the audit log captures the chain.
A reviewable reasoning trail is worth more to a regulator (and a tribunal) than a better-worded paragraph.

**Steps 4, plus billing/admin → the *practice-ops agent* (T1/T2).**
Reminders, consent chasing, no-show follow-ups, report-deadline tracking (EHCP statutory deadlines are
dates the agent can simply know), invoice drafting. Boring, reversible, and the part of the 4–8 weekly
admin hours that drafting alone doesn't touch. Year-1 integrations (calendar, payments) become this
agent's tools rather than standalone features.

**Step 7: Carryover → the *carryover agent* (T1/T2, v0.2).**
Between sessions: nudges home practice per the plan, collects parent-logged observations, watches for
regression keywords and safeguarding signals (escalate, T0), and drafts next-session plan adjustments
grounded in what actually happened at home. This is the outcomes-loop moat from the venture memo wearing
its natural interface. The agent makes the loop *continuous* — which is the thing a weekly 45-minute
session fundamentally cannot be, and the thing no scribe can offer because scribes only exist during the
appointment.

**Step 9: Caseload analytics → the *caseload agent* (T0, later).**
Weekly digest: which cases are stalling, where override rates are drifting, capacity forecast. Drafted
narrative over real metrics; clinician-facing only.

# 3. The internal agents — full autonomy where it's free

No DPIA, no PHI, no review gate needed, and available to build **now**:

- **Eval-runner agent.** On every prompt, template, or model-version change: run all 54 golden cases,
  diff triage outcomes and plan domains against expectations, score artifact gists (LLM-as-judge against
  the golden gists), and block the deploy on regression. This turns the persona harness from a manual
  `make eval` into a continuous certification gate — *agents grading agents*, which is precisely the
  machinery the SLT-Bench move (venture memo, Move 2) needs anyway.
- **Persona-generation agent.** Drafts new personas to spec (specialty × jurisdiction × severity cells
  still empty on the coverage matrix), schema-validates, and opens a PR for human clinical review. The
  54 become 200 without 4× the authoring effort, and the human stays where they belong: reviewing
  clinical plausibility, not typing YAML.
- **Red-team agent.** Plays the difficult parent (or the prompt-injecting one) against the
  intake-completion agent's boundaries; plays edge-case intakes against the triage agent. Failures become
  new golden cases. A standing adversarial loop on synthetic data is a safety-case asset most funded
  competitors cannot show.
- **Dev agents.** Already in use (this repo's recent history is the evidence). Worth stating as strategy:
  a two-person team competing with funded teams does it by spending agent-hours where headcount is
  missing — tests, migrations, template authoring, doc upkeep.

The pattern worth internalising: **the eval harness is the agent certification authority.** No
product-facing agent capability ships until it passes the persona benchmark for its task, and its
benchmark score is recorded alongside its tier. That sentence is the published safety posture.

# 4. How this lands on the existing architecture

Nothing here requires new infrastructure categories — it requires promoting existing pieces:

- **Cloud Tasks → worker Cloud Run** is already the async lane for long-running drafts; agent loops
  (plan → tool call → observe → continue) run in the same lane with a step budget and a wall-clock cap.
- **The `aiDrafts` table generalises to `agentRuns`:** persisted plan, tool-call log, token/step counts,
  terminal state (`drafted | acted | escalated | aborted`), and the artifact produced. The audit log
  references the run.
- **A2UI is the approval surface.** Agent proposals arrive as server-fed cards — *"Intake has 2 gaps;
  here's the message I'll send the parent — Approve / Edit / Reject"* — streamed over the existing SSE
  channel. The review gate becomes a one-tap interaction instead of a chore, which is what makes
  supervised autonomy *feel* like autonomy to the clinician.
- **Tool permissions live server-side per agent identity.** The intake-completion agent's toolset
  physically excludes `send_email(free_text)`; T2 sends go through `send_templated(template_id, slots)`.
  Guardrails as API surface, not as prompt hopes.
- **Model posture unchanged:** the agent loop runs against the same self-hosted endpoint behind the
  existing `LlmClient` interface. Agentic ≠ new vendor exposure.

# 5. Sequencing — agents do not jump the gates

The venture memo's stage gates still govern. Agents slot in without reordering anything:

| When | What ships | Why this order |
|---|---|---|
| **Now (pre-DPIA)** | Eval-runner, persona-generation, red-team agents (internal, synthetic) | Zero PHI; builds the certification machinery the product agents will need |
| **Gate 1 (live loop)** | T0 drafting only — single calls, no agent loops | The drafting value thesis must be proven before it is compounded |
| **Gate 1 → 2** | Case-preparation agent (T0 chains: retrieve → check → cite → compose) | Same review gate, richer drafts; measured by edit-distance like everything else |
| **Gate 2 → 3** | Front-door agent + practice-ops agent (T1/T2); intake-completion agent behind a per-practice opt-in | First *actions*; start where actions are reversible or template-bounded |
| **v0.2** | Carryover agent | Rides the outcomes-loop build; the moat feature |
| **Never** | T3 | The line is the product |

One honest warning to hold ourselves to: **agents are a multiplier, not a rescue.** If Gate 1 shows
clinicians rewriting most of the drafts, wrapping the same model in a loop will not fix it — it will
produce confidently-assembled wrong briefs faster. Agents compound a loop that already works; they are
sequenced after the proof, not instead of it.

# 6. The strategic point

The scribe incumbents are all announcing "agentic" roadmaps; the predictable failure mode across the
category will be autonomy shipped first and supervision retrofitted after the first incident. Sona's
position inverts that: supervision was the founding constraint, so every increment of autonomy arrives
**pre-audited, pre-gated, and benchmarked against a clinical eval suite we can publish.** "Not fully
autonomous" is not the caveat in that story. It is the headline: *supervised autonomy you can certify* —
the only kind a profession with safeguarding duties, statutory deadlines, and HCPC accountability is
ever going to adopt.
