variable "project_id" {
  description = "GCP project id for this environment (create one project per env for IAM isolation)."
  type        = string
}

variable "region" {
  description = "Primary region for regional resources (Cloud SQL, Run, Artifact Registry, KMS)."
  type        = string
}

variable "environment" {
  description = "Short environment label used in resource names (e.g. dev, stage, prod)."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for human-readable resource names inside the project."
  type        = string
  default     = "sona"
}

variable "gcs_bucket_force_destroy" {
  description = "When true, Terraform can delete the exports bucket even if it contains objects. Use true for dev only."
  type        = bool
  default     = false
}

variable "db_tier" {
  description = "Cloud SQL machine type."
  type        = string
}

variable "db_disk_size_gb" {
  type    = number
  default = 10
}

variable "db_high_availability" {
  type    = bool
  default = false
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_backup_enabled" {
  type    = bool
  default = true
}

variable "db_pitr_enabled" {
  type    = bool
  default = true
}
