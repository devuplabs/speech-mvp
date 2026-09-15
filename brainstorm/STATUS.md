# Pivot Council — final state of the loop

**Closed:** 2026-09-15 · Loop ran 2026-08-14 → 2026-08-25; orchestrator wakes continued to 2026-09-15 with no further input.

The council completed all five phases. Every deliverable is on this branch. This file records how the loop ended, what is still open, and what went stale while it waited — so the record is complete without needing the Linear board.

## Phase outcomes

| Phase | Deliverable | Status |
|---|---|---|
| P0 context | `00-context/CONTEXT.md` | Done |
| P1 research | `10-research/R1`–`R4` | Done — 4 parallel agents, same day |
| P2 ideation | `20-proposals/` — 13 candidates across 3 independent sets | Done |
| P3 cross-critique | `30-critiques/` — 4 critiques | Done |
| P4 synthesis | `40-synthesis/recommendation.md` | Done — Lane A wins at 55/65 |
| P5 founder gate | Awaiting sen | **Open** |

## Which agents actually showed up

- **Claude** produced its proposal set and its cross-critique on schedule.
- **Cursor** submitted 5 proposals via Linear DEV-137 about six hours after the phase opened; mirrored here as `proposals-cursor.md`.
- **Codex never participated.** Its ideation slot (DEV-136) and critique slot (DEV-139) were nudged at 48h and substituted at 96h per the PROTOCOL anti-stall rule, using fresh Claude subagents given deliberately different framings — a contrarian, US-weighted persona for the proposals and an operator lens for the critique. Cursor's critique slot (DEV-140) was substituted the same way with a technical-due-diligence lens.
- Files carrying `-substitute` in the name are those stand-ins, not the named vendor's work. Treat their independence accordingly: they are three different Claude framings, not three different model families.

## Linear bookkeeping left undone

The Linear MCP connection lapsed and now requires re-authorization, so the board was never brought in line with the work. Linear state is frozen at 2026-08-20 and is **not** an accurate picture:

- DEV-141 shows In Progress — the Claude critique is in fact complete.
- DEV-139 / DEV-140 show Todo — both were substituted and filed.
- DEV-142 shows Backlog — the synthesis memo is written and pushed.
- DEV-143 (the founder decision gate) was never moved to Todo.

Nothing is lost; the board is just stale. Reconnect the Linear connector if you want it tidied, or work from this branch and ignore it.

## What went stale while the loop waited

`40-synthesis/recommendation.md` names one action with a hard external deadline: submitting a response to the **DCB0129/0160 revision consultation before 11 Sep 2026**. That date passed on 11 September 2026 with no response filed. The move was listed as a free authority-building step for Lane C, not a dependency of Lane A, so the recommendation still stands — but that particular opening is closed and should be struck from the plan rather than carried forward as if it were live.

The four validation tests carry no external deadlines and remain runnable as written.

## The decision that is actually waiting

Read `40-synthesis/recommendation.md`. It asks for one choice: which of the four money-based validation tests to run, at a total cost under £1,100 over 30 days. The recommendation is to run tests 1–3 in the same fortnight and gate test 4 on recruiting a named US SLP partner.
