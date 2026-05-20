variable "project_id" { type = string }
variable "region" { type = string }
variable "name_prefix" { type = string }

variable "vpc_connector_cidr" {
  description = "Dedicated /28 (or larger) for Serverless VPC Access; must not overlap SQL PSA range."
  type        = string
  default     = "10.8.0.0/28"
}

variable "sql_peering_address" {
  description = "Start of RFC1918 range reserved for Google managed services peering (Cloud SQL private IP)."
  type        = string
  default     = "10.20.0.0"
}

variable "sql_peering_prefix_length" {
  type    = number
  default = 16
}

resource "google_compute_network" "this" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_global_address" "google_managed_services" {
  name          = "${var.name_prefix}-psa-sql"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = var.sql_peering_address
  prefix_length = var.sql_peering_prefix_length
  network       = google_compute_network.this.id
  project       = var.project_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.google_managed_services.name]
}

resource "google_vpc_access_connector" "this" {
  name          = "${var.name_prefix}-vpc-cn"
  region        = var.region
  project       = var.project_id
  network       = google_compute_network.this.name
  ip_cidr_range = var.vpc_connector_cidr

  # GCP API requires either max_instances or max_throughput (see vpc-access connector create).
  min_instances = 2
  max_instances = 3

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
  ]
}

output "vpc_id" {
  value = google_compute_network.this.id
}

output "vpc_self_link" {
  value = google_compute_network.this.self_link
}

output "vpc_name" {
  value = google_compute_network.this.name
}

output "vpc_connector_id" {
  value = google_vpc_access_connector.this.id
}

output "vpc_connector_name" {
  value = google_vpc_access_connector.this.name
}
