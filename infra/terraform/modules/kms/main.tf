variable "project_id" { type = string }
variable "region" { type = string }
variable "name_prefix" { type = string }

resource "google_kms_key_ring" "this" {
  name     = "${var.name_prefix}-ring"
  location = var.region
  project  = var.project_id
}

resource "google_kms_crypto_key" "gcs" {
  name            = "${var.name_prefix}-gcs"
  key_ring        = google_kms_key_ring.this.id
  rotation_period = "7776000s"
  purpose         = "ENCRYPT_DECRYPT"

  version_template {
    algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }
}

output "key_ring_id" {
  value = google_kms_key_ring.this.id
}

output "gcs_crypto_key_id" {
  value = google_kms_crypto_key.gcs.id
}
