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
TEST_PROJECT_ID=$(grep project_id $TEST_VAR_FILE | cut -d '=' -f2 | tr -d ' "')
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
    log "Terraform is not installed. Please install Terraform 1.0.0 or newer." "ERROR"
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

# Function to plan Terraform deployment
plan_terraform() {
  log "Planning Terraform deployment..."
  terraform plan -var-file="$TEST_VAR_FILE" -out=tfplan | tee -a $LOG_FILE
  log "Terraform plan created successfully." "SUCCESS"
}

# Function to apply Terraform configuration
apply_terraform() {
  log "Applying Terraform configuration..."
  terraform apply tfplan | tee -a $LOG_FILE
  log "Terraform configuration applied successfully." "SUCCESS"
}

# Function to verify deployment
verify_deployment() {
  log "Verifying deployment..."
  
  # Get outputs
  NEO4J_URLS=$(terraform output -json neo4j_urls | jq -r '.[]')
  NEO4J_BOLT_ENDPOINTS=$(terraform output -json neo4j_bolt_endpoints | jq -r '.[]')
  NEO4J_INSTANCE_NAMES=$(terraform output -json neo4j_instance_names | jq -r '.[]')
  EXTERNAL_IPS=$(terraform output -json neo4j_instance_ips | jq -r '.external[]')
  INTERNAL_IPS=$(terraform output -json neo4j_instance_ips | jq -r '.internal[]')
  
  # Log outputs
  log "Neo4j URLs: $NEO4J_URLS"
  log "Neo4j Bolt Endpoints: $NEO4J_BOLT_ENDPOINTS"
  log "Neo4j Instance Names: $NEO4J_INSTANCE_NAMES"
  log "Neo4j External IPs: $EXTERNAL_IPS"
  log "Neo4j Internal IPs: $INTERNAL_IPS"
  
  # Get the project ID from the instance self-link
  INSTANCE_SELF_LINK=$(terraform output -json neo4j_instance_self_links | jq -r '.[]' | head -1)
  if [ -n "$INSTANCE_SELF_LINK" ]; then
    # Extract project ID from self_link - format is typically projects/PROJECT_ID/zones/ZONE/instances/NAME
    ACTUAL_PROJECT_ID=$(echo $INSTANCE_SELF_LINK | sed -n 's/.*projects\/\([^\/]*\)\/.*/\1/p')
    
    if [ -n "$ACTUAL_PROJECT_ID" ]; then
      log "Setting active project to: $ACTUAL_PROJECT_ID"
      # Set the active project
      gcloud config set project "$ACTUAL_PROJECT_ID"
    else
      log "Could not parse project ID from self-link: $INSTANCE_SELF_LINK, using project from variables: $TEST_PROJECT_ID"
      gcloud config set project "$TEST_PROJECT_ID"
    fi
  else
    log "Could not determine project ID from instance self-link, using project from variables: $TEST_PROJECT_ID"
    gcloud config set project "$TEST_PROJECT_ID"
  fi
  
  # Verify instances are running
  for instance in $NEO4J_INSTANCE_NAMES; do
    STATUS=$(gcloud compute instances describe "$instance" --zone="$TEST_ZONE" --format="value(status)")
    if [ "$STATUS" != "RUNNING" ]; then
      log "Instance $instance is not running (status: $STATUS)." "ERROR"
      return 1
    fi
    log "Instance $instance is running." "SUCCESS"
  done
  
  # Wait for Neo4j to be accessible
  log "Waiting for Neo4j to be accessible..."
  
  for ip in $EXTERNAL_IPS; do
    # Try to connect to Neo4j Browser port
    RETRY_COUNT=0
    MAX_RETRIES=30
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      if nc -z -w 5 "$ip" 7474; then
        log "Neo4j Browser on $ip is accessible." "SUCCESS"
        break
      fi
      RETRY_COUNT=$((RETRY_COUNT+1))
      log "Waiting for Neo4j Browser on $ip to be accessible (attempt $RETRY_COUNT/$MAX_RETRIES)..."
      sleep 10
    done
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
      log "Neo4j Browser on $ip is not accessible after $MAX_RETRIES attempts." "ERROR"
      return 1
    fi
  done
  
  log "Deployment verified successfully." "SUCCESS"
  return 0
}

# Function to clean up resources
cleanup_resources() {
  if [ "$1" == "--cleanup" ]; then
    log "Cleaning up resources..."
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