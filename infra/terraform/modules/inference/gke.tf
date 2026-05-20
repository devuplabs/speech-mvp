data "google_client_config" "this" {}

data "google_compute_network" "vpc" {
  self_link = var.vpc_network_self_link
}

resource "google_compute_subnetwork" "gke" {
  name          = "${var.name_prefix}-gke-${var.environment}"
  ip_cidr_range = var.gke_subnet_cidr
  region        = var.region
  network       = data.google_compute_network.vpc.id
  project       = var.project_id

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.gke_pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.gke_services_cidr
  }
}

resource "google_service_account" "gke_nodes" {
  account_id   = "${var.name_prefix}-gke-nodes"
  display_name = "GKE inference nodes (${var.environment})"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "gke_nodes_models_reader" {
  bucket = var.models_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_ar_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_container_cluster" "this" {
  name     = "${var.name_prefix}-inference-${var.environment}"
  location = var.region
  project  = var.project_id

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = data.google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.gke.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    dynamic "cidr_block" {
      for_each = var.master_authorized_cidrs
      content {
        cidr_block   = cidr_block.value
        display_name = "authorized-${cidr_block.key}"
      }
    }
  }

  deletion_protection = var.deletion_protection

  depends_on = [
    google_compute_subnetwork.gke,
  ]
}

resource "google_container_node_pool" "gpu" {
  name     = "${var.name_prefix}-gpu-pool"
  location = var.inference_zone
  cluster  = google_container_cluster.this.name
  project  = var.project_id

  initial_node_count = var.node_pool_min_count

  autoscaling {
    min_node_count = var.node_pool_min_count
    max_node_count = var.node_pool_max_count
  }

  node_config {
    machine_type = var.gpu_machine_type
    disk_size_gb = 100
    disk_type    = "pd-balanced"

    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    guest_accelerator {
      type  = var.gpu_accelerator_type
      count = var.gpu_accelerator_count
      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels = {
      workload = "vllm"
    }

    tags = ["gke-inference", "sona-vllm"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_locations = [var.inference_zone]
}
