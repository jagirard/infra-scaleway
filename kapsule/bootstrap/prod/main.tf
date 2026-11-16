locals {
  permission_sets = [
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

  state_bucket_permission_sets = [
    "ObjectStorageBucketsRead",
    "ObjectStorageObjectsRead",
    "ObjectStorageObjectsWrite",
    "ObjectStorageObjectsDelete",
  ]
}

resource "scaleway_iam_application" "production" {
  name            = var.ci_application_name
  description     = "Dedicated identity for the sovereign Scaleway production Kapsule cluster"
  organization_id = var.organization_id
  tags            = ["managed-by=terraform", "environment=prod", "purpose=kapsule"]
}

resource "scaleway_iam_policy" "production" {
  name            = "${var.ci_application_name}-project-policy"
  description     = "Project-scoped permissions required to provision and operate the production Kapsule cluster"
  organization_id = var.organization_id
  application_id  = scaleway_iam_application.production.id

  rule {
    project_ids          = [var.project_id]
    permission_set_names = local.permission_sets
  }

  rule {
    project_ids          = [var.state_bucket_project_id]
    permission_set_names = local.state_bucket_permission_sets
  }

  lifecycle {
    precondition {
      condition     = var.state_bucket_project_id != var.project_id
      error_message = "state_bucket_project_id must stay separate from the production project_id."
    }
  }
}
