variable "project_id" {
  description = "GCP project id for this environment (create one project per env for IAM isolation)."
  type        = string
}

variable "region" {
  description = "Primary region for regional resources (Cloud SQL, Run, Artifact Registry, KMS, GKE)."
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
  description = "When true, Terraform can delete GCS buckets even if they contain objects. Use true for dev only."
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

variable "jurisdiction" {
  description = "Data residency jurisdiction for this stack: uk or us."
  type        = string

  validation {
    condition     = contains(["uk", "us"], var.jurisdiction)
    error_message = "jurisdiction must be uk or us."
  }
}

variable "inference_enabled" {
  description = "Provision GKE + vLLM (Gemma 3 27B). Enable in phase 2 after core infra and GPU quota."
  type        = bool
  default     = false
}

variable "model_gcs_prefix" {
  description = "GCS prefix under models bucket for Gemma weights."
  type        = string
  default     = "gemma-3-27b-it"
}

variable "vllm_container_image" {
  description = "vLLM image in Artifact Registry (required when inference_enabled)."
  type        = string
  default     = ""
}

variable "inference_zone" {
  description = "GPU zone (default {region}-b)."
  type        = string
  default     = ""
}

variable "inference_gpu_machine_type" {
  type    = string
  default = "g2-standard-8"
}

variable "inference_node_pool_min_count" {
  type    = number
  default = 1
}

variable "inference_node_pool_max_count" {
  type    = number
  default = 1
}

variable "inference_deletion_protection" {
  type    = bool
  default = false
}
