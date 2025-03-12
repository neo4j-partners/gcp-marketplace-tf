module "neo4j" {
  source = "./modules/neo4j"

  region                = var.region
  zone                  = var.zone
  deployment_name       = var.deployment_name
  network_name          = var.network_name
  subnetwork_name       = var.subnetwork_name
  create_network        = var.create_network
  subnetwork_cidr       = var.subnetwork_cidr
  node_count            = var.node_count
  machine_type          = var.machine_type
  disk_size             = var.disk_size
  admin_password        = var.admin_password
  install_bloom         = var.install_bloom
  bloom_license_key     = var.bloom_license_key
  firewall_source_range = var.firewall_source_range
  license_type          = var.license_type
} 