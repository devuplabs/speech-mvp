provider "google" {
  project = var.project_id
  region  = var.region
}

module "stack" {
  source = "../../../modules/sona_environment"

  project_id   = var.project_id
  region       = var.region
  environment  = var.environment
  jurisdiction = var.jurisdiction
  name_prefix  = var.name_prefix

  gcs_bucket_force_destroy = var.gcs_bucket_force_destroy

  db_tier                = var.db_tier
  db_edition             = var.db_edition
  db_disk_size_gb        = var.db_disk_size_gb
  db_high_availability   = var.db_high_availability
  db_deletion_protection = var.db_deletion_protection
  db_backup_enabled      = var.db_backup_enabled
  db_pitr_enabled        = var.db_pitr_enabled

  inference_enabled             = var.inference_enabled
  model_gcs_prefix              = var.model_gcs_prefix
  vllm_container_image          = var.vllm_container_image
  inference_zone                = var.inference_zone
  inference_gpu_machine_type    = var.inference_gpu_machine_type
  inference_node_pool_min_count = var.inference_node_pool_min_count
  inference_node_pool_max_count = var.inference_node_pool_max_count
  inference_deletion_protection = var.inference_deletion_protection

  # First AI loop — wire prep_brief through Vertex AI Gemini 2.5 in europe-west2.
  inference_openai_base_url_override = var.inference_openai_base_url_override
  llm_model                          = var.llm_model
  llm_enabled_kinds                  = var.llm_enabled_kinds
  grant_vertex_aiplatform_iam        = var.grant_vertex_aiplatform_iam
}
