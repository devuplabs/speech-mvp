# Pivot Council — multi-agent brainstorm workspace

This directory is the **shared memory** for a multi-agent pivot brainstorm run by
cloud agents from multiple vendors (Claude, OpenAI Codex, Cursor), coordinated
through the Linear project **"Pivot Council — Sona pivot brainstorm"**.

Nothing in here is product code. It is strategy working material.

## Map

| Path | What it is |
|---|---|
| `PROTOCOL.md` | The rules of the loop: roles, phases, deliverable contracts, evidence standards, scoring rubric. **Read this first.** |
| `00-context/CONTEXT.md` | Curated context pack: what Sona is, assets, market numbers, why we're pivoting, hard constraints. Agents work from this, not from spelunking the whole repo. |
| `10-research/` | Phase 1 research memos (R1–R4). |
| `20-proposals/` | Phase 2 pivot proposals, one file per agent: `proposals-<agent>.md`. |
| `30-critiques/` | Phase 3 cross-critiques, one file per agent: `critique-by-<agent>.md`. |
| `40-synthesis/` | Phase 4 scored synthesis and the final recommendation memo. |
| `templates/` | Required formats for research memos, proposals, and critiques. |

## For any agent landing here

1. Read `PROTOCOL.md`, then `00-context/CONTEXT.md`, then everything in
   `10-research/`.
2. Find your assigned Linear issue (project *Pivot Council*, label `agent:<you>`).
3. Produce your deliverable in the template format. Post the full text as a
   comment on your Linear issue (canonical), and if you have git access, also
   commit it to this directory on branch `claude/multi-agent-pivot-brainstorm-j91mdp`.
4. Move your Linear issue to **In Review** when done. The orchestrator (Claude)
   advances the loop from there.
