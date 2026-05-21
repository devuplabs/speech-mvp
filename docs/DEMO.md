# Sona MVP — working demo

End-to-end **synthetic** flow on live **uk/dev** API (no Postmark, no GPU inference).

## Prerequisites

- **Hosted demo (GCP):** [https://sona-web-dev-3rhenudy6a-nw.a.run.app](https://sona-web-dev-3rhenudy6a-nw.a.run.app) → API `https://sona-api-dev-3rhenudy6a-nw.a.run.app`
- **Local dev:** Flutter SDK installed

## Run the client

**Hosted (no localhost):** open [https://sona-web-dev-3rhenudy6a-nw.a.run.app](https://sona-web-dev-3rhenudy6a-nw.a.run.app)

**Local:**

```bash
cd apps/sona
flutter run -d chrome --web-port=8080
# or: flutter run --dart-define=SONA_API_BASE_URL=https://your-api.run.app
```

## Demo flow (Figma UI)

| Step | Action |
|------|--------|
| **Parent intake** | Welcome → Form → Review (check **all three** consent boxes) → **Submit** |
| **Clinician Today** | Dashboard lists cases from API; open prep for your child |
| **Prep → Triage → Publish** | Continue flow → publish parent summary |
| **Parent summary** | Bottom bar **Parent summary** after publish |

## Local API + browser (CORS)

Browsers block cross-origin calls unless the API allows your page origin explicitly.

**Production / Cloud Run:** set `CORS_ORIGINS` to your real app URLs only (comma-separated). Do not use localhost on deployed APIs.

**Local dev only** (`NODE_ENV=development`):

`DATABASE_URL` is required — without it `/v1/demo/bootstrap` and other data routes will not work.

1. Copy `apps/api/.env.example` → `apps/api/.env`
2. Start [Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/connect-auth-proxy) (connection name in `.env.example`)
3. Set `DATABASE_URL=postgresql://sona_app:PASSWORD@127.0.0.1:5432/sona`

```bash
# Terminal 1 — API (needs DATABASE_URL in apps/api/.env)
cd apps/api
set NODE_ENV=development
set CORS_ALLOW_LOCALHOST=true
set PORT=8081
npm run dev

# Terminal 2 — Flutter
cd apps/sona
flutter run -d chrome --web-port=8080 --dart-define=SONA_API_BASE_URL=http://localhost:8081
```

Optional explicit list instead of `CORS_ALLOW_LOCALHOST`: `CORS_ORIGINS=http://localhost:8080,http://127.0.0.1:8080`

**Browser shows 404 on `/v1/demo/bootstrap`:** the local API has no database. Use Cloud Run (`flutter run` without `SONA_API_BASE_URL`) or add `DATABASE_URL` as above.

## API shortcuts (curl)

```bash
API=https://sona-api-dev-3rhenudy6a-nw.a.run.app
TENANT=$(curl -s -X POST "$API/v1/demo/bootstrap" -H "Content-Type: application/json" -d "{}" | jq -r .tenantId)
CASE=$(curl -s -X POST "$API/v1/cases" -H "Content-Type: application/json" \
  -d "{\"tenantId\":\"$TENANT\",\"childDisplayName\":\"Demo\",\"parentEmail\":\"p@example.com\"}" | jq -r .id)
curl -s -X POST "$API/v1/cases/$CASE/intake" -H "Content-Type: application/json" \
  -d '{"answers":{"concerns":["speech_delay"]},"consentVersion":"demo"}'
curl -s "$API/v1/cases/$CASE" | jq '.case.status, .drafts[].kind'
```

## Parked (blocked) — expected gaps

- **GenUI branching intake** — generic JSON answers only until Monal co-design
- **Real LLM prep** — stub brief until GPU/inference phase 2
- **Magic-link auth / passkeys** — demo uses case UUID
- **Email/SMS notify** — portal only
- **DPIA / real PHI** — synthetic data only in dev
