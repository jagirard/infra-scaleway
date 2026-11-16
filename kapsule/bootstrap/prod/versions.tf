terraform {
  required_version = "~> 1.14.0"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.81.0"
    }
  }
}

provider "scaleway" {
  project_id      = var.project_id
  organization_id = var.organization_id
  region          = var.region
  zone            = var.zone
}
