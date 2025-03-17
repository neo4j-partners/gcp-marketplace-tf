# Neo4j Enterprise Terraform Module for GCP

This Terraform module deploys Neo4j Enterprise on Google Cloud Platform (GCP). It supports both standalone and clustered deployments.

## Features

- Deploys Neo4j Enterprise on GCP using Ubuntu 22.04 LTS
- Supports standalone or clustered deployments (1, 3, 4, 5, 6, or 7 nodes)
- Uses individual VMs instead of Managed Instance Groups
- Configures networking, firewall rules, and persistent storage
- Optional Neo4j Bloom installation
- Uses SSD persistent disks (pd-ssd) for optimal performance
- Available on GCP Marketplace
- Fully compliant with GCP Marketplace requirements (uses only approved providers)

## Repository Structure

```
neo4j-terraform-gcp/
├── modules/                          # Terraform modules
│   └── neo4j/                        # Main Neo4j module
│       ├── scripts/                  # Startup scripts for Neo4j
│       ├── main.tf                   # Main module configuration
│       ├── network.tf                # Network configuration
│       ├── variables.tf              # Module variables
│       ├── outputs.tf                # Module outputs
│       └── versions.tf               # Module provider requirements
├── test/                             # Test configurations
├── metadata.yaml                     # GCP Marketplace metadata
├── metadata.display.yaml             # GCP Marketplace display metadata
├── logo.png                          # Logo for GCP Marketplace
├── main.tf                           # Root module configuration
├── variables.tf                      # Root module variables
├── outputs.tf                        # Root module outputs
├── versions.tf                       # Provider and version constraints
└── terraform.tfvars.example          # Example variables file
```

## Prerequisites

- Terraform 1.2.0 or newer
- Google Cloud SDK
- A GCP project with billing enabled
- Appropriate permissions to create resources in GCP
- Default project configured in gcloud CLI (`gcloud config set project YOUR_PROJECT_ID`)

## Usage

### Option 1: Deploy from GCP Marketplace

1. Visit the [Neo4j Enterprise listing on GCP Marketplace](https://console.cloud.google.com/marketplace/product/neo4j-public/neo4j-enterprise)
2. Click "Launch"
3. Configure the deployment parameters
4. Review and Launch

### Option 2: Use the Module Directly

1. Ensure your default GCP project is set in gcloud CLI:
```bash
gcloud config set project YOUR_PROJECT_ID
```

2. Copy `terraform.tfvars.example` to `terraform.tfvars` and update the values
3. Initialize Terraform:

```bash
terraform init
```

4. Plan the deployment:

```bash
terraform plan
```

5. Apply the configuration:

```bash
terraform apply
```

## Module Configuration

The following variables can be configured in your `terraform.tfvars` file:

| Variable | Description | Default |
|----------|-------------|---------|
| project_id | GCP Project ID | (Required) |
| region | GCP Region | us-central1 |
| zone | GCP Zone | us-central1-a |
| deployment_name | Deployment name | neo4j |
| image | The VM image to use for Neo4j instances | projects/launcher-public/global/images/neo4j-enterprise-edition-byol-v20250305 |
| node_count | Number of Neo4j nodes | 3 |
| machine_type | GCP machine type | c3-standard-4 |
| disk_size | Data disk size in GB | 100 |
| disk_type | Type of disk to use | pd-ssd |
| admin_password | Neo4j admin password | (Required) |
| license_type | Neo4j license type (enterprise-byol or evaluation) | enterprise-byol |
| firewall_source_range | Source IP ranges for firewall rules (comma-separated) | 0.0.0.0/0 |

For a complete list of inputs, see the [variables.tf](./variables.tf) file.

> **Note for GCP Marketplace:** When deploying through GCP Marketplace, the `image` variable will be automatically set to the Marketplace-owned version of the VM image.

## Outputs

| Output | Description |
|--------|-------------|
| neo4j_url | URL to access Neo4j Browser |
| neo4j_bolt_url | Bolt URL for connecting to Neo4j |
| neo4j_ip_addresses | IP addresses of the Neo4j nodes |
| neo4j_instance_names | Names of the Neo4j instances |
| neo4j_instance_zones | Zones where Neo4j instances are deployed |
| neo4j_instance_machine_types | Machine types of Neo4j instances |

## Architecture

This module deploys:

1. A VPC network and subnetwork (optional)
2. Firewall rules for internal and external access
3. Neo4j VMs with attached persistent disks
4. Configures Neo4j for standalone or clustered operation

### Providers Used

This module only uses the following approved GCP Marketplace providers:
- google
- google-beta

## Testing

The module includes test configurations in the `test/` directory:

- `verify_module.sh`: Basic verification for GCP Marketplace
- `test_deployment.sh`: Comprehensive deployment testing using marketplace_test.tfvars

The test script performs thorough checks to verify:
- All instances are properly deployed
- Neo4j services are running and accessible
- Neo4j Browser and Bolt interfaces are operational
- Cluster configuration is properly set up

## Notes

- For production deployments, it's recommended to restrict the `firewall_source_range` to specific IP ranges
- The default machine type (c3-standard-4) is suitable for most workloads, but can be adjusted based on your requirements
- For large datasets, consider increasing the `disk_size` parameter
- The startup script includes robust error handling and non-interactive installation to ensure reliable deployment

## License

This module is licensed under the Apache License 2.0. 