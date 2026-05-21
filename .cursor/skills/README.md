# Cursor skills for Speech MVP

Skills teach the agent structured workflows. On-demand skills are synced from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT). Run `scripts/sync-agent-skills.ps1` to refresh.

This repo uses two tiers:

## Always-on (every chat)

Loaded via `.cursor/rules/*.mdc` with `alwaysApply: true`:

| Rule | Purpose |
|------|---------|
| `mvp-git-workflow` | Branch + PR only — never commit/push to `main` |
| `incremental-implementation` | Thin vertical slices, verify each step |
| `code-review-and-quality` | Five-axis review before merge |
| `mvp-security-reminder` | PHI, secrets, portal-first comms |

Edit those rules or `.cursor/skills/mvp-git-workflow/SKILL.md` as your process evolves.

## On-demand (auto-invoked when relevant)

Full skills live under `.cursor/skills/<name>/SKILL.md` after sync. They are copied from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) with `disable-model-invocation: false` so Cursor can load them when the task matches the description.

### First-time setup

```powershell
# Default source: E:\devup\agent-skills
.\scripts\sync-agent-skills.ps1

# Or point at your clone:
$env:AGENT_SKILLS_PATH = "E:\devup\agent-skills"
.\scripts\sync-agent-skills.ps1
```

Re-run after updating the upstream `agent-skills` repo.

### How to use on-demand skills

**1. Automatic (recommended)**  
Just describe the task in chat. Examples:

| You say… | Skill that should activate |
|----------|----------------------------|
| "Match this Figma screen in Flutter" | `frontend-ui-engineering` |
| "The Chrome page is blank" | `browser-testing-with-devtools`, `debugging-and-error-recovery` |
| "Add a new intake API endpoint" | `api-and-interface-design` |
| "Record an ADR for portal-first email" | `documentation-and-adrs` |
| "Cloud Build failed" | `ci-cd-and-automation`, `debugging-and-error-recovery` |
| "Plan magic-link auth" | `spec-driven-development`, `planning-and-task-breakdown` |
| "Review this PR before merge" | `code-review-and-quality` (full skill) |
| "Harden parent summary publish" | `security-and-hardening` |

**2. Explicit @ mention (Cursor)**  
In Agent chat, type `@` and pick a skill if your Cursor build lists `.cursor/skills` entries (e.g. `@frontend-ui-engineering`).

**3. Explicit instruction**  
> Follow the `security-and-hardening` skill in `.cursor/skills/security-and-hardening/SKILL.md` for this change.

**4. Specialist agents (copy/paste)**  
For deep review, paste content from `E:\devup\agent-skills\agents\code-reviewer.md` (or `security-auditor.md`, `test-engineer.md`) and ask the agent to review in that persona.

### On-demand skills included by sync

- `frontend-ui-engineering`
- `browser-testing-with-devtools`
- `api-and-interface-design`
- `security-and-hardening`
- `documentation-and-adrs`
- `debugging-and-error-recovery`
- `ci-cd-and-automation`
- `spec-driven-development`
- `planning-and-task-breakdown`
- `test-driven-development`
- `code-simplification`
- `performance-optimization`
- `shipping-and-launch`
- `deprecation-and-migration`
- `incremental-implementation` (full; always-on rule is the short form)
- `code-review-and-quality` (full; always-on rule is the short form)

### Reference checklists

After sync: `.cursor/references/` — `security-checklist.md`, `testing-patterns.md`, `performance-checklist.md`, `accessibility-checklist.md`.

Mention them when needed: e.g. "Use the security checklist in `.cursor/references/security-checklist.md`."

### Do not duplicate git workflow

Use **`mvp-git-workflow`** for branching/PR policy. Do not add the pack's `git-workflow-and-versioning` skill — it allows trunk merges without your PR-only rule.
