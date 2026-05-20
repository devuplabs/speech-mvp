output "cluster_name" {
  value = google_container_cluster.this.name
}

output "cluster_endpoint" {
  value = google_container_cluster.this.endpoint
}

output "gke_subnet_name" {
  value = google_compute_subnetwork.gke.name
}

output "gke_nodes_service_account_email" {
  value = google_service_account.gke_nodes.email
}

output "vllm_namespace" {
  value = kubernetes_namespace.vllm.metadata[0].name
}

output "vllm_internal_service_host" {
  description = "Hostname or IP of the internal LoadBalancer (populated after Service gets an IP — may require second apply)."
  value       = try(kubernetes_service.vllm.status[0].load_balancer[0].ingress[0].ip, "")
}

output "vllm_openai_base_url" {
  description = "Set Sona API INFERENCE_OPENAI_BASE_URL to this value (http://<internal-ip>:8000/v1)."
  value = (
    length(try(kubernetes_service.vllm.status[0].load_balancer[0].ingress, [])) > 0 &&
    try(kubernetes_service.vllm.status[0].load_balancer[0].ingress[0].ip, "") != ""
  ) ? "http://${kubernetes_service.vllm.status[0].load_balancer[0].ingress[0].ip}:${var.vllm_service_port}/v1" : ""
}

output "model_gcs_uri" {
  value = "gs://${var.models_bucket_name}/${var.model_gcs_prefix}"
}
