output "neo4j_urls" {
  description = "URLs to access Neo4j Browser"
  value = [
    for instance in google_compute_instance.neo4j : "http://${instance.network_interface[0].access_config[0].nat_ip}:7474"
  ]
}

output "neo4j_bolt_endpoints" {
  description = "Bolt endpoints for Neo4j connections"
  value = [
    for instance in google_compute_instance.neo4j : "bolt://${instance.network_interface[0].access_config[0].nat_ip}:7687"
  ]
}

output "neo4j_instance_names" {
  description = "Names of the Neo4j instances"
  value = google_compute_instance.neo4j[*].name
}

output "neo4j_instance_ips" {
  description = "IP addresses of the Neo4j instances"
  value = [for instance in google_compute_instance.neo4j : instance.network_interface[0].access_config[0].nat_ip]
}

output "neo4j_instance_self_links" {
  description = "Self links of the Neo4j instances"
  value = google_compute_instance.neo4j[*].self_link
}

output "neo4j_instance_zones" {
  description = "Zones of the Neo4j instances"
  value = google_compute_instance.neo4j[*].zone
}

output "neo4j_instance_machine_types" {
  description = "Machine types of the Neo4j instances"
  value = google_compute_instance.neo4j[*].machine_type
} 