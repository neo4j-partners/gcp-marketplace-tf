variable "region" {
  description = "The GCP region where resources will be created"
  type        = string
}

variable "zone" {
  description = "The GCP zone where resources will be created"
  type        = string
}

variable "deployment_name" {
  description = "Deployment name"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network to use or create"
  type        = string
}

variable "subnetwork_name" {
  description = "The name of the subnetwork to use or create"
  type        = string
}

variable "create_network" {
  description = "Whether to create a new network or use an existing one"
  type        = bool
}

variable "subnetwork_cidr" {
  description = "CIDR range for the subnetwork"
  type        = string
}

variable "node_count" {
  description = "Number of Neo4j nodes to deploy"
  type        = number
  validation {
    condition     = contains([1, 3, 4, 5, 6, 7], var.node_count)
    error_message = "Node count must be 1 (standalone) or 3-7 (cluster)."
  }
}

variable "machine_type" {
  description = "GCP machine type for Neo4j nodes"
  type        = string
}

variable "disk_size" {
  description = "Size of the data disk in GB"
  type        = number
}

variable "admin_password" {
  description = "Password for the Neo4j admin user"
  type        = string
  sensitive   = true
}

variable "install_bloom" {
  description = "Whether to install Neo4j Bloom"
  type        = bool
}

variable "bloom_license_key" {
  description = "License key for Neo4j Bloom (if installing)"
  type        = string
  sensitive   = true
}

variable "firewall_source_range" {
  description = "Source IP ranges for external access"
  type        = list(string)
}

variable "license_type" {
  description = "Neo4j license type (Commercial or Evaluation)"
  type        = string
  validation {
    condition     = contains(["Commercial", "Evaluation"], var.license_type)
    error_message = "License type must be either Commercial or Evaluation."
  }
} 