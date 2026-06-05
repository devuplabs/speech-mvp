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
