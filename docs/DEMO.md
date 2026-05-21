# Sona MVP — working demo

End-to-end **synthetic** flow on live **uk/dev** API (no Postmark, no GPU inference).

## Prerequisites

- API deployed: `https://sona-api-dev-3rhenudy6a-nw.a.run.app` (or your URL)
- Flutter SDK installed

## Run the client

```bash
cd apps/sona
flutter run -d chrome
# or: flutter run --dart-define=SONA_API_BASE_URL=https://your-api.run.app
```

## Demo flow (3 tabs)

| Tab | Steps |
|-----|--------|
| **Parent** | Submit intake → copy **Case ID** |
| **Clinician** | Paste case ID → Load case → see prep brief → Triage → **Publish parent summary** |
| **Parent view** | Paste case ID → **Open published summary** |

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
