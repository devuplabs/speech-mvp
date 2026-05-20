variable "project_id" { type = string }
variable "region" { type = string }
variable "name_prefix" { type = string }
variable "environment" { type = string }
variable "runtime_service_account_email" { type = string }

resource "google_cloud_tasks_queue" "llm_jobs" {
  name     = "${var.name_prefix}-llm-${var.environment}"
  location = var.region
  project  = var.project_id

  rate_limits {
    max_dispatches_per_second = 10
    max_concurrent_dispatches = 5
  }

  retry_config {
    max_attempts       = 5
    max_retry_duration = "3600s"
    min_backoff        = "10s"
    max_backoff        = "300s"
  }
}

resource "google_cloud_tasks_queue_iam_member" "runtime_enqueuer" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_tasks_queue.llm_jobs.name
  role     = "roles/cloudtasks.enqueuer"
  member   = "serviceAccount:${var.runtime_service_account_email}"
}

output "llm_queue_name" {
  value = google_cloud_tasks_queue.llm_jobs.name
}

output "llm_queue_id" {
  value = google_cloud_tasks_queue.llm_jobs.id
}
