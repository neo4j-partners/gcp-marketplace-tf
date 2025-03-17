variable "project_id" {
  description = "The ID of the project in which to provision resources."
  type        = string
}

variable "license_type" {
  description = "Neo4j license type (enterprise-byol or evaluation)"
  type        = string
  default     = "enterprise-byol"
  validation {
    condition     = contains(["enterprise-byol", "evaluation"], var.license_type)
    error_message = "License type must be either 'enterprise-byol' (Bring Your Own License) or 'evaluation'."
  }
}

variable "region" {
  description = "The GCP region where resources will be created"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The zone for the solution to be deployed."
  type        = string
  default     = "us-central1-a"
}

variable "goog_cm_deployment_name" {
  description = "The name of the deployment and VM instances."
  type        = string
  default     = "neo4j"
}

variable "source_image" {
  description = "The image name for the disk for the VM instance."
  type        = string
  default     = "projects/launcher-public/global/images/neo4j-enterprise-edition-byol-v20250305"
}

variable "network_name" {
  description = "The name of the VPC network to use or create"
  type        = string
  default     = "neo4j-network"
}

variable "subnetwork_name" {
  description = "The name of the subnetwork to use or create"
  type        = string
  default     = "neo4j-subnet"
}

variable "create_network" {
  description = "Whether to create a new network or use an existing one"
  type        = bool
  default     = true
}

variable "subnetwork_cidr" {
  description = "CIDR range for the subnetwork"
  type        = string
  default     = "10.10.10.0/24"
}

variable "node_count" {
  description = "Number of Neo4j nodes to deploy"
  type        = number
  default     = 3
  validation {
    condition     = contains([1, 3, 4, 5, 6, 7], var.node_count)
    error_message = "Node count must be 1 (standalone) or 3-7 (cluster)."
  }
}

variable "machine_type" {
  description = "GCP machine type for Neo4j nodes"
  type        = string
  default     = "c3-standard-4"
}

variable "disk_size" {
  description = "Size of the data disk in GB"
  type        = number
  default     = 100
}

variable "admin_password" {
  description = "Password for the Neo4j admin user"
  type        = string
  sensitive   = true
  default     = "Neo4j1234" # Default for validation only, will be overridden by user input
}

variable "install_bloom" {
  description = "Whether to install Neo4j Bloom"
  type        = bool
  default     = false
}

variable "bloom_license_key" {
  description = "License key for Neo4j Bloom (if installing)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "firewall_source_range" {
  description = "Source IP ranges for external access"
  type        = string
  default     = "0.0.0.0/0"
} 