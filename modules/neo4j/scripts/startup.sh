#!/bin/bash
set -euo pipefail

# Export variables from Terraform template
export deployment_name=${deployment_name}
export node_count=${node_count}
export admin_password=${admin_password}
export install_bloom=${install_bloom}
export bloom_license_key=${bloom_license_key}
export project_id=${project_id}
export license_type=${license_type}

# Get instance metadata and node index
get_instance_metadata() {
    echo "Retrieving instance metadata..."
    export NODE_INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
    export NODE_EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
    export INSTANCE_NAME=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
    # Extract node index from instance name (neo4j-deployment_name-X format)
    export NODE_INDEX=$(echo $INSTANCE_NAME | sed 's/.*-//')
    
    # Print the values to verify
    echo "Metadata retrieved:"
    echo "NODE_INTERNAL_IP: $NODE_INTERNAL_IP"
    echo "NODE_EXTERNAL_IP: $NODE_EXTERNAL_IP"
    echo "INSTANCE_NAME: $INSTANCE_NAME"
    echo "NODE_INDEX: $NODE_INDEX"
}

# Log startup info after metadata is retrieved
log_startup_info() {
    echo "Starting Neo4j setup script"
    echo "Node count: $node_count"
    echo "Node index: $NODE_INDEX"
    echo "Deployment name: $deployment_name"
    echo "Instance name: $INSTANCE_NAME"
    echo "Internal IP: $NODE_INTERNAL_IP"
    echo "External IP: $NODE_EXTERNAL_IP"
}

# Install system dependencies
install_dependencies() {
    echo "Installing system dependencies..."
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt to install dependencies..."
        if DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl gnupg jq; then
            echo "Dependencies installed successfully."
            return 0
        fi
        echo "Attempt $attempt failed."
        attempt=$((attempt + 1))
        if [ $attempt -le $max_attempts ]; then
            echo "Waiting before retry..."
            sleep 10
        fi
    done
    
    echo "Failed to install dependencies after $max_attempts attempts. Exiting."
    exit 1
}

# Setup data disk
setup_data_disk() {
    echo "Setting up data disk..."
    DATA_DEVICE=$(lsblk -o NAME,SERIAL | grep data-disk | awk '{print $1}')
    if [ -n "$DATA_DEVICE" ]; then
        DATA_DEVICE="/dev/$DATA_DEVICE"
        echo "Found data disk at $DATA_DEVICE"
        
        if ! blkid $DATA_DEVICE; then
            echo "Formatting data disk..."
            mkfs.ext4 -F $DATA_DEVICE
        else
            echo "Data disk already formatted"
        fi
        
        mkdir -p /data
        echo "$DATA_DEVICE /data ext4 defaults,nofail 0 2" >> /etc/fstab
        mount -a
        
        mkdir -p /data/neo4j
        chown -R 7474:7474 /data/neo4j
    else
        echo "No data disk found, using boot disk"
        mkdir -p /data/neo4j
    fi
}

# Install Neo4j
install_neo4j() {
    echo "Adding Neo4j apt repo..."
    wget -O - https://debian.neo4j.com/neotechnology.gpg.key | gpg --dearmor > /usr/share/keyrings/neotechnology.gpg
    
    echo "deb [signed-by=/usr/share/keyrings/neotechnology.gpg] https://debian.neo4j.com stable latest" > /etc/apt/sources.list.d/neo4j.list
    
    apt-get update
    
    # Pre-accept the license for non-interactive installation
    if [[ "${license_type}" == "evaluation" ]]; then
        echo "Setting up evaluation license..."
        echo "neo4j-enterprise neo4j/accept-license select Accept evaluation license" | debconf-set-selections
    else
        echo "Setting up enterprise license (BYOL)..."
        echo "neo4j-enterprise neo4j/accept-license select Accept commercial license" | debconf-set-selections
    fi
    
    # Install Neo4j Enterprise
    DEBIAN_FRONTEND=noninteractive apt-get install -y neo4j-enterprise
    
    # Enable the service
    systemctl enable neo4j
}
# Function to configure Neo4j settings.
configure_neo4j_setting() {
    local setting=$1
    local value=$2
    local confFile="/etc/neo4j/neo4j.conf"

    # Check if the setting exists uncommented
    if grep -q "^$${setting}=" "$confFile"; then
        sed -i "s|^$${setting}=.*|$${setting}=$${value}|g" "$confFile"
        echo "Replaced existing setting: $${setting}=$${value}"
    # Check if the setting exists commented
    elif grep -q "^#$${setting}=" "$confFile"; then
        # Setting exists commented - add it after the comment line
        sed -i "/^#$${setting}=/a $${setting}=$${value}" "$confFile"
        echo "Added setting after comment: $${setting}=$${value}"
    # Setting doesn't exist in the file
    else
        # Add to the end under "Other Neo4j system properties"
        sed -i "/# Other Neo4j system properties/a $${setting}=$${value}" "$confFile"
        echo "Added new setting to end: $${setting}=$${value}"
    fi
}


# Configure Neo4j
configure_neo4j() {
    echo "Configuring Neo4j..."
    NEO4J_CONF=/etc/neo4j/neo4j.conf

    # Basic configuration
    configure_neo4j_setting "server.default_listen_address" "0.0.0.0"
    configure_neo4j_setting "server.default_advertised_address" "$NODE_EXTERNAL_IP"
    configure_neo4j_setting "server.bolt.listen_address" "0.0.0.0:7687"
    configure_neo4j_setting "server.bolt.advertised_address" "$NODE_EXTERNAL_IP:7687"

    # Configure HTTP endpoint for Neo4j Browser - only add this once
    configure_neo4j_setting "server.http.listen_address" "0.0.0.0:7474"
    configure_neo4j_setting "server.http.advertised_address" "$NODE_EXTERNAL_IP:7474"

    # Security settings
    configure_neo4j_setting "dbms.security.procedures.unrestricted" "apoc.*,bloom.*"
    configure_neo4j_setting "dbms.security.procedures.allowlist" "apoc.*,bloom.*"
    configure_neo4j_setting "dbms.security.http_auth_allowlist" "/,/browser.*,/bloom.*"

    # Metrics configuration
    configure_neo4j_setting "server.metrics.enabled" "true"
    configure_neo4j_setting "server.metrics.jmx.enabled" "true"
    configure_neo4j_setting "server.metrics.prefix" "neo4j"
    configure_neo4j_setting "server.metrics.filter" "*"
    configure_neo4j_setting "server.metrics.csv.interval" "5s"
    configure_neo4j_setting "dbms.routing.default_router" "SERVER"

    # SSRF protection
    configure_neo4j_setting "internal.dbms.cypher_ip_blocklist" "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.169.0/24,fc00::/7,fe80::/10,ff00::/8"
}

# Install APOC plugin
install_apoc() {
    echo "Installing APOC plugin..."
    mkdir -p /data/neo4j/plugins
    cp /var/lib/neo4j/labs/apoc-*-core.jar /data/neo4j/plugins/
}

# Configure Bloom if requested
configure_bloom() {
    if [[ "${install_bloom}" == "Yes" ]]; then
        echo "Installing Neo4j Bloom..."
        cp /var/lib/neo4j/products/bloom-plugin-*.jar /data/neo4j/plugins/
        chown neo4j:neo4j /data/neo4j/plugins/bloom-plugin-*.jar
        
        if [[ -n "${bloom_license_key}" ]]; then
            echo "Configuring Bloom license..."
            mkdir -p /etc/neo4j/licenses
            echo "${bloom_license_key}" > /etc/neo4j/licenses/neo4j-bloom.license
            configure_neo4j_setting "dbms.bloom.license_file" "/etc/neo4j/licenses/neo4j-bloom.license"
            chown -R neo4j:neo4j /etc/neo4j/licenses
        fi
    fi
}

# Configure clustering if node count > 1
configure_clustering() {
    if [[ ${node_count} -gt 1 ]]; then
        echo "Configuring Neo4j cluster..."
        
        # Discovery and cluster settings
        configure_neo4j_setting "server.cluster.listen_address" "0.0.0.0:6000"
        configure_neo4j_setting "server.cluster.advertised_address" "$NODE_INTERNAL_IP:6000"
        
        configure_neo4j_setting "server.cluster.raft.listen_address" "0.0.0.0:7000"
        configure_neo4j_setting "server.cluster.raft.advertised_address" "$NODE_INTERNAL_IP:7000"
        
        configure_neo4j_setting "server.routing.listen_address" "0.0.0.0:7688"
        configure_neo4j_setting "server.routing.advertised_address" "$NODE_INTERNAL_IP:7688"
        
        # Set initial cluster size
        configure_neo4j_setting "initial.dbms.default_primaries_count" "3"
        configure_neo4j_setting "initial.dbms.default_secondaries_count" "$(( node_count - 3 ))"
        
        configure_neo4j_setting "dbms.cluster.minimum_initial_system_primaries_count" "${node_count}"
        
        discover_cluster_members
    fi
}

# Discover cluster members
discover_cluster_members() {
    echo "Discovering cluster members..."
    CORE_MEMBERS=""
    
    for i in $(seq 1 ${node_count}); do
        NODE_NAME="neo4j-${deployment_name}-$i"
        NODE_IP=$(getent hosts $NODE_NAME.c.$project_id.internal | awk '{ print $1 }')
        
        if [[ -z "$NODE_IP" ]]; then
            NODE_IP=$(gcloud compute instances describe $NODE_NAME --zone=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | cut -d/ -f4) --format="value(networkInterfaces[0].networkIP)" 2>/dev/null || echo "")
        fi
        
        if [[ -n "$NODE_IP" ]]; then
            if [[ -n "$CORE_MEMBERS" ]]; then
                CORE_MEMBERS="$CORE_MEMBERS,$NODE_IP:6000"
            else
                CORE_MEMBERS="$NODE_IP:6000"
            fi
        fi
    done
    
    if [[ -n "$CORE_MEMBERS" ]]; then
        echo "Setting V2 discovery endpoints: $CORE_MEMBERS"
        configure_neo4j_setting "dbms.cluster.discovery.resolver_type" "LIST"
        configure_neo4j_setting "dbms.cluster.endpoints" "$CORE_MEMBERS"
    fi
}

# Start Neo4j and set password
start_neo4j() {
    echo "Starting Neo4j service..."
    systemctl enable neo4j --now
    systemctl start neo4j

    echo "Setting admin password..."
    local max_attempts=30
    local attempt=1
    while ! neo4j-admin dbms set-initial-password "${admin_password}" 2>/dev/null; do
        if [ $attempt -gt $max_attempts ]; then
            echo "Failed to set password after $max_attempts attempts. Check Neo4j status."
            exit 1
        fi
        echo "Attempt $attempt: Waiting for Neo4j to start..."
        sleep 10
        attempt=$((attempt + 1))
    done
    echo "Password set successfully."
}

# Main function
main() {
    get_instance_metadata
    log_startup_info
    install_dependencies
    setup_data_disk
    install_neo4j
    configure_neo4j
    install_apoc
    configure_bloom
    configure_clustering
    start_neo4j
    echo "Neo4j setup complete!"
}

# Run main function
main 