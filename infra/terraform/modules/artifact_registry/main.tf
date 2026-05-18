variable "project_id" { type = string }
variable "region" { type = string }
variable "name_prefix" { type = string }

resource "google_artifact_registry_repository" "sona" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.name_prefix}-sona"
  format          = "DOCKER"
  description     = "Container images for Sona (Cloud Run)."
}

output "repository_id" {
  value = google_artifact_registry_repository.sona.repository_id
}

output "docker_repository_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.sona.repository_id}"
}
