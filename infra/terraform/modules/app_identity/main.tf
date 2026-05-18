variable "project_id" { type = string }
variable "name_prefix" { type = string }
variable "environment" { type = string }

resource "google_service_account" "runtime" {
  account_id   = "${var.name_prefix}-run"
  display_name = "Sona Cloud Run runtime (${var.environment})"
  project      = var.project_id
}

resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

output "runtime_service_account_email" {
  value = google_service_account.runtime.email
}

output "runtime_service_account_id" {
  value = google_service_account.runtime.id
}
