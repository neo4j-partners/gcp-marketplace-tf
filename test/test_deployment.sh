#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
TEST_VAR_FILE="test/marketplace_test.tfvars"
LOG_FILE="test/test_deployment.log"
TEST_PROJECT_ID=$(grep project_id $TEST_VAR_FILE | head -1 | cut -d '=' -f2 | tr -d ' "')
TEST_REGION=$(grep region $TEST_VAR_FILE | head -1 | cut -d '=' -f2 | tr -d ' "')
TEST_ZONE=$(grep zone $TEST_VAR_FILE | cut -d '=' -f2 | tr -d ' "')

# Function to log messages
log() {
  local message="$1"
  local level="${2:-INFO}"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "${timestamp} [${level}] ${message}" | tee -a $LOG_FILE
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
  log "Checking prerequisites..."
  
  # Check if terraform is installed
  if ! command_exists terraform; then
    log "Terraform is not installed. Please install Terraform 1.2.0 or newer." "ERROR"
    exit 1
  fi
  
  # Check terraform version
  TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
  log "Terraform version: $TERRAFORM_VERSION"
  
  # Check if gcloud is installed
  if ! command_exists gcloud; then
    log "Google Cloud SDK is not installed. Please install it." "ERROR"
    exit 1
  fi
  
  # Check if jq is installed
  if ! command_exists jq; then
    log "jq is not installed. Please install it for JSON parsing." "ERROR"
    exit 1
  fi
  
  # Check if test var file exists
  if [ ! -f "$TEST_VAR_FILE" ]; then
    log "Test variable file $TEST_VAR_FILE not found." "ERROR"
    exit 1
  fi
  
  # Check if user is authenticated with gcloud
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    log "Not authenticated with gcloud. Please run 'gcloud auth login'." "ERROR"
    exit 1
  fi
  
  # Check if project ID is valid
  if [ -z "$TEST_PROJECT_ID" ]; then
    log "No project ID found in $TEST_VAR_FILE. Please add project_id to your tfvars file." "ERROR"
    exit 1
  fi
  
  # Check if project exists and user has access
  if ! gcloud projects describe "$TEST_PROJECT_ID" >/dev/null 2>&1; then
    log "Project $TEST_PROJECT_ID does not exist or you don't have access to it." "ERROR"
    exit 1
  fi
  
  log "All prerequisites checked successfully." "SUCCESS"
}

# Function to initialize Terraform
initialize_terraform() {
  log "Initializing Terraform..."
  terraform init | tee -a $LOG_FILE
  log "Terraform initialized successfully." "SUCCESS"
}

# Function to validate Terraform configuration
validate_terraform() {
  log "Validating Terraform configuration..."
  terraform validate | tee -a $LOG_FILE
  log "Terraform configuration is valid." "SUCCESS"
}

# Function to plan Terraform configuration
plan_terraform() {
  log "Planning Terraform deployment..."
  # The project_id is already set in the test tfvars file
  terraform plan -var-file="$TEST_VAR_FILE" -out=tfplan | tee -a $LOG_FILE
  log "Terraform plan created successfully." "SUCCESS"
}

# Function to apply Terraform configuration
apply_terraform() {
  log "Applying Terraform configuration..."
  # The project_id is already set in the test tfvars file
  terraform apply tfplan | tee -a $LOG_FILE
  log "Terraform configuration applied successfully." "SUCCESS"
}

# Function to verify deployment
verify_deployment() {
  log "Verifying deployment..."
  
  # Get outputs
  NEO4J_URL=$(terraform output -json neo4j_url 2>/dev/null || echo "")
  NEO4J_BOLT_URL=$(terraform output -json neo4j_bolt_url 2>/dev/null || echo "")
  NEO4J_INSTANCE_NAMES=$(terraform output -json neo4j_instance_names | jq -r '.[]' 2>/dev/null || echo "")
  NEO4J_IP_ADDRESSES=$(terraform output -json neo4j_ip_addresses | jq -r '.[]' 2>/dev/null || echo "")
  NEO4J_ZONES=$(terraform output -json neo4j_instance_zones | jq -r '.[]' 2>/dev/null || echo "")
  
  # Log outputs
  log "Neo4j URL: $NEO4J_URL"
  log "Neo4j Bolt URL: $NEO4J_BOLT_URL"
  log "Neo4j Instance Names: $NEO4J_INSTANCE_NAMES"
  log "Neo4j IP Addresses: $NEO4J_IP_ADDRESSES"
  log "Neo4j Zones: $NEO4J_ZONES"
  
  # Verify instances are running
  for instance in $NEO4J_INSTANCE_NAMES; do
    STATUS=$(gcloud compute instances describe "$instance" --zone="$TEST_ZONE" --format="value(status)" 2>/dev/null || echo "NOT_FOUND")
    if [ "$STATUS" != "RUNNING" ]; then
      log "Instance $instance is not running (status: $STATUS)." "ERROR"
      return 1
    fi
    log "Instance $instance is running." "SUCCESS"
  done
  
  # Wait for Neo4j to be accessible
  log "Waiting for Neo4j to be accessible..."
  
  # Extract IP from the Neo4J_URL (format: http://IP:7474) and remove quotes
  IP=$(echo $NEO4J_URL | sed 's|http://||' | sed 's|:7474||' | tr -d '"' | xargs)
  
  log "Checking Neo4j Browser on IP: $IP"
  
  # Try to connect to Neo4j Browser port
  RETRY_COUNT=0
  MAX_RETRIES=30
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s --connect-timeout 5 http://$IP:7474 > /dev/null; then
      log "Neo4j Browser on $IP is accessible." "SUCCESS"
      break
    fi
    RETRY_COUNT=$((RETRY_COUNT+1))
    log "Waiting for Neo4j Browser on $IP to be accessible (attempt $RETRY_COUNT/$MAX_RETRIES)..."
    sleep 10
  done
  
  if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log "Neo4j Browser on $IP is not accessible after $MAX_RETRIES attempts." "ERROR"
    return 1
  fi
  
  log "Deployment verified successfully." "SUCCESS"
  return 0
}

# Function to clean up resources
cleanup_resources() {
  if [ "$1" == "--cleanup" ]; then
    log "Cleaning up resources..."
    # The project_id is already set in the terraform.tfvars file
    terraform destroy -var-file="$TEST_VAR_FILE" -auto-approve | tee -a $LOG_FILE
    log "Resources cleaned up successfully." "SUCCESS"
  else
    log "Skipping cleanup. To clean up resources, run with --cleanup flag."
  fi
}

# Main function
main() {
  log "Starting Neo4j Terraform GCP deployment test..."
  
  # Create or clear log file
  > $LOG_FILE
  
  # Run test steps
  check_prerequisites
  initialize_terraform
  validate_terraform
  plan_terraform
  apply_terraform
  
  # Verify deployment
  if verify_deployment; then
    log "Test completed successfully!" "SUCCESS"
    echo -e "\n${GREEN}✓ Test completed successfully!${NC}\n"
  else
    log "Test failed during verification." "ERROR"
    echo -e "\n${RED}✗ Test failed during verification.${NC}\n"
  fi
  
  # Clean up if requested
  cleanup_resources "$1"
}

# Run main function with arguments
main "$@" 