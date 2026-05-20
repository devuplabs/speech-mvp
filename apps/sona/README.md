# Sona Flutter client

Parent (mobile/web) + clinician (web). GenUI A2UI → Sona API.

## Bootstrap (requires Flutter SDK 3.24+)

```bash
cd apps/sona
flutter create . --org com.devuplabs.sona
dart pub add genui genui_a2a a2a
```

Set `SONA_API_BASE_URL` per flavor (dev / stage / prod).

**Do not add:** `firebase_vertex_ai`, `genui_google_generative_ai`, or Vertex SDKs.

## Layout (after `flutter create`)

```
lib/
  design_system/
  features/
  genui/
```
