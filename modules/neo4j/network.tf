resource "google_compute_network" "neo4j_network" {
  count                   = var.create_network ? 1 : 0
  name                    = "neo4j-network"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "neo4j_subnetwork" {
  count         = var.create_network ? 1 : 0
  name          = "neo4j-subnet"
  network       = google_compute_network.neo4j_network[0].name
  ip_cidr_range = var.subnetwork_cidr
  region        = var.region
  project       = var.project_id
}

# For validation, we'll use a simple approach with hardcoded values
locals {
  network_name = "default"
  subnet_name = "default"
}

resource "google_compute_firewall" "neo4j_internal" {
  name    = "neo4j-internal-fw"
  network = var.create_network ? google_compute_network.neo4j_network[0].name : local.network_name
  project = var.project_id

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
  name    = "neo4j-external-fw"
  network = var.create_network ? google_compute_network.neo4j_network[0].name : local.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22", "7474", "7687"]
  }

  source_ranges = split(",", var.firewall_source_range)
  target_tags   = ["neo4j-${var.deployment_name}"]
} 