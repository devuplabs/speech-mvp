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
variable "db_password_secret_id" { type = string }

variable "artifact_registry_docker_url" { type = string }

variable "api_image" {
  description = "Container image for API (and worker when using the same image)."
  type        = string
}

variable "llm_queue_name" {
  description = "Existing Cloud Tasks queue name (sona-llm-{env}). HTTP target is configured here."
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
