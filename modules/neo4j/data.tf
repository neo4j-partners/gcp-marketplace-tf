data "google_client_config" "current" {}

locals {
  project_id = try(trimspace(file("/tmp/google_project_id")), "")
} 