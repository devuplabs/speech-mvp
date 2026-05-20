output "cluster_name" {
  value = var.enabled ? google_container_cluster.this[0].name : null
}

output "cluster_endpoint" {
  value = var.enabled ? google_container_cluster.this[0].endpoint : null
}

output "gke_subnet_name" {
  value = var.enabled ? google_compute_subnetwork.gke[0].name : null
}

output "gke_nodes_service_account_email" {
  value = var.enabled ? google_service_account.gke_nodes[0].email : null
}

output "vllm_namespace" {
  value = var.enabled ? kubernetes_namespace.vllm[0].metadata[0].name : null
}

output "vllm_internal_service_host" {
  description = "Hostname or IP of the internal LoadBalancer (populated after Service gets an IP — may require second apply)."
  value = var.enabled ? try(
    kubernetes_service.vllm[0].status[0].load_balancer[0].ingress[0].ip,
    ""
  ) : ""
}

output "vllm_openai_base_url" {
  description = "Set Sona API INFERENCE_OPENAI_BASE_URL to this value (http://<internal-ip>:8000/v1)."
  value = var.enabled && (
    length(try(kubernetes_service.vllm[0].status[0].load_balancer[0].ingress, [])) > 0 &&
    try(kubernetes_service.vllm[0].status[0].load_balancer[0].ingress[0].ip, "") != ""
  ) ? "http://${kubernetes_service.vllm[0].status[0].load_balancer[0].ingress[0].ip}:${var.vllm_service_port}/v1" : ""
}

output "model_gcs_uri" {
  value = "gs://${var.models_bucket_name}/${var.model_gcs_prefix}"
}
