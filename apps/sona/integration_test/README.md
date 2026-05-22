# `apps/sona/integration_test/`

Reserved for `package:integration_test`-based parent-intake suites that run on
real Chrome via `chromedriver` (Option A in the
"Automate Flutter UI E2E for parent intake" Notion task).

Today the regression net for the parent-intake step 1 page 1 → page 2 → step 2
transition lives at
`apps/sona/test/widget/parent_intake_full_flow_test.dart`. It runs in the
standard Dart VM under `flutter test` and walks the real `SonaApp` end to end
via `WidgetTester.enterText` against a `MockClient`-backed `SonaApiClient`.

## Running an integration_test under chromedriver

When a CI image with chromedriver is wired up, drop a sibling test file
beside this README that imports `package:integration_test/integration_test.dart`,
calls `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`, and reuses
the same `_FakeBackend`/`_enterByLabel`/etc helpers from the widget test (or
extracts them into a shared `lib/test/` library). Then run:

```bash
chromedriver --port=4444 &
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/parent_intake_full_test.dart \
  -d web-server --browser-name=chrome --headless --web-port=8090
```

`test_driver/integration_test.dart` and the `integration_test` dev dependency
are already in place to make that drop-in possible.
