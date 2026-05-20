terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.25.0, < 7.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

variable "project_id" {
  description = "GCP project id for this environment (one project per env recommended)."
  type        = string
}

variable "services" {
  description = "APIs to enable on the project before other resources."
  type        = list(string)
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

resource "google_project_service" "this" {
  for_each                   = toset(var.services)
  project                    = var.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}

output "enabled_services" {
  description = "Set of enabled service identifiers."
  value       = keys(google_project_service.this)
}
