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

variable "db_edition" {
  description = "Cloud SQL edition. ENTERPRISE allows db-f1-micro on POSTGRES_16; use ENTERPRISE_PLUS + perf tiers for prod."
  type        = string
  default     = "ENTERPRISE"
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

# ---- LLM inference (Vertex AI Gemini in europe-west2 — first AI loop) ----

variable "inference_openai_base_url_override" {
  description = "Override the GKE vLLM URL with an external OpenAI-compatible endpoint. For Vertex AI Gemini in europe-west2: 'https://europe-west2-aiplatform.googleapis.com/v1beta1/projects/<PROJECT>/locations/europe-west2/endpoints/openapi'."
  type        = string
  default     = ""
}

variable "llm_model" {
  description = "Model id sent to the chat-completions endpoint. Examples: 'google/gemini-2.5-flash' (cheap default), 'google/gemini-2.5-pro' (better quality), 'google/gemma-3-27b-it' (self-hosted vLLM)."
  type        = string
  default     = ""
}

variable "llm_enabled_kinds" {
  description = "AI draft kinds the LLM may generate. Empty string => app default (prep_brief only — the first AI loop). Use '*' to enable all four (prep_brief, session_plan, clinical_report, parent_summary)."
  type        = string
  default     = ""
}

variable "grant_vertex_aiplatform_iam" {
  description = "Grant the Cloud Run runtime SA roles/aiplatform.user. Set true together with a Vertex inference_openai_base_url_override."
  type        = bool
  default     = false
}
