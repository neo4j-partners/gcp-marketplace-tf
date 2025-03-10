output "neo4j_urls" {
  description = "URLs to access Neo4j Browser"
  value       = module.neo4j.neo4j_urls
}

output "neo4j_bolt_endpoints" {
  description = "Bolt endpoints for Neo4j connections"
  value       = module.neo4j.neo4j_bolt_endpoints
}

output "neo4j_instance_names" {
  description = "Names of the Neo4j instances"
  value       = module.neo4j.neo4j_instance_names
}

output "neo4j_instance_ips" {
  description = "IP addresses of the Neo4j instances"
  value       = module.neo4j.neo4j_instance_ips
}

output "neo4j_instance_self_links" {
  description = "Self links of the Neo4j instances"
  value       = module.neo4j.neo4j_instance_self_links
} 