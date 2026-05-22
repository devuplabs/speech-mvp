# `apps/sona/integration_test/`

Persona-driven, full-flow parent-intake integration test that's structurally
ready for chromedriver promotion in CI.

## Today's regression net (always runs in `flutter test`)

The fast safety net is in `apps/sona/test/widget/`:

| File | Coverage |
|---|---|
| `parent_intake_full_flow_test.dart` | Demo-blocker regression net (PR #21 / #22) — hardcoded happy path, kept as-is. |
| `parent_intake_personas_flow_test.dart` | **Persona loop** — runs every synthetic persona in `lib/test_utils/intake_personas.dart` through the full 8-step flow + submit. Adding a new persona auto-extends parent-intake coverage. Completes in < 10 s for all 4 personas locally. |

Both run under `flutter test` in the Dart VM — no browser, no chromedriver.

## Chromedriver-backed promotion (this folder)

`parent_intake_full_test.dart` is the same persona-driven flow under
`IntegrationTestWidgetsFlutterBinding`. It runs against real Chrome via
`chromedriver` once the CI image has it:

```bash
# Local one-off (Chrome + matching chromedriver must be installed):
chromedriver --port=4444 &
cd apps/sona
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/parent_intake_full_test.dart \
  -d web-server --browser-name=chrome --headless --web-port=8090
```

`test_driver/integration_test.dart` and the `integration_test` dev dependency
are already in place. CI promotion is tracked separately — once
`infra/ci/cloudbuild.web.yaml` (or a sibling job) installs chromedriver, this
flow can block deploys.

## Why two files (widget + integration_test)?

The widget test is the always-on regression net (Dart VM, < 10 s). The
integration_test mirror catches Flutter web–specific issues (accessibility
tree races, scroll/focus interplay) that the Dart VM can't reproduce. Together
they bracket the parent intake on both axes — keep them in sync as the form
evolves.
