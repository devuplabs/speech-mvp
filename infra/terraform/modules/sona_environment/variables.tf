variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "jurisdiction" { type = string }
variable "name_prefix" {
  type    = string
  default = "sona"
}

variable "enabled_apis" {
  type = list(string)
  default = [
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "vpcaccess.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
    "cloudkms.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "cloudtasks.googleapis.com",
  ]
}

variable "vpc_connector_cidr" {
  type    = string
  default = "10.8.0.0/28"
}

variable "gcs_bucket_force_destroy" {
  type    = bool
  default = false
}

variable "db_tier" { type = string }

variable "db_edition" {
  description = "Cloud SQL edition (ENTERPRISE for dev micro tiers; ENTERPRISE_PLUS for prod perf tiers)."
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

variable "inference_enabled" {
  description = "Provision GKE + vLLM. Default false for MVP bootstrap; enable when GPU/model ready."
  type        = bool
  default     = false
}

variable "model_gcs_prefix" {
  type    = string
  default = "gemma-3-27b-it"
}

variable "vllm_container_image" {
  description = "vLLM OpenAI image in Artifact Registry (required when inference_enabled)."
  type        = string
  default     = ""

  validation {
    condition     = !var.inference_enabled || length(var.vllm_container_image) > 0
    error_message = "Set vllm_container_image when inference_enabled is true (mirror vllm/vllm-openai to Artifact Registry first)."
  }
}

variable "inference_zone" {
  description = "Zone for GPU node pool (e.g. europe-west2-b)."
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

variable "gke_master_authorized_cidrs" {
  description = "CIDRs for GKE control plane access (Terraform applies Kubernetes resources). Use a VPN CIDR in prod instead of 0.0.0.0/0."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}


variable "cloud_run_bootstrap_image" {
  description = "Placeholder Cloud Run image for first Terraform apply (before sona-api is built). Cloud Build replaces it; Terraform ignores image changes."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "api_container_image" {
  description = "Override Cloud Run image for API and worker. Leave null to use cloud_run_bootstrap_image until Cloud Build deploys sona-api."
  type        = string
  default     = null
}

variable "cloud_run_enable_web" {
  description = "Provision sona-web-{env} for hosted Flutter web."
  type        = bool
  default     = true
}

variable "web_bootstrap_image" {
  description = "Placeholder Cloud Run image for web until sona-web is built (nginx serves empty site until Cloud Build deploy)."
  type        = string
  default     = "nginx:alpine"
}

variable "web_container_image" {
  description = "Override Cloud Run image for Flutter web. Leave null to use web_bootstrap_image until Cloud Build deploys sona-web."
  type        = string
  default     = null
}

variable "cloud_run_deletion_protection" {
  description = "Cloud Run deletion protection. Keep false in dev; enable in prod."
  type        = bool
  default     = false
}

variable "cloud_run_allow_unauthenticated" {
  description = "Allow public invoke on API service (dev Flutter web). Disable in prod."
  type        = bool
  default     = true
}

variable "mailgun_api_key" {
  description = "Mailgun API key for transactional email (clinician invites). Supply at apply time (e.g. TF_VAR_mailgun_api_key) — never commit. Empty string disables email and creates no secret."
  type        = string
  default     = ""
  sensitive   = true
}

variable "mailgun_domain" {
  description = "Mailgun sending domain (e.g. mg.yourdomain.com). Empty string disables email."
  type        = string
  default     = ""
}

variable "mailgun_from_email" {
  description = "Verified Mailgun sender address for transactional email. Empty string disables email."
  type        = string
  default     = ""
}

variable "mailgun_base_url" {
  description = "Mailgun API region base, e.g. https://api.eu.mailgun.net for EU. Empty defaults to US."
  type        = string
  default     = ""
}
