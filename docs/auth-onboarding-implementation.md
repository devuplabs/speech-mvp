# Auth & Onboarding — backend foundation (Auth·02 / Auth·03 / Auth·04)

Implements the backend foundation for the multi-clinician / group-practice
onboarding flow from `Sona_Feature_Spec_v3` and the Figma "Sona — Auth &
Onboarding" file. This is the autonomous, DB-and-Firebase-independent slice;
live Firebase wiring is **Auth·01** and the Flutter screens are **Auth·06–14**.

## What landed

### Auth·02 — data model (`src/db/schema.ts`, `drizzle/0005_practice_and_users.sql`)
- A **tenant is a practice**. `tenants` gained `location`, `specialties`
  (jsonb), `mode` (`single|group`), and `seats`.
- New **`users`** table = one row per seat: `tenantId`, `firebaseUid` (null
  until the invite is accepted), `email`, `fullName`, `role` (`admin|clinician`),
  `status` (`invited|active|disabled`), timestamps. Email is unique per practice.
- New enums: `practice_mode`, `user_role`, `user_status`.
- Migration registered in `src/db/migrate.ts` (`MIGRATION_IDS`).
- **Shared patient access** comes for free: `cases` are already tenant-scoped,
  so every clinician in a practice sees the same patients (not siloed).

### Auth·03 — auth middleware & RBAC (`src/auth/`)
- `TokenVerifier` interface + `FirebaseTokenVerifier`. The verifier **fails
  closed** with `auth_not_configured` (HTTP 503) until Auth·01 wires the
  Firebase Admin SDK — no route can be reached without real verification.
- `requireIdentity` (token only) and `requireUser` (token → active `users`
  row) Hono middlewares; `requireRole(...)` guard.
- Pure, unit-tested guards in `rbac.ts`: `assertRole`, `assertSameTenant`,
  `seatsRemaining`, `canAddSeat`.
- `AuthError` → HTTP status mapping added to the global handler in `index.ts`.

### Auth·04 — onboarding API (`src/routes/practices.ts`, `src/services/practice.ts`, `src/schemas/practice.ts`)
Mounted at `/v1/practices`:
| Route | Screen | Guard |
| --- | --- | --- |
| `POST /v1/practices` | 01 Admin sign-up | valid Firebase token (no seat yet) |
| `PATCH /v1/practices/:id/plan` | 02 Plan & seats | active admin |
| `PATCH /v1/practices/:id` | 03 Practice config | active admin |
| `GET /v1/practices/:id/clinicians` | 04 Roster | active admin |
| `POST /v1/practices/:id/clinicians` | 04 Invite | active admin |
| `POST /v1/practices/:id/clinicians/import` | 04 CSV import | active admin |
| `POST /v1/practices/:id/activate` | 05 Go live | active admin |

Seat limits, cross-practice isolation, and email de-dupe are enforced in the
service layer.

## Firebase (Auth·01) — done via Terraform + ADC
Firebase Authentication is provisioned **entirely in Terraform**
(`infra/terraform/modules/firebase_auth`, wired into `environments/uk/dev`) —
no console steps:
- Identity Platform with email/password + passwordless email-link (Magic Link).
- A Firebase web app registration; client config (apiKey/appId/authDomain/…)
  is exposed as TF outputs for the Flutter build (these are public, not secret).
- Runtime SA granted `roles/firebaseauth.admin`.

`FirebaseTokenVerifier` (`src/auth/verifier.ts`) now calls
`firebase-admin verifyIdToken()` using **Application Default Credentials** — on
Cloud Run that is the runtime service account, so there is **no service-account
key and no secret to store**. It still fails closed (`auth_not_configured`)
when `GCP_PROJECT_ID` is unset. `GCP_PROJECT_ID` is already injected into the
API service by `modules/cloud_run`.

## Auth·05 — clinician invite & credential provisioning (done)
On invite, `services/clinician-provisioning.ts#dispatchClinicianInvite`:
1. creates (or reuses) the Firebase user for the clinician's email,
2. links it to the seat (`firebase_uid`),
3. generates a Firebase **set-password** action link (continue URL →
   `/auth/accept-invite`), and
4. emails it via Mailgun (`services/email.ts#sendClinicianInviteEmail`).

Best-effort: if Firebase/Mailgun is unconfigured it returns
`{ provisioned/emailSent: false }` without rolling back the seat — admins can
`POST /v1/practices/:id/clinicians/:userId/resend`. Uses the shared
`getAdminAuth(env)` (ADC) from `auth/verifier.ts` — no secrets. CSV import
dispatches an invite per imported row.

## Auth·06 — Flutter auth scaffolding (client primitives)
Additive, non-breaking foundation for the auth screens (`apps/sona`):
- `config/firebase_options.dart` — `FirebaseOptions` from **build-time
  `--dart-define`s** sourced from the `firebase_auth` Terraform outputs (public
  client config, not secrets). `isConfigured` is false for demo/test builds.
- `services/auth/auth_controller.dart` — `ChangeNotifier` over `FirebaseAuth`
  (auth state, `idToken()`, password sign-in, magic link, sign-out).
- `services/auth/authed_http_client.dart` — `http.BaseClient` that attaches
  `Authorization: Bearer <idToken>` to every request, so `SonaApiClient` gains
  auth without per-call changes.
- `app/auth_gate.dart` — gates authenticated surfaces; falls through to the
  existing app when Firebase isn't configured (keeps demo + widget tests green).
- `main.dart` — initialises Firebase only when configured and wires the
  token-injecting client.

Build wiring (CI injects the TF outputs):
```sh
flutter build web \
  --dart-define=FIREBASE_API_KEY="$(terraform output -raw firebase_web_api_key)" \
  --dart-define=FIREBASE_APP_ID="$(terraform output -raw firebase_web_app_id)" \
  --dart-define=FIREBASE_PROJECT_ID="$(terraform output -raw firebase_project_id)" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$(terraform output -raw firebase_auth_domain)" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$(terraform output -raw firebase_messaging_sender_id)"
```
> Not compiled in the dev container (no Flutter toolchain) — verify with
> `flutter pub get` + `flutter analyze` in CI. The login UI + forced route
> guards land in **Auth·12 / Auth·14**.

## Follow-ups (tracked in Notion)
- Demo seeding of an admin/clinician roster (optional).
- The patient-history import path stays gated pending GDPR review (**Auth·17**).

## Verification
`npm run typecheck`, `npm run build`, and `npm test` (30 tests) all pass.
The migration runs against Postgres on next deploy via `RUN_MIGRATIONS_ON_START`
(not exercised here — no local Postgres in the dev container).
