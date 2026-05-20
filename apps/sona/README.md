# Sona Flutter client

Parent (mobile/web) + clinician (web). GenUI A2UI → Sona API.

## Prerequisites

- Flutter SDK 3.24+ (`flutter doctor`)
- On Windows: enable **Developer Mode** for plugin symlinks (Settings → System → For developers)

## Git (what we commit)

Tracked: `lib/`, `test/`, `web/`, `android/`, `ios/`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`.

Ignored (build/local): `.dart_tool/`, `build/`, generated plugin registrants, IDE files, desktop `linux/` / `macos/` / `windows/` (MVP targets are web + mobile only). Regenerate desktop with `flutter create . --platforms=windows,linux,macos` if needed.

## Run (dev API on localhost)

```bash
# Terminal 1 — API
cd apps/api && npm install && npm run dev

# Terminal 2 — Flutter
cd apps/sona
flutter pub get
flutter run -d chrome
# or: flutter run -d windows
```

Default API URL: `http://localhost:8080` (override below).

## API URL per environment

```bash
flutter run --dart-define=SONA_API_BASE_URL=https://your-dev-api.run.app
```

## Layout

```
lib/
  config/          # SONA_API_BASE_URL (dart-define)
  design_system/   # ThemeData / tokens
  features/        # Screens (home, intake, clinician, …)
  genui/           # A2uiAgentConnector → Sona API
```

## Bootstrap (already done)

```bash
flutter create . --org com.devuplabs.sona --project-name sona
dart pub add genui genui_a2a a2a
```

**Do not add:** `firebase_vertex_ai`, `genui_google_generative_ai`, or Vertex SDKs.
