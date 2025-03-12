resource "google_compute_network" "neo4j_network" {
  count                   = var.create_network ? 1 : 0
  name                    = "${var.network_name}-${var.deployment_name}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "neo4j_subnetwork" {
  count         = var.create_network ? 1 : 0
  name          = "${var.subnetwork_name}-${var.deployment_name}"
  network       = google_compute_network.neo4j_network[0].id
  ip_cidr_range = var.subnetwork_cidr
  region        = var.region
}

locals {
  network_id    = var.create_network ? google_compute_network.neo4j_network[0].id : "projects/${local.project_id}/global/networks/${var.network_name}"
  subnetwork_id = var.create_network ? google_compute_subnetwork.neo4j_subnetwork[0].id : "projects/${local.project_id}/regions/${var.region}/subnetworks/${var.subnetwork_name}"
}

resource "google_compute_firewall" "neo4j_internal" {
  name    = "neo4j-internal-${var.deployment_name}"
  network = local.network_id

  allow {
    protocol = "tcp"
    ports    = ["5000", "6000", "7000", "7687", "7688"]
  }

  allow {
    protocol = "udp"
    ports    = ["5000", "6000", "7000"]
  }

  source_ranges = [var.subnetwork_cidr]
  target_tags   = ["neo4j-${var.deployment_name}"]
}

resource "google_compute_firewall" "neo4j_external" {
  name    = "neo4j-external-${var.deployment_name}"
  network = local.network_id

  allow {
    protocol = "tcp"
    ports    = ["22", "7474", "7687"]
  }

  source_ranges = var.firewall_source_range
  target_tags   = ["neo4j-${var.deployment_name}"]
} 