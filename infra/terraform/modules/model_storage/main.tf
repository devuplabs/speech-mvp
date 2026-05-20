variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "jurisdiction" { type = string }
variable "gcs_kms_key_id" { type = string }
variable "force_destroy" {
  type    = bool
  default = false
}

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  bucket_name = "${var.project_id}-sona-models-${var.jurisdiction}-${var.environment}"
}

resource "google_storage_bucket" "models" {
  name                        = local.bucket_name
  location                    = var.region
  project                     = var.project_id
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy

  encryption {
    default_kms_key_name = var.gcs_kms_key_id
  }

  versioning {
    enabled = true
  }
}

resource "google_kms_crypto_key_iam_member" "gcs_service_agent" {
  crypto_key_id = var.gcs_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.this.number}@gs-project-accounts.iam.gserviceaccount.com"
}

output "models_bucket_name" {
  value = google_storage_bucket.models.name
}

output "models_bucket_url" {
  value = google_storage_bucket.models.url
}
