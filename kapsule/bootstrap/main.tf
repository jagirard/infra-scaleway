locals {
  ci_permission_sets = [
    "KubernetesFullAccess",
    "InstancesFullAccess",
    "BlockStorageFullAccess",
    "VPCFullAccess",
    "PrivateNetworksFullAccess",
    "IPAMFullAccess",
    "VPCGatewayFullAccess",
    "LoadBalancersFullAccess",
    "ObjectStorageBucketsRead",
    "ObjectStorageObjectsRead",
    "ObjectStorageObjectsWrite",
    "ObjectStorageObjectsDelete",
  ]
}

resource "scaleway_object_bucket" "terraform_state" {
  name          = var.state_bucket_name
  project_id    = var.project_id
  region        = var.region
  force_destroy = false

  tags = {
    environment = "dev"
    managed_by  = "terraform"
    purpose     = "terraform-state"
  }

  versioning {
    enabled = true
  }
}

resource "scaleway_object_bucket_acl" "terraform_state" {
  bucket     = scaleway_object_bucket.terraform_state.id
  acl        = "private"
  project_id = var.project_id
  region     = var.region
}

resource "scaleway_iam_application" "github_actions" {
  name            = var.ci_application_name
  description     = "GitHub Actions identity for the autonomous Scaleway development pilot"
  organization_id = var.organization_id
  tags            = ["managed-by=terraform", "environment=dev", "purpose=ci"]
}

resource "scaleway_iam_policy" "github_actions" {
  name            = "${var.ci_application_name}-project-policy"
  description     = "Project-scoped permissions required to provision and operate the Kapsule development pilot"
  organization_id = var.organization_id
  application_id  = scaleway_iam_application.github_actions.id

  rule {
    project_ids          = [var.project_id]
    permission_set_names = local.ci_permission_sets
  }
}
