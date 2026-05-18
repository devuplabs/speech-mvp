variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "gcs_kms_key_id" {
  description = "Full KMS crypto key resource id for bucket default encryption."
  type        = string
}

variable "force_destroy" {
  description = "Allow bucket delete with objects (dev only)."
  type        = bool
  default     = false
}

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  bucket_name = "${var.project_id}-sona-exports-${var.environment}"
}

resource "google_storage_bucket" "exports" {
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

output "exports_bucket_name" {
  value = google_storage_bucket.exports.name
}

output "exports_bucket_url" {
  value = google_storage_bucket.exports.url
}
