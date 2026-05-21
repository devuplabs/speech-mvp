# Sona web E2E (Playwright)

Automated UI tests for the hosted Flutter web app. Replaces manual click-through after each deploy.

## Setup (once)

```bash
cd e2e
npm install
npx playwright install chromium
```

## Run against hosted dev

```bash
cd e2e
npm test
```

Optional env overrides:

```bash
SONA_WEB_URL=https://sona-web-dev-3rhenudy6a-nw.a.run.app \
SONA_API_URL=https://sona-api-dev-3rhenudy6a-nw.a.run.app \
npm test
```

## Run with browser visible (debug)

```bash
npm run test:headed
# or
npm run test:ui
```

## Tests

| File | What it checks |
|------|----------------|
| `tests/api-bootstrap.spec.ts` | Fast API-only: bootstrap 200/201, create case, save draft (no browser) |
| `tests/parent-intake-smoke.spec.ts` | Launcher → Get started → step 1; no `SonaApiException(200)` on screen |
| `tests/parent-intake-full.spec.ts` | All 8 steps + review consents + submit → success snackbar + welcome |

## Reports

After a run:

```bash
npm run report
```

## Notes

- First load can take **30–60s** (Flutter web WASM). Timeouts are set generously.
- Tests click **Enable accessibility** (Flutter web placeholder) so buttons/inputs appear in the DOM.
- Mobile viewport (430×932) matches the parent intake layout.
- If the UI changes heavily, update `helpers/intake-flow.ts`.
