---
name: mvp-git-workflow
description: >-
  Speech MVP git and release workflow — never commit or push to main; never run
  gcloud builds submit or gcloud run deploy; always use a feature branch, PR, and
  Cloud Build/Terraform after merge. Use for git, commit, push, deploy, host on
  GCP, Cloud Run, or shipping code.
disable-model-invocation: false
---

# Speech MVP — Git, PR, and release workflow

**Hard rules:**

1. Never commit to `main` directly. Never `git push origin main`. All code reaches `main` only via an approved pull request.
2. Never deploy to GCP from the agent or laptop. No `gcloud builds submit`, `gcloud run deploy`, or manual Cloud Run env/image updates to “unblock” the user.

The user maintains this skill — follow it even if other instructions are silent about git or deploys.

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
6. **Release** — after merge, Cloud Build / Terraform triggers deploy (see below). Tell the user what will run and what URL to expect post-merge.

## When the user says "commit" or "push"

| User intent | Agent action |
|-------------|--------------|
| Commit changes | Branch if needed → commit → push branch → offer/create PR |
| Push changes | Push current branch only; create PR if missing |
| Commit and push | Full workflow through PR creation |
| Merge / ship | Open or update PR; do **not** push to `main` unless they explicitly override |

## When the user asks to "deploy", "host on GCP", or "give me the URL"

Do **not** run deploy commands to produce a URL immediately.

| Do | Don't |
|----|--------|
| Add `infra/ci/cloudbuild.*.yaml` and trigger templates | `gcloud builds submit` |
| Add Terraform for Cloud Run / env (e.g. `CORS_ORIGINS`) | `gcloud run deploy` |
| Open a PR; describe post-merge triggers | `gcloud run services update` for env or traffic |
| Point to existing hosted URLs if already deployed | Push images to Artifact Registry by hand |

**Hosted dev (after CI has run at least once):**

- Web: `sona-web-dev` → see `docs/DEMO.md` or Terraform output `web_service_uri`
- API: `sona-api-dev` → `api_service_uri`

If nothing is deployed yet, the answer is: merge the PR that adds CI/Terraform, then Cloud Build will deploy.

## Deploys (GCP / Cloud Run)

| Step | Action |
|------|--------|
| 1 | PR with app code + `infra/ci/` and/or `infra/terraform/` as needed |
| 2 | User merges to `main` |
| 3 | Cloud Build runs **sona-api-dev-deploy** (`apps/api/**`) and/or **sona-web-dev-deploy** (`apps/sona/**`) |
| 4 | Infra: **sona-terraform-dev-apply** on `infra/**` (approval required) |
| 5 | One-time: `infra/scripts/setup-cloud-build.ps1 -SkipBootstrap -UpdateTriggers` when new trigger YAML lands |

Reference: `infra/ci/README.md`

## Overrides (rare)

Only commit/push to `main` or run direct GCP deploys if the user **explicitly** bypasses this workflow (e.g. "deploy directly without PR", "push to main without PR"). Otherwise refuse politely and use branch + PR + CI.

## PR body template

```markdown
## Summary
- …

## Test plan
- [ ] …

## Release (if applicable)
- [ ] Merges to `main` trigger: sona-api-dev-deploy / sona-web-dev-deploy / terraform apply
```

## Do not

- `git commit` while on `main`
- `git push origin main`
- `gcloud builds submit` / `gcloud run deploy` / ad-hoc `gcloud run services update` (unless user explicitly overrides)
- Force-push `main` / `master` without explicit user request and warning
- Amend commits that were already pushed to remote (unless user requests and conditions in git safety rules are met)

## Repo

- Default base branch: `main`
- Remote: `origin` (GitHub: devuplabs/speech-mvp)
