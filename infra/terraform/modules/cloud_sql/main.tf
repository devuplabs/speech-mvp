variable "project_id" { type = string }
variable "region" { type = string }
variable "name_prefix" { type = string }
variable "environment" { type = string }

variable "vpc_network_self_link" {
  description = "VPC self link for private IP Cloud SQL."
  type        = string
}

variable "tier" {
  description = "Cloud SQL machine tier (e.g. db-f1-micro for dev cost control)."
  type        = string
}

variable "edition" {
  description = "Cloud SQL edition. POSTGRES_16 defaults to ENTERPRISE_PLUS in the API; use ENTERPRISE for db-f1-micro / db-g1-small. Prod may use ENTERPRISE_PLUS with db-perf-optimized-* tiers."
  type        = string
  default     = "ENTERPRISE"
}

variable "disk_size_gb" {
  type    = number
  default = 10
}

variable "high_availability" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "backup_enabled" {
  type    = bool
  default = true
}

variable "pitr_enabled" {
  description = "Point-in-time recovery (requires backup_enabled)."
  type        = bool
  default     = true
}

variable "db_name" {
  type    = string
  default = "sona"
}

variable "db_user_name" {
  type    = string
  default = "sona_app"
}

resource "random_password" "db_app" {
  length  = 32
  special = false
}

resource "google_sql_database_instance" "this" {
  name             = "${var.name_prefix}-postgres"
  database_version = "POSTGRES_16"
  region           = var.region
  project          = var.project_id

  deletion_protection = var.deletion_protection

  settings {
    edition             = var.edition
    tier                = var.tier
    disk_autoresize     = true
    disk_size           = var.disk_size_gb
    disk_type           = startswith(var.tier, "db-f1-micro") ? "PD_HDD" : "PD_SSD"
    availability_type   = var.high_availability ? "REGIONAL" : "ZONAL"

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.vpc_network_self_link
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = var.backup_enabled
      point_in_time_recovery_enabled = var.pitr_enabled && var.backup_enabled
    }

    deletion_protection_enabled = var.deletion_protection
  }
}

resource "google_sql_database" "app" {
  name     = var.db_name
  instance = google_sql_database_instance.this.name
  project  = var.project_id
}

resource "google_sql_user" "app" {
  name     = var.db_user_name
  instance = google_sql_database_instance.this.name
  password = random_password.db_app.result
  project  = var.project_id
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.name_prefix}-db-app-password"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_app.result
}

output "instance_name" {
  value = google_sql_database_instance.this.name
}

output "instance_connection_name" {
  value = google_sql_database_instance.this.connection_name
}

output "private_ip_address" {
  value = google_sql_database_instance.this.private_ip_address
}

output "database_name" {
  value = google_sql_database.app.name
}

output "db_user_name" {
  value = google_sql_user.app.name
}

output "db_password_secret_id" {
  value = google_secret_manager_secret.db_password.secret_id
}

output "db_password_secret_resource_id" {
  value = google_secret_manager_secret.db_password.id
}
