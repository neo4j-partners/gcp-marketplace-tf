locals {
  neo4j_tag   = "neo4j-${var.deployment_name}"
}

resource "google_compute_instance" "neo4j" {
  count        = var.node_count
  name         = "neo4j-${var.deployment_name}-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [local.neo4j_tag]
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = var.source_image
      size  = 20
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = var.create_network ? google_compute_network.neo4j_network[0].name : "default"
    subnetwork = var.create_network ? google_compute_subnetwork.neo4j_subnetwork[0].name : "default"
    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = templatefile("${path.module}/scripts/startup.sh", {
    node_count        = var.node_count
    node_index        = count.index + 1
    admin_password    = var.admin_password
    install_bloom     = var.install_bloom ? "Yes" : "No"
    bloom_license_key = var.bloom_license_key
    deployment_name   = var.deployment_name
    project_id        = var.project_id
    license_type      = var.license_type
  })

  service_account {
    scopes = ["compute-rw", "storage-ro", "logging-write", "monitoring-write"]
  }

  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [attached_disk]
  }
}

resource "google_compute_disk" "neo4j_data" {
  count   = var.node_count
  name    = "neo4j-data-${var.deployment_name}-${count.index + 1}"
  type    = "pd-ssd"
  size    = var.disk_size
  zone    = var.zone
  project = var.project_id

  labels = {
    deployment = var.deployment_name
  }
}

resource "google_compute_attached_disk" "neo4j_data_attachment" {
  count       = var.node_count
  disk        = google_compute_disk.neo4j_data[count.index].id
  instance    = google_compute_instance.neo4j[count.index].id
  device_name = "data-disk"
  project     = var.project_id
} 