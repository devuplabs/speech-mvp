# Sona MVP — working demo

End-to-end **synthetic** flow on live **uk/dev** API (no Postmark, no GPU inference).

## Prerequisites

- API deployed: `https://sona-api-dev-3rhenudy6a-nw.a.run.app` (or your URL)
- Flutter SDK installed

## Run the client

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

Flutter web on `localhost` cannot call Cloud Run until the API is redeployed with CORS. For local dev, run the API on another port:

```bash
# Terminal 1 — API (needs DATABASE_URL in apps/api/.env)
cd apps/api
set PORT=8081
npm run dev

# Terminal 2 — Flutter
cd apps/sona
flutter run -d chrome --web-port=8080 --dart-define=SONA_API_BASE_URL=http://localhost:8081
```

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
