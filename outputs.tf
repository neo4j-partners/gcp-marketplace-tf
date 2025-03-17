output "neo4j_url" {
  description = "URL to access Neo4j Browser"
  value       = module.neo4j.neo4j_urls[0]
}

output "neo4j_bolt_url" {
  description = "Bolt URL for connecting to Neo4j"
  value       = module.neo4j.neo4j_bolt_endpoints[0]
}

output "neo4j_ip_addresses" {
  description = "IP addresses of the Neo4j nodes"
  value       = module.neo4j.neo4j_instance_ips
}

output "neo4j_instance_names" {
  description = "Names of the Neo4j instances"
  value       = module.neo4j.neo4j_instance_names
}

output "neo4j_instance_zones" {
  description = "Zones where Neo4j instances are deployed"
  value       = [for i in range(var.node_count) : var.zone]
}

output "neo4j_instance_machine_types" {
  description = "Machine types of Neo4j instances"
  value       = [for i in range(var.node_count) : var.machine_type]
} 