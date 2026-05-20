terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.25.0, < 7.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

module "enable_apis" {
  source     = "../enable_apis"
  project_id = var.project_id
  services   = var.enabled_apis
}

module "network" {
  source             = "../network"
  project_id         = var.project_id
  region             = var.region
  name_prefix        = var.name_prefix
  vpc_connector_cidr = var.vpc_connector_cidr

  depends_on = [module.enable_apis]
}

module "kms" {
  source      = "../kms"
  project_id  = var.project_id
  region      = var.region
  name_prefix = var.name_prefix

  depends_on = [module.enable_apis]
}

module "app_identity" {
  source      = "../app_identity"
  project_id  = var.project_id
  name_prefix = var.name_prefix
  environment = var.environment

  depends_on = [module.enable_apis]
}

module "artifact_registry" {
  source      = "../artifact_registry"
  project_id  = var.project_id
  region      = var.region
  name_prefix = var.name_prefix

  depends_on = [module.enable_apis]
}

module "storage" {
  source         = "../storage"
  project_id     = var.project_id
  region         = var.region
  environment    = var.environment
  jurisdiction   = var.jurisdiction
  gcs_kms_key_id = module.kms.gcs_crypto_key_id
  force_destroy  = var.gcs_bucket_force_destroy

  depends_on = [module.enable_apis, module.kms]
}

module "model_storage" {
  source         = "../model_storage"
  project_id     = var.project_id
  region         = var.region
  environment    = var.environment
  jurisdiction   = var.jurisdiction
  gcs_kms_key_id = module.kms.gcs_crypto_key_id
  force_destroy  = var.gcs_bucket_force_destroy

  depends_on = [module.enable_apis, module.kms]
}

module "cloud_sql" {
  source                = "../cloud_sql"
  project_id            = var.project_id
  region                = var.region
  name_prefix           = var.name_prefix
  environment           = var.environment
  vpc_network_self_link = module.network.vpc_self_link
  tier                  = var.db_tier
  disk_size_gb          = var.db_disk_size_gb
  high_availability     = var.db_high_availability
  deletion_protection   = var.db_deletion_protection
  backup_enabled        = var.db_backup_enabled
  pitr_enabled          = var.db_pitr_enabled

  depends_on = [module.enable_apis, module.network]
}

module "cloud_tasks" {
  source                        = "../cloud_tasks"
  project_id                    = var.project_id
  region                        = var.region
  name_prefix                   = var.name_prefix
  environment                   = var.environment
  runtime_service_account_email = module.app_identity.runtime_service_account_email

  depends_on = [module.enable_apis]
}

locals {
  inference_zone = var.inference_zone != "" ? var.inference_zone : "${var.region}-b"
}

module "inference" {
  source = "../inference"

  enabled               = var.inference_enabled
  project_id            = var.project_id
  region                = var.region
  name_prefix           = var.name_prefix
  environment           = var.environment
  vpc_network_name      = module.network.vpc_name
  vpc_network_self_link = module.network.vpc_self_link
  vpc_connector_cidr    = var.vpc_connector_cidr
  models_bucket_name    = module.model_storage.models_bucket_name
  model_gcs_prefix      = var.model_gcs_prefix
  vllm_container_image  = var.vllm_container_image
  inference_zone        = local.inference_zone
  gpu_machine_type        = var.inference_gpu_machine_type
  node_pool_min_count     = var.inference_node_pool_min_count
  node_pool_max_count     = var.inference_node_pool_max_count
  deletion_protection       = var.inference_deletion_protection
  master_authorized_cidrs = var.gke_master_authorized_cidrs
}

resource "google_storage_bucket_iam_member" "runtime_exports" {
  bucket = module.storage.exports_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.app_identity.runtime_service_account_email}"
}

resource "google_storage_bucket_iam_member" "runtime_models_reader" {
  bucket = module.model_storage.models_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${module.app_identity.runtime_service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "runtime_db_password" {
  project   = var.project_id
  secret_id = module.cloud_sql.db_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.app_identity.runtime_service_account_email}"
}
