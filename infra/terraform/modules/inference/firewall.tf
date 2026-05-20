data "google_compute_network" "fw_vpc" {
  self_link = var.vpc_network_self_link
}

# Cloud Run (VPC connector) → vLLM internal load balancer
resource "google_compute_firewall" "allow_vpc_connector_to_vllm" {
  count = local.enabled_count

  name    = "${var.name_prefix}-allow-connector-vllm"
  network = data.google_compute_network.fw_vpc.name
  project = var.project_id

  direction = "INGRESS"
  priority  = 1000

  source_ranges = [var.vpc_connector_cidr]
  target_tags   = ["gke-inference"]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.vllm_service_port), "80", "443"]
  }
}

# Deny general internet egress from inference nodes (Private Google Access still works).
resource "google_compute_firewall" "deny_inference_egress_internet" {
  count = local.enabled_count

  name    = "${var.name_prefix}-deny-inference-egress-inet"
  network = data.google_compute_network.fw_vpc.name
  project = var.project_id

  direction = "EGRESS"
  priority  = 2000

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["gke-inference"]

  deny {
    protocol = "all"
  }
}

# Allow east-west within VPC (API connector, health checks, internal LB).
resource "google_compute_firewall" "allow_inference_internal" {
  count = local.enabled_count

  name    = "${var.name_prefix}-allow-inference-internal"
  network = data.google_compute_network.fw_vpc.name
  project = var.project_id

  direction = "INGRESS"
  priority  = 900

  source_ranges = [
    var.gke_subnet_cidr,
    var.vpc_connector_cidr,
    "172.16.0.0/28",
  ]
  target_tags = ["gke-inference"]

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }
}
