locals {
  neo4j_image = "ubuntu-os-cloud/ubuntu-2204-lts"
  neo4j_tag   = "neo4j-${var.deployment_name}"
}

resource "google_compute_instance" "neo4j" {
  count        = var.node_count
  name         = "neo4j-${var.deployment_name}-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [local.neo4j_tag]

  boot_disk {
    initialize_params {
      image = local.neo4j_image
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = local.network_id
    subnetwork = local.subnetwork_id
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    startup-script = <<-EOF
#!/bin/bash
mkdir -p /opt/neo4j/scripts
cat > /opt/neo4j/scripts/startup.sh <<'SCRIPT'
${templatefile("${path.module}/scripts/startup.sh", {
  node_count        = var.node_count
  node_index       = count.index + 1
  admin_password   = var.admin_password
  install_bloom    = var.install_bloom ? "Yes" : "No"
  bloom_license_key = var.bloom_license_key
  deployment_name  = var.deployment_name
  project_id       = local.project_id
  license_type     = var.license_type
})}
SCRIPT
chmod +x /opt/neo4j/scripts/startup.sh
/opt/neo4j/scripts/startup.sh
EOF
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "logging-write", "monitoring-write"]
  }

  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [attached_disk]
  }
}

resource "google_compute_disk" "neo4j_data" {
  count = var.node_count
  name  = "neo4j-data-${var.deployment_name}-${count.index + 1}"
  type  = "pd-ssd"
  zone  = var.zone
  size  = var.disk_size

  labels = {
    deployment = var.deployment_name
  }
}

resource "google_compute_attached_disk" "neo4j_data_attachment" {
  count       = var.node_count
  disk        = google_compute_disk.neo4j_data[count.index].id
  instance    = google_compute_instance.neo4j[count.index].id
  device_name = "data-disk"
}

# Wait for Neo4j Bolt port to be available before considering deployment complete
resource "null_resource" "wait_for_bolt" {
  count = var.node_count

  triggers = {
    instance_id = google_compute_instance.neo4j[count.index].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.module}/scripts/wait-for-port.sh ${google_compute_instance.neo4j[count.index].network_interface[0].access_config[0].nat_ip} 7687 600"
  }

  depends_on = [
    google_compute_instance.neo4j,
    google_compute_attached_disk.neo4j_data_attachment
  ]
} 