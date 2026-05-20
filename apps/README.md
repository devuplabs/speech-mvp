# Sona applications

Monorepo layout. **Project tracker (Notion):** [Projects — Sona MVP board](https://www.notion.so/366c6894396e80fe993de778c796a932?v=366c6894396e80ad985e000c6e5a19f4) (Devup Teamspace).

| App | Status |
|-----|--------|
| `api/` | Scaffolded — Hono, health/ready, env config |
| `sona/` | Scaffolded — Flutter + GenUI deps, dev shell |

**One architecture** for dev, stage, and prod — see [ADR-004](../docs/decisions/004-unified-environments-access.md).

```
apps/
├── sona/                 # Flutter — parent (mobile/web) + clinician (web)
│   ├── lib/
│   │   ├── design_system/
│   │   ├── features/
│   │   └── genui/           # Sona catalog + A2uiAgentConnector → Sona API
│   └── pubspec.yaml         # genui, genui_a2a, a2a (no firebase_vertex_ai)
└── api/                  # Sona API — A2UI agent server + REST
    ├── src/
    │   ├── a2ui/            # A2UI stream handlers for Flutter
    │   └── llm/             # SelfHostedLlmClient → vLLM (Gemma 3 27B IT)
    └── openapi.yaml
```

## Stack

| ADR | Topic |
|-----|--------|
| [002](../docs/decisions/002-flutter-genui-client.md) | Flutter + GenUI A2UI → API |
| [003](../docs/decisions/003-self-hosted-llm-air-gap.md) | Air-gap inference (GKE/GCE) |
| [004](../docs/decisions/004-unified-environments-access.md) | Dev = prod topology; prod IAM lockdown |

## Bootstrap (when ready)

```bash
cd apps/sona
flutter create . --org com.devuplabs.sona
dart pub add genui genui_a2a a2a

cd apps/api
npm init -y && npm install hono zod
```

**Environment URLs:** configure `SONA_API_BASE_URL` per flavor (dev / stage / prod) — same app binaries, different endpoint.

**Do not add:** `firebase_vertex_ai`, `genui_google_generative_ai`, or Vertex client SDKs to Flutter.

## Deploy

| Artifact | Target |
|----------|--------|
| API + workers | Artifact Registry → Cloud Run |
| Inference | GKE + vLLM, `google/gemma-3-27b-it` (weights in GCS CMEK) |
| Flutter web | `flutter build web` → GCS+CDN or Firebase Hosting |

Prod deploy: Cloud Build SA only — no developer kubectl/console on prod ([ADR-004](../docs/decisions/004-unified-environments-access.md)).
