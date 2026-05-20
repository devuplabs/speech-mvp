variable "enabled" {
  description = "When false, skip GKE/vLLM resources (avoids count on this module, which uses a kubernetes provider)."
  type        = bool
  default     = true
}

variable "project_id" { type = string }
variable "region" { type = string }
variable "name_prefix" { type = string }
variable "environment" { type = string }

variable "vpc_id" {
  description = "VPC network id from the network module (avoids data source lookup before first apply)."
  type        = string
}

variable "vpc_network_name" {
  description = "VPC network name (for firewall rules)."
  type        = string
}
variable "vpc_connector_cidr" {
  description = "CIDR for Serverless VPC Access (source for API → vLLM firewall rule)."
  type        = string
}

variable "models_bucket_name" { type = string }
variable "model_gcs_prefix" {
  description = "Object prefix in the models bucket (e.g. gemma-3-27b-it/). Upload AWQ weights here before first deploy."
  type        = string
  default     = "gemma-3-27b-it"
}

variable "vllm_container_image" {
  description = "vLLM OpenAI-compatible image in Artifact Registry (mirror vllm/vllm-openai — no Docker Hub in air-gap)."
  type        = string
}

variable "inference_zone" {
  description = "Zone for the GPU node pool (must have L4 quota)."
  type        = string
}

variable "gke_subnet_cidr" {
  type    = string
  default = "10.10.0.0/24"
}

variable "gke_pods_cidr" {
  type    = string
  default = "10.11.0.0/20"
}

variable "gke_services_cidr" {
  type    = string
  default = "10.12.0.0/24"
}

variable "gpu_machine_type" {
  type    = string
  default = "g2-standard-8"
}

variable "gpu_accelerator_type" {
  type    = string
  default = "nvidia-l4"
}

variable "gpu_accelerator_count" {
  type    = number
  default = 1
}

variable "node_pool_min_count" {
  type    = number
  default = 1
}

variable "node_pool_max_count" {
  type    = number
  default = 1
}

variable "vllm_service_port" {
  type    = number
  default = 8000
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "master_authorized_cidrs" {
  description = "CIDRs allowed to reach the GKE control plane (for Terraform/kubernetes provider). Tighten in prod (e.g. Cloud Build private pool / VPN)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
