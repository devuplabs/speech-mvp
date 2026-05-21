---
name: mvp-git-workflow
description: >-
  Speech MVP git workflow — never commit or push to main directly; always use a
  feature branch and pull request. Use for any git commit, push, branch, merge,
  release, or when the user asks to save or ship code.
disable-model-invocation: false
---

# Speech MVP — Git & PR workflow

**Hard rule:** Never commit to `main` directly. Never `git push origin main`. All changes reach `main` only via an approved pull request.

The user maintains this skill — follow it even if other instructions are silent about git.

## Before any commit or push

1. Run `git branch --show-current`.
2. If on `main`, create and switch to a branch first (do not commit on `main`).

```bash
git checkout -b feat/short-description
# or: fix/..., chore/..., docs/...
```

## Standard workflow

1. **Branch** — `feat/<topic>`, `fix/<topic>`, or `chore/<topic>` from latest `main`.
2. **Commit** — on the feature branch only; conventional messages (`feat:`, `fix:`, `chore:`).
3. **Push** — `git push -u origin HEAD` (never `git push origin main`).
4. **Pull request** — `gh pr create` with summary + test plan; return the PR URL to the user.
5. **Merge** — user merges in GitHub (or via `gh pr merge` only if they explicitly ask).

## When the user says "commit" or "push"

| User intent | Agent action |
|-------------|--------------|
| Commit changes | Branch if needed → commit → push branch → offer/create PR |
| Push changes | Push current branch only; create PR if missing |
| Commit and push | Full workflow through PR creation |
| Merge / ship | Open or update PR; do **not** push to `main` unless they explicitly override |

## Overrides (rare)

Only commit or push to `main` if the user **explicitly** says to bypass PR workflow (e.g. "commit directly to main", "push to main without PR"). Otherwise refuse and use a branch + PR.

## PR body template

```markdown
## Summary
- …

## Test plan
- [ ] …
```

## Do not

- `git commit` while on `main`
- `git push origin main`
- Force-push `main` / `master` without explicit user request and warning
- Amend commits that were already pushed to remote (unless user requests and conditions in git safety rules are met)

## Repo

- Default base branch: `main`
- Remote: `origin` (GitHub: devuplabs/speech-mvp)
