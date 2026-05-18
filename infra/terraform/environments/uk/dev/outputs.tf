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
  description = "Use with Cloud Run: vpc-access-connector."
  value       = module.network.vpc_connector_name
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
  description = "Secret Manager secret id holding the generated DB password."
  value       = module.cloud_sql.db_password_secret_id
}

output "exports_bucket_name" {
  value = module.storage.exports_bucket_name
}

output "runtime_service_account_email" {
  description = "Attach to Cloud Run as the runtime service account."
  value       = module.app_identity.runtime_service_account_email
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
