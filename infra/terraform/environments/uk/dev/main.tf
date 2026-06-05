provider "google" {
  project = var.project_id
  region  = var.region
}

# Required for Firebase project + web app registration (firebase_auth module).
provider "google-beta" {
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
}

# Firebase Authentication (Identity Platform) — Auth·01 / Feature 2.
module "firebase_auth" {
  source = "../../../modules/firebase_auth"

  providers = {
    google      = google
    google-beta = google-beta
  }

  project_id                    = var.project_id
  runtime_service_account_email = module.stack.runtime_service_account_email
  region                        = var.region
  name_prefix                   = var.name_prefix

  # Allow sign-in / email-link completion from the hosted web UI + localhost dev.
  authorized_domains = compact([
    "localhost",
    replace(replace(module.stack.web_service_uri, "https://", ""), "http://", ""),
  ])

  # Mirror the 5 Firebase Web client-config values into Secret Manager so the
  # sona-web-dev-deploy Cloud Build pipeline reads them via availableSecrets
  # rather than substitutions. The Cloud Build SA below already runs the
  # web trigger (see infra/ci/triggers/sona-web-dev-deploy.yaml).
  publish_web_config_secrets = var.publish_firebase_web_config_secrets
  cloudbuild_secret_accessor_emails = var.publish_firebase_web_config_secrets ? [
    var.cloudbuild_service_account_email,
  ] : []
}
