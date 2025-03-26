terraform {
  required_version = ">= 1.2.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  default_labels = {
    goog-partner-solution = "isol_plb32_0014m00001h36fwqay_2yv7nsvohejgjrstgxrez64s7ic32kub"
  }
} 