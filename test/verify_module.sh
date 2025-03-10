#!/bin/bash
set -e

# This script performs a basic verification of the Terraform module
# as required by GCP Marketplace

echo "Starting verification of Neo4j Terraform module for GCP Marketplace..."

# Change to root directory
cd "$(dirname "$0")/.."

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Validate the configuration
echo "Validating Terraform configuration..."
terraform validate

# Run a plan with the test variables
echo "Running Terraform plan with test variables..."
terraform plan -var-file=test/marketplace_test.tfvars

echo "Verification completed successfully!"
echo "To deploy the resources, run: terraform apply -var-file=test/marketplace_test.tfvars"
echo "Note: This will create actual resources in your GCP project and may incur costs." 