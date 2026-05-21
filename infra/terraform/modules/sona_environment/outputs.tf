output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "jurisdiction" {
  value = var.jurisdiction
}

output "vpc_connector_name" {
  value = module.network.vpc_connector_name
}

output "vpc_connector_id" {
  value = module.network.vpc_connector_id
}

output "vpc_name" {
  value = module.network.vpc_name
}

output "cloud_sql_instance_connection_name" {
  value = module.cloud_sql.instance_connection_name
}

output "cloud_sql_private_ip" {
  value = module.cloud_sql.private_ip_address
}

output "cloud_sql_database" {
  value = module.cloud_sql.database_name
}

output "cloud_sql_app_user" {
  value = module.cloud_sql.db_user_name
}

output "db_password_secret_id" {
  value = module.cloud_sql.db_password_secret_id
}

output "postmark_secret_id" {
  value = google_secret_manager_secret.postmark_api_token.secret_id
}

output "exports_bucket_name" {
  value = module.storage.exports_bucket_name
}

output "models_bucket_name" {
  value = module.model_storage.models_bucket_name
}

output "models_bucket_url" {
  value = module.model_storage.models_bucket_url
}

output "runtime_service_account_email" {
  value = module.app_identity.runtime_service_account_email
}

output "artifact_registry_docker_url" {
  value = module.artifact_registry.docker_repository_url
}

output "kms_key_ring_id" {
  value = module.kms.key_ring_id
}

output "gcs_kms_crypto_key_id" {
  value = module.kms.gcs_crypto_key_id
}

output "llm_cloud_tasks_queue_name" {
  value = local.llm_queue_name
}

output "api_service_uri" {
  value = module.cloud_run.api_uri
}

output "worker_service_uri" {
  value = module.cloud_run.worker_uri
}

output "inference_cluster_name" {
  value = module.inference.cluster_name
}

output "inference_vllm_openai_base_url" {
  description = "Sona API INFERENCE_OPENAI_BASE_URL (may be empty until internal LB IP is ready)."
  value       = module.inference.vllm_openai_base_url
}

output "inference_model_gcs_uri" {
  value = module.inference.model_gcs_uri
}
