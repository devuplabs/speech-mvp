output "project_id" {
  value = module.stack.project_id
}

output "region" {
  value = module.stack.region
}

output "jurisdiction" {
  value = module.stack.jurisdiction
}

output "vpc_connector_name" {
  description = "Cloud Run: vpc-access-connector."
  value       = module.stack.vpc_connector_name
}

output "vpc_connector_id" {
  value = module.stack.vpc_connector_id
}

output "vpc_name" {
  value = module.stack.vpc_name
}

output "cloud_sql_instance_connection_name" {
  value = module.stack.cloud_sql_instance_connection_name
}

output "cloud_sql_private_ip" {
  value = module.stack.cloud_sql_private_ip
}

output "cloud_sql_database" {
  value = module.stack.cloud_sql_database
}

output "cloud_sql_app_user" {
  value = module.stack.cloud_sql_app_user
}

output "db_password_secret_id" {
  value = module.stack.db_password_secret_id
}

output "exports_bucket_name" {
  value = module.stack.exports_bucket_name
}

output "models_bucket_name" {
  value = module.stack.models_bucket_name
}

output "models_bucket_url" {
  value = module.stack.models_bucket_url
}

output "runtime_service_account_email" {
  value = module.stack.runtime_service_account_email
}

output "artifact_registry_docker_url" {
  value = module.stack.artifact_registry_docker_url
}

output "kms_key_ring_id" {
  value = module.stack.kms_key_ring_id
}

output "gcs_kms_crypto_key_id" {
  value = module.stack.gcs_kms_crypto_key_id
}

output "llm_cloud_tasks_queue_name" {
  value = module.stack.llm_cloud_tasks_queue_name
}

output "inference_cluster_name" {
  value = module.stack.inference_cluster_name
}

output "inference_vllm_openai_base_url" {
  description = "Set on Sona API as INFERENCE_OPENAI_BASE_URL."
  value       = module.stack.inference_vllm_openai_base_url
}

output "inference_model_gcs_uri" {
  value = module.stack.inference_model_gcs_uri
}
