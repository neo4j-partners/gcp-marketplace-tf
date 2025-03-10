#!/bin/bash
set -euo pipefail

# Export variables from Terraform template
export environment=${environment}
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
    # Extract node index from instance name (neo4j-environment-X format)
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
    echo "Environment: $environment"
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
    if [[ "${license_type}" == "Evaluation" ]]; then
        echo "Setting up evaluation license..."
        echo "neo4j-enterprise neo4j/accept-license select Accept evaluation license" | debconf-set-selections
    else
        echo "Setting up enterprise license..."
        echo "neo4j-enterprise neo4j/accept-license select Accept commercial license" | debconf-set-selections
    fi
    
    # Install Neo4j Enterprise
    DEBIAN_FRONTEND=noninteractive apt-get install -y neo4j-enterprise
    
    # Enable the service
    systemctl enable neo4j
}

# Configure Neo4j
configure_neo4j() {
    echo "Configuring Neo4j..."
    NEO4J_CONF=/etc/neo4j/neo4j.conf

    # Basic configuration
    sed -i 's/#server.default_listen_address=0.0.0.0/server.default_listen_address=0.0.0.0/g' $NEO4J_CONF
    sed -i "s/#server.default_advertised_address=localhost/server.default_advertised_address=$NODE_EXTERNAL_IP/g" $NEO4J_CONF
    sed -i 's/#server.bolt.listen_address=:7687/server.bolt.listen_address=0.0.0.0:7687/g' $NEO4J_CONF
    sed -i "s/#server.bolt.advertised_address=:7687/server.bolt.advertised_address=$NODE_EXTERNAL_IP:7687/g" $NEO4J_CONF

    # Configure data directory
    echo "dbms.directories.data=/data/neo4j/data" >> $NEO4J_CONF
    echo "dbms.directories.plugins=/data/neo4j/plugins" >> $NEO4J_CONF
    echo "dbms.directories.logs=/data/neo4j/logs" >> $NEO4J_CONF
    echo "dbms.directories.import=/data/neo4j/import" >> $NEO4J_CONF

    # Security settings
    echo "dbms.security.procedures.unrestricted=apoc.*,bloom.*" >> $NEO4J_CONF
    echo "dbms.security.procedures.allowlist=apoc.*,bloom.*" >> $NEO4J_CONF
    echo "dbms.security.http_auth_allowlist=/,/browser.*,/bloom.*" >> $NEO4J_CONF

    # Metrics configuration
    echo "server.metrics.enabled=true" >> $NEO4J_CONF
    echo "server.metrics.jmx.enabled=true" >> $NEO4J_CONF
    echo "server.metrics.prefix=neo4j" >> $NEO4J_CONF
    echo "server.metrics.filter=*" >> $NEO4J_CONF
    echo "server.metrics.csv.interval=5s" >> $NEO4J_CONF
    echo "dbms.routing.default_router=SERVER" >> $NEO4J_CONF

    # SSRF protection
    echo "internal.dbms.cypher_ip_blocklist=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.169.0/24,fc00::/7,fe80::/10,ff00::/8" >> $NEO4J_CONF
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
            echo "dbms.bloom.license_file=/etc/neo4j/licenses/neo4j-bloom.license" >> $NEO4J_CONF
            chown -R neo4j:neo4j /etc/neo4j/licenses
        fi
    fi
}

# Configure clustering if node count > 1
configure_clustering() {
    if [[ ${node_count} -gt 1 ]]; then
        echo "Configuring Neo4j cluster..."
        
        # Discovery and cluster settings
        sed -i "s/#server.discovery.advertised_address=:5000/server.discovery.advertised_address=$NODE_INTERNAL_IP:5000/g" $NEO4J_CONF
        sed -i "s/#server.cluster.advertised_address=:6000/server.cluster.advertised_address=$NODE_INTERNAL_IP:6000/g" $NEO4J_CONF
        sed -i "s/#server.cluster.raft.advertised_address=:7000/server.cluster.raft.advertised_address=$NODE_INTERNAL_IP:7000/g" $NEO4J_CONF
        sed -i "s/#server.routing.advertised_address=:7688/server.routing.advertised_address=$NODE_INTERNAL_IP:7688/g" $NEO4J_CONF
        
        # Set initial cluster size
        sed -i "s/#initial.dbms.default_primaries_count=1/initial.dbms.default_primaries_count=3/g" $NEO4J_CONF
        sed -i "s/#initial.dbms.default_secondaries_count=0/initial.dbms.default_secondaries_count=$(( node_count - 3 ))/g" $NEO4J_CONF
        
        echo "dbms.cluster.minimum_initial_system_primaries_count=${node_count}" >> $NEO4J_CONF
        
        discover_cluster_members
    fi
}

# Discover cluster members
discover_cluster_members() {
    echo "Discovering cluster members..."
    CORE_MEMBERS=""
    
    for i in $(seq 1 ${node_count}); do
        NODE_NAME="neo4j-${environment}-$i"
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
        echo "dbms.cluster.discovery.version=V2_ONLY" >> $NEO4J_CONF
        echo "dbms.cluster.discovery.resolver_type=LIST" >> $NEO4J_CONF
        echo "dbms.cluster.discovery.v2.endpoints=$CORE_MEMBERS" >> $NEO4J_CONF
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