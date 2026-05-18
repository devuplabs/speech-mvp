provider "google" {
  project = var.project_id
  region  = var.region
}

module "enable_apis" {
  source     = "../../../modules/enable_apis"
  project_id = var.project_id
}

module "network" {
  source      = "../../../modules/network"
  project_id  = var.project_id
  region      = var.region
  name_prefix = var.name_prefix

  depends_on = [module.enable_apis]
}

module "kms" {
  source      = "../../../modules/kms"
  project_id  = var.project_id
  region      = var.region
  name_prefix = var.name_prefix

  depends_on = [module.enable_apis]
}

module "app_identity" {
  source      = "../../../modules/app_identity"
  project_id  = var.project_id
  name_prefix = var.name_prefix
  environment = var.environment

  depends_on = [module.enable_apis]
}

module "artifact_registry" {
  source      = "../../../modules/artifact_registry"
  project_id  = var.project_id
  region      = var.region
  name_prefix = var.name_prefix

  depends_on = [module.enable_apis]
}

module "storage" {
  source         = "../../../modules/storage"
  project_id     = var.project_id
  region         = var.region
  environment    = var.environment
  jurisdiction   = var.jurisdiction
  gcs_kms_key_id = module.kms.gcs_crypto_key_id
  force_destroy  = var.gcs_bucket_force_destroy

  depends_on = [module.enable_apis, module.kms]
}

module "cloud_sql" {
  source                = "../../../modules/cloud_sql"
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

resource "google_storage_bucket_iam_member" "runtime_exports" {
  bucket = module.storage.exports_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.app_identity.runtime_service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "runtime_db_password" {
  project   = var.project_id
  secret_id = module.cloud_sql.db_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.app_identity.runtime_service_account_email}"
}
