# Firebase Web App client config. These values are NOT secret — they are
# embedded in the shipped client bundle — so they are exposed as plain outputs
# for the web build/deploy to consume (no Secret Manager entry needed).
# Backend token verification uses ADC via the runtime SA, so there is no
# service-account key or API secret to store anywhere.

output "firebase_project_id" {
  value = google_firebase_project.default.project
}

output "web_app_id" {
  value = google_firebase_web_app.sona.app_id
}

output "web_api_key" {
  description = "Firebase Web API key (public client config, not a secret)."
  value       = data.google_firebase_web_app_config.sona.api_key
}

output "auth_domain" {
  value = data.google_firebase_web_app_config.sona.auth_domain
}

output "messaging_sender_id" {
  value = data.google_firebase_web_app_config.sona.messaging_sender_id
}

output "identity_platform_configured" {
  value = google_identity_platform_config.auth.id
}

# --- Secret Manager IDs for the Cloud Build web pipeline (Option A) ----------
# These are short secret IDs (e.g. "sona-firebase-web-api-key"), suitable for
# the `availableSecrets:` block of cloudbuild.web.yaml. Empty when
# publish_web_config_secrets = false.

output "firebase_web_secret_ids" {
  description = "Map of {api_key|app_id|project_id|auth_domain|messaging_sender_id} -> Secret Manager secret_id."
  value = {
    for k, s in google_secret_manager_secret.firebase_web : k => s.secret_id
  }
}

output "firebase_web_secret_resource_ids" {
  description = "Map of fully-qualified secret resource IDs (projects/.../secrets/...). Useful when wiring Cloud Run secret_key_ref."
  value = {
    for k, s in google_secret_manager_secret.firebase_web : k => s.id
  }
}
