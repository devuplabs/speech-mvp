# Cursor MCP — Google Cloud & Developer Knowledge

Copy [`.cursor/mcp.json.example`](../.cursor/mcp.json.example) to **either**:

- **Project:** `speech-mvp/.cursor/mcp.json` (commit without secrets), or  
- **Global:** `%USERPROFILE%\.cursor\mcp.json` (all projects)

Then set environment variables and restart Cursor (**Settings → MCP**).

## Servers

| Server | Package / URL | Purpose |
|--------|----------------|---------|
| **google-developer-knowledge** | `https://developerknowledge.googleapis.com/mcp` | Official Google docs search (`search_documents`, `get_documents`) |
| **gcloud** | `@google-cloud/gcloud-mcp` | Run gcloud via natural language (`run_gcloud_command`) |
| **gcp-observability** | `@google-cloud/observability-mcp` | Logs, metrics, traces in your GCP project |
| **gcp-storage** | `@google-cloud/storage-mcp` | GCS buckets/objects (model weights, exports) |

Requires **Node.js 20+** and **gcloud** on PATH for the `npx` servers.

## 1. Developer Knowledge API key

```powershell
gcloud config set project project-a625d19b-de99-48e9-9a9
gcloud services enable developerknowledge.googleapis.com --quiet
```

Create an API key restricted to **Developer Knowledge API** in [Credentials](https://console.cloud.google.com/apis/credentials?project=project-a625d19b-de99-48e9-9a9).

Set user env var (Windows):

```powershell
[System.Environment]::SetEnvironmentVariable(
  "GOOGLE_DEVELOPER_KNOWLEDGE_API_KEY", "YOUR_KEY", "User")
```

Optional (gcloud beta):

```powershell
gcloud components install beta
gcloud beta services mcp enable developerknowledge.googleapis.com --project=project-a625d19b-de99-48e9-9a9
```

## 2. gcloud MCP auth

Uses your active gcloud account (same as CLI):

```powershell
gcloud auth login
gcloud config set project project-a625d19b-de99-48e9-9a9
```

## 3. Install

```powershell
cd e:\devup\speech-mvp
copy .cursor\mcp.json.example .cursor\mcp.json
# Set GOOGLE_DEVELOPER_KNOWLEDGE_API_KEY, restart Cursor
```

Do **not** commit API keys. Use `%USERPROFILE%\.cursor\mcp.json` for keys if you prefer.

## Related

- [Cloud Build setup](../infra/ci/cloud-build-terraform.md)
- [Architecture review](architecture-review-gcp-2026.md)
