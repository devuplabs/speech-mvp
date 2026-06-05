/**
 * Firebase Authentication (Identity Platform) — fully provisioned via Terraform,
 * no console steps (Auth·01 / Feature 2).
 *
 * - Enables the Identity Toolkit + Firebase Management APIs.
 * - Configures email/password and passwordless email-link (Magic Link) sign-in.
 * - Registers a Firebase Web App so the Flutter client can initialise the SDK.
 * - Grants the Cloud Run runtime SA `firebaseauth.admin` so the API can verify
 *   tokens and mint invite/credential links via ADC (no service-account keys,
 *   no secrets — token verification uses the runtime SA).
 */

resource "google_project_service" "identitytoolkit" {
  project            = var.project_id
  service            = "identitytoolkit.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "firebase" {
  project            = var.project_id
  service            = "firebase.googleapis.com"
  disable_on_destroy = false
}

# Initialise Identity Platform and its sign-in methods.
resource "google_identity_platform_config" "auth" {
  project = var.project_id

  authorized_domains = var.authorized_domains

  sign_in {
    allow_duplicate_emails = false

    email {
      enabled = true
      # false => passwordless email-link (Magic Link) is permitted alongside
      # email/password, per the spec's "Magic Link + password" recommendation.
      password_required = false
    }
  }

  depends_on = [google_project_service.identitytoolkit]
}

# Add Firebase features to the GCP project (required to register a web app).
resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id

  depends_on = [google_project_service.firebase]
}

# Web App registration — yields the client config (apiKey, appId, authDomain…).
resource "google_firebase_web_app" "sona" {
  provider        = google-beta
  project         = var.project_id
  display_name    = var.web_app_display_name
  deletion_policy = "DELETE"

  depends_on = [google_firebase_project.default]
}

data "google_firebase_web_app_config" "sona" {
  provider   = google-beta
  project    = var.project_id
  web_app_id = google_firebase_web_app.sona.app_id
}

# Runtime SA can verify tokens and manage Firebase Auth users / action links.
resource "google_project_iam_member" "runtime_firebaseauth_admin" {
  project = var.project_id
  role    = "roles/firebaseauth.admin"
  member  = "serviceAccount:${var.runtime_service_account_email}"
}

# ---------------------------------------------------------------------------
# Firebase Web client config in Secret Manager (Auth — Option A wiring)
# ---------------------------------------------------------------------------
# The 5 values below are PUBLIC client config — they ship inside the browser
# bundle when Flutter builds. Per the Firebase docs they are not secret.
# We still mirror them into Secret Manager so:
#   - The Cloud Build web pipeline reads them via `availableSecrets` instead
#     of substitutions (no plain values in the trigger YAML).
#   - Rotation lives in one place if the Firebase project is ever rebuilt.
#   - The value source stays Terraform → outputs of the live web app config.
#
# IAM grant: ONLY the Cloud Build SA needs to read these. The runtime SA is
# unrelated — it verifies tokens via ADC and never touches client config.

locals {
  publish_secrets = var.publish_web_config_secrets

  fb_web_secrets = local.publish_secrets ? {
    api_key             = data.google_firebase_web_app_config.sona.api_key
    app_id              = google_firebase_web_app.sona.app_id
    project_id          = google_firebase_project.default.project
    auth_domain         = data.google_firebase_web_app_config.sona.auth_domain
    messaging_sender_id = data.google_firebase_web_app_config.sona.messaging_sender_id
  } : {}

  # Stable secret IDs — kept human-readable so they're easy to spot in the
  # Cloud Console + cross-reference from cloudbuild.web.yaml.
  fb_secret_ids = {
    api_key             = "${var.name_prefix}-firebase-web-api-key"
    app_id              = "${var.name_prefix}-firebase-web-app-id"
    project_id          = "${var.name_prefix}-firebase-project-id"
    auth_domain         = "${var.name_prefix}-firebase-auth-domain"
    messaging_sender_id = "${var.name_prefix}-firebase-messaging-sender-id"
  }
}

resource "google_secret_manager_secret" "firebase_web" {
  for_each  = local.fb_web_secrets
  project   = var.project_id
  secret_id = local.fb_secret_ids[each.key]

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "firebase_web" {
  for_each    = local.fb_web_secrets
  secret      = google_secret_manager_secret.firebase_web[each.key].id
  secret_data = each.value
}

# Grant the Cloud Build SA(s) read access on each secret. Scoped per-secret
# (not project-wide) so the surface is the minimum needed for the web build.
resource "google_secret_manager_secret_iam_member" "firebase_web_accessor" {
  for_each = local.publish_secrets ? {
    for pair in setproduct(
      keys(local.fb_web_secrets),
      var.cloudbuild_secret_accessor_emails,
    ) :
    "${pair[0]}__${pair[1]}" => { key = pair[0], member = pair[1] }
  } : {}

  project   = var.project_id
  secret_id = google_secret_manager_secret.firebase_web[each.value.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.member}"
}
