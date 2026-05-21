output "api_service_name" {
  value = google_cloud_run_v2_service.api.name
}

output "api_uri" {
  value = google_cloud_run_v2_service.api.uri
}

output "worker_service_name" {
  value = google_cloud_run_v2_service.worker.name
}

output "worker_uri" {
  value = google_cloud_run_v2_service.worker.uri
}

output "web_service_name" {
  value = var.enable_web ? google_cloud_run_v2_service.web[0].name : null
}

output "web_uri" {
  description = "Hosted Flutter web URL (browser demo)."
  value       = var.enable_web ? google_cloud_run_v2_service.web[0].uri : null
}
