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
