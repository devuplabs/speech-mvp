# Postmark API token: secret shell created by Terraform; you add the token version manually.
resource "google_secret_manager_secret" "postmark_api_token" {
  project   = var.project_id
  secret_id = "${var.name_prefix}-postmark-api-token"

  replication {
    auto {}
  }

  depends_on = [module.enable_apis]
}

resource "google_secret_manager_secret_iam_member" "runtime_postmark" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.postmark_api_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.app_identity.runtime_service_account_email}"
}
