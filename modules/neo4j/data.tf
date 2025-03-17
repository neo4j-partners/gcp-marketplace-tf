data "google_client_config" "current" {}

locals {
  current_project = data.google_client_config.current.project
} 