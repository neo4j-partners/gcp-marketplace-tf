# Neo4j Enterprise Terraform Module for GCP

This Terraform module deploys Neo4j Enterprise on Google Cloud Platform (GCP). It supports both standalone and clustered deployments.

## Features

- Deploys Neo4j Enterprise on GCP using Ubuntu 22.04 LTS
- Supports standalone or clustered deployments (1, 3, 4, 5, 6, or 7 nodes)
- Uses individual VMs instead of Managed Instance Groups
- Configures networking, firewall rules, and persistent storage
- Optional Neo4j Bloom installation
- Uses pd-ssd
- Available on GCP Marketplace

## Repository Structure

```
neo4j-terraform-gcp/
├── modules/                           # Terraform modules
│   └── neo4j/                        # Main Neo4j module
├── test/                             # Test configurations
├── marketplace-metadata/             # GCP Marketplace metadata
├── main.tf                          # Root module configuration
├── variables.tf                     # Root module variables
├── outputs.tf                       # Root module outputs
├── versions.tf                      # Provider and version constraints
└── terraform.tfvars.example        # Example variables file
```

## Prerequisites

- Terraform 1.0.0 or newer
- Google Cloud SDK
- A GCP project with billing enabled
- Appropriate permissions to create resources in GCP

## Usage

### Option 1: Deploy from GCP Marketplace

1. Visit the [Neo4j Enterprise listing on GCP Marketplace](https://console.cloud.google.com/marketplace/product/neo4j-public/neo4j-enterprise)
2. Click "Launch"
3. Configure the deployment parameters
4. Review and Launch

### Option 2: Use the Module

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and update the values
2. Initialize Terraform:

```bash
terraform init
```

3. Plan the deployment:

```bash
terraform plan
```

4. Apply the configuration:

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
| environment | Environment label | dev |
| node_count | Number of Neo4j nodes | 3 |
| machine_type | GCP machine type | c3-standard-4 |
| disk_size | Data disk size in GB | 100 |
| admin_password | Neo4j admin password | (Required) |
| license_type | Neo4j license type (Commercial or Evaluation) | Evaluation |

For a complete list of inputs, see the [variables.tf](./variables.tf) file.

## Outputs

| Output | Description |
|--------|-------------|
| neo4j_urls | URLs to access Neo4j Browser |
| neo4j_bolt_endpoints | Bolt endpoints for Neo4j connections |
| neo4j_instance_names | Names of the Neo4j instances |
| neo4j_instance_ips | IP addresses of the Neo4j instances |

## Architecture

This module deploys:

1. A VPC network and subnetwork (optional)
2. Firewall rules for internal and external access
3. Neo4j VMs with attached persistent disks
4. Configures Neo4j for standalone or clustered operation

## Testing

The module includes test configurations in the `test/` directory:

- `verify_module.sh`: Basic verification for GCP Marketplace
- `test_deployment.sh`: Comprehensive deployment testing using marketplace_test.tfvars

## Notes

- For production deployments, it's recommended to restrict the `firewall_source_range` to specific IP ranges
- The default machine type (c3-standard-4) is suitable for most workloads, but can be adjusted based on your requirements
- For large datasets, consider increasing the `disk_size` parameter

## License

This module is licensed under the Apache License 2.0. 