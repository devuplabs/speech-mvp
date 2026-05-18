terraform {
  required_version = ">= 1.5.0"

  # Remote state: pass bucket/prefix at init time (local + Cloud Build friendly).
  # Example: terraform init -backend-config-file=backend.hcl
  backend "gcs" {}

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
