variable "project_id" { type = string }
variable "region" { type = string }
variable "name_prefix" { type = string }
variable "environment" { type = string }
variable "jurisdiction" { type = string }

variable "runtime_service_account_email" { type = string }
variable "vpc_connector_id" { type = string }

variable "cloud_sql_connection_name" { type = string }
variable "cloud_sql_private_ip" { type = string }
variable "cloud_sql_database" { type = string }
variable "cloud_sql_app_user" { type = string }
variable "db_password_secret_resource_id" {
  description = "Full Secret Manager resource ID for DB password (Cloud Run secret_key_ref)."
  type        = string
}

variable "mailgun_api_key_secret_resource_id" {
  description = "Full Secret Manager resource ID for the Mailgun API key (Cloud Run secret_key_ref). Empty string leaves MAILGUN_API_KEY unset (email disabled)."
  type        = string
  default     = ""
}

variable "mailgun_domain" {
  description = "Mailgun sending domain (e.g. mg.yourdomain.com). Empty string leaves MAILGUN_DOMAIN unset (email disabled)."
  type        = string
  default     = ""
}

variable "mailgun_from_email" {
  description = "Verified Mailgun sender address for transactional email. Empty string leaves MAILGUN_FROM_EMAIL unset (email disabled)."
  type        = string
  default     = ""
}

variable "mailgun_base_url" {
  description = "Mailgun API region base, e.g. https://api.eu.mailgun.net for EU. Empty string defaults the API to US (https://api.mailgun.net)."
  type        = string
  default     = ""
}

variable "artifact_registry_docker_url" { type = string }

variable "api_image" {
  description = "Container image for API (and worker when using the same image)."
  type        = string
}

variable "inference_openai_base_url" {
  type    = string
  default = ""
}

variable "api_min_instances" {
  type    = number
  default = 0
}

variable "api_max_instances" {
  type    = number
  default = 3
}

variable "worker_min_instances" {
  type    = number
  default = 0
}

variable "worker_max_instances" {
  type    = number
  default = 2
}

variable "allow_unauthenticated_api" {
  description = "Dev only: public ingress for API (Flutter web / testing)."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Cloud Run deletion protection. false in dev so Terraform can replace services during bootstrap."
  type        = bool
  default     = false
}

variable "enable_web" {
  description = "Provision sona-web-{env} Cloud Run (Flutter web static nginx)."
  type        = bool
  default     = true
}

variable "web_image" {
  description = "Container image for Flutter web. Replaced by sona-web-dev-deploy; Terraform ignores tag changes."
  type        = string
}

variable "allow_unauthenticated_web" {
  description = "Dev only: public ingress for hosted Flutter web."
  type        = bool
  default     = true
}

variable "web_min_instances" {
  type    = number
  default = 0
}

variable "web_max_instances" {
  type    = number
  default = 3
}
