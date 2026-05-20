# Cloud Build + GitHub — troubleshooting

## “I authorized OAuth but never saw the GitHub App install prompt”

That is **often normal**. On the current connection:

| Field | Value |
|-------|--------|
| `installationState.stage` | **COMPLETE** |
| `githubConfig.appInstallationId` | `134099335` |
| OAuth user | Your GitHub account (shown in connection `githubConfig`) |

OAuth and app install can happen in one flow, or the app was **already installed** on your GitHub user/org from a previous GCP project. You do **not** need a second prompt if `stage` is `COMPLETE`.

Verify anytime:

```powershell
gcloud builds connections describe sona-github `
  --region=europe-west2 --project=project-a625d19b-de99-48e9-9a9 `
  --format="yaml(installationState,githubConfig)"
```

## What you still must do: grant repo access to the app

The app can be installed but **not allowed to read** `devuplabs/speech-mvp` (common for **org-owned private** repos).

1. Open **GitHub → Settings → Applications → Installed GitHub Apps**  
   Or org admins: **devuplabs → Settings → GitHub Apps → Google Cloud Build**
2. Click **Configure** on **Google Cloud Build**.
3. Under **Repository access**, choose **Only select repositories** and add **`speech-mvp`** (or “All repositories” for dev only).
4. Save.

Direct link (user installation — adjust if your org uses an org-level install):

https://github.com/settings/installations/134099335

## Link the repo in GCP (done once per project)

```powershell
gcloud builds repositories create speech-mvp `
  --remote-uri=https://github.com/devuplabs/speech-mvp.git `
  --connection=sona-github `
  --region=europe-west2 `
  --project=project-a625d19b-de99-48e9-9a9
```

Check:

```powershell
gcloud builds repositories list `
  --connection=sona-github --region=europe-west2 `
  --project=project-a625d19b-de99-48e9-9a9
```

You should see `speech-mvp`.

## Create triggers

After repo access is configured, either:

**A. Console (recommended if CLI returns `INVALID_ARGUMENT`)**

1. [Cloud Build → Triggers](https://console.cloud.google.com/cloud-build/triggers;region=europe-west2?project=project-a625d19b-de99-48e9-9a9)
2. **Create trigger** → Repository: **speech-mvp** (2nd gen)
3. **Plan trigger:** Event = Pull request → `main`, Config = `infra/ci/cloudbuild.terraform.plan.yaml`
4. **Apply trigger:** Event = Push → `main`, Config = `infra/ci/cloudbuild.terraform.apply.yaml`, enable **Require approval**

**B. Script**

```powershell
.\infra\scripts\setup-cloud-build.ps1 -SkipBootstrap
```

## PR builds and `/gcbrun`

For the plan trigger, Cloud Build only runs on PRs from **forks/external contributors** unless a collaborator comments **`/gcbrun`** on the PR (default `COMMENTS_ENABLED`). As repo owner, comment `/gcbrun` on your PR to start the plan build.

## Connection region

Use **`europe-west2`** everywhere (connection, repositories, triggers). Do not use `global` for 2nd gen repos.
