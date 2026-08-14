# Pivot Council protocol

Multi-agent brainstorm to answer one question:

> **What should Sona pivot to, given that a competitor shipped our MVP shape and
> captured our distribution channels — while our target customer remains speech
> pathologists (SLTs/SLPs) in the UK and US?**

Design follows the orchestrator–workers pattern (Anthropic, *Building Effective
Agents*) and the engineering discipline from Stanford CS329Z (*Engineering AI
Agents*): decompose the problem, curate the context, define deliverable
contracts per component, and evaluate outputs against an explicit rubric.

## Roles

| Role | Who | How it's triggered |
|---|---|---|
| Orchestrator | Claude (Claude Code cloud session) | Recurring schedule; polls Linear, advances phases, synthesizes |
| Worker: research | Claude subagents | Done in orchestrator session (Phase 1) |
| Worker: ideation + critique | OpenAI Codex cloud agent | Linear issue labelled `agent:codex` (delegate in Linear, or paste the issue URL into Codex) |
| Worker: ideation + critique | Cursor cloud agent | Linear issue labelled `agent:cursor` (delegate in Linear, or paste the issue URL into a Cursor background agent) |
| Worker: ideation + critique | Claude | Issues labelled `agent:claude` |
| Decision maker | Founder (Senthil) | Single human gate at the end (`human` label) |

Model diversity is applied where it matters most — independent idea generation
and adversarial critique — not at mechanical stages.

## Phases (state machine)

```
P0 context → P1 research (4 parallel) → P2 ideation (3 agents, independent)
→ P3 cross-critique (each agent red-teams the others) → P4 scored synthesis
→ P5 human decision gate
```

A phase opens when the previous phase's issues reach **In Review**/**Done**.
The orchestrator opens phases by moving issues from **Backlog** to **Todo** and
posting a "phase open" comment on each.

- **P0 — Context pack** (`00-context/CONTEXT.md`): curated once by the orchestrator.
- **P1 — Research** (`10-research/`): four lenses — R1 competitor & whitespace,
  R2 demand truth & monetization, R3 distribution, R4 asset leverage.
- **P2 — Ideation** (`20-proposals/`): each agent independently proposes 3–5
  pivot candidates using `templates/proposal.md`. Agents must NOT read each
  other's proposals before submitting (independence preserves diversity).
- **P3 — Cross-critique** (`30-critiques/`): each agent adversarially reviews the
  *other* agents' proposals using `templates/critique.md`. Goal: kill weak ideas,
  strengthen strong ones. Politeness is a defect here.
- **P4 — Synthesis** (`40-synthesis/`): orchestrator dedupes, scores every
  surviving candidate against the rubric below, and writes a recommendation memo
  with the top 2–3 pivots, each paired with a cheap falsifiable validation test.
- **P5 — Human gate**: founder picks the validation test(s) to run. This is the
  only step that requires a human.

## Evidence standards (hard rules, born from our scars)

1. **Stated willingness to pay is inadmissible.** "They said they'd pay" counts
   for nothing. Admissible demand evidence: money already spent on workarounds,
   existing budget lines, statutory/regulatory obligations, pull behaviour
   (inbound chasing, deposits, pre-orders), pain that shows up in revenue or
   compliance risk — not in politeness.
2. **Distribution before features.** Every proposal must name its channel, who
   gatekeeps it, why it is not already captured by the competitor/incumbents,
   and why a 2-person team can win it. "Great product, figure out distribution
   later" is an automatic kill.
3. **Feature moats are dead; name a real one.** Acceptable moats: distribution
   ownership, workflow/data lock-in, eval/benchmark assets, compliance posture,
   community/brand, speed of iteration. "Our AI is better" is not a moat.
4. **Asset leverage.** Prefer pivots that reuse: the speech-ml persona/eval
   harness (54 personas, 18 SLT specialties, 8 jurisdictions), the compliant
   clinical platform, the compliance-by-design posture, SLT domain depth.
5. **Target customer is fixed:** speech pathologists (SLTs/SLPs) in the **UK and
   US**. The *product, wedge, buyer-of-record and business model* may change
   (e.g. schools, LAs, ICBs, clinic groups or parents can hold the budget), but
   the pivot must serve the SLT/SLP workflow. Ideas that abandon this audience
   are out of scope for this run.
6. **Falsifiability.** Every proposal ends with a kill criterion and a ≤2-week,
   ≤£500 validation test whose success metric involves real money or real
   committed behaviour, not opinions.

## Scoring rubric (the eval, used in P4)

Each surviving candidate is scored 1–5 on:

| Dimension | Weight |
|---|---|
| Demand evidence quality (per rules above) | ×3 |
| Distribution: open channel a 2-person team can win | ×3 |
| Moat durability (non-feature) | ×2 |
| Asset leverage (how much of what we built transfers) | ×2 |
| Time-to-first-revenue | ×2 |
| 2-person feasibility (scope, regulatory burden) | ×1 |

Critique findings adjust scores; unresolved fatal critiques kill a candidate.

## Communication conventions

- **Canonical output** = full markdown deliverable posted as a comment on the
  agent's Linear issue. Git commit to `brainstorm/` on branch
  `claude/multi-agent-pivot-brainstorm-j91mdp` is a mirror (do it if you can).
- Status flow per issue: `Todo → In Progress (started) → In Review (deliverable
  posted) → Done (orchestrator accepted)`.
- Questions/blockers: comment on the issue and @sen only if truly blocked on a
  human. Default to making a reasonable assumption and stating it.

## Anti-stall rules (autonomy guarantees)

- The orchestrator wakes on a schedule. If a worker issue has sat in Todo/In
  Progress for **>48h**, the orchestrator posts a nudge comment; after **96h**
  it reassigns the work to an available agent (Claude produces an alternate
  independent proposal set under a deliberately different framing/persona so
  diversity is preserved) and the loop continues.
- The founder is consulted exactly once, at P5. Missing founder input (e.g. the
  competitor's name) is handled by proceeding on stated assumptions, flagged in
  deliverables as `ASSUMPTION:`.
