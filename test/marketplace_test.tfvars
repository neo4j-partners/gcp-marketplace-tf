project_id       = "launcher-development-191917"
region           = "us-central1"
zone             = "us-central1-a"
network_name     = "test-network"
subnetwork_name  = "test-subnet"
create_network   = true
subnetwork_cidr  = "10.10.10.0/24"
node_count       = 3
machine_type     = "c3-standard-4"
disk_size        = 100
admin_password   = "TestPassword123!"
install_bloom    = false
bloom_license_key = ""
firewall_source_range = "0.0.0.0/0"
license_type = "enterprise-byol"