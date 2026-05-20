variable "project_id" { type = string }
variable "region" { type = string }
variable "llm_queue_name" {
  description = "Cloud Tasks queue name (created by cloud_run module)."
  type        = string
}
variable "runtime_service_account_email" { type = string }

resource "google_cloud_tasks_queue_iam_member" "runtime_enqueuer" {
  project  = var.project_id
  location = var.region
  name     = var.llm_queue_name
  role     = "roles/cloudtasks.enqueuer"
  member   = "serviceAccount:${var.runtime_service_account_email}"
}

output "llm_queue_name" {
  value = var.llm_queue_name
}

output "llm_queue_id" {
  value = "projects/${var.project_id}/locations/${var.region}/queues/${var.llm_queue_name}"
}
