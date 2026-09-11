data "scaleway_k8s_version" "selected" {
  name   = var.kubernetes_version
  region = var.region
}

resource "scaleway_k8s_cluster" "main" {
  name                        = var.cluster_name
  description                 = "Autonomous Scaleway Kapsule development pilot"
  project_id                  = var.project_id
  region                      = var.region
  type                        = "kapsule"
  version                     = data.scaleway_k8s_version.selected.name
  cni                         = "cilium"
  private_network_id          = scaleway_vpc_private_network.main.id
  pod_cidr                    = var.pod_cidr
  service_cidr                = var.service_cidr
  service_dns_ip              = cidrhost(var.service_cidr, 10)
  delete_additional_resources = false
  tags                        = var.tags
}

resource "scaleway_k8s_acl" "main" {
  cluster_id = scaleway_k8s_cluster.main.id
  region     = var.region

  dynamic "acl_rules" {
    for_each = toset(concat(var.api_allowed_cidrs, ["${scaleway_vpc_public_gateway_ip.main.address}/32"]))

    content {
      ip          = acl_rules.value
      description = acl_rules.value == "${scaleway_vpc_public_gateway_ip.main.address}/32" ? "NetBird Scaleway routing peer egress" : "Authorized Terraform operator network"
    }
  }
}

resource "scaleway_k8s_pool" "main" {
  cluster_id         = scaleway_k8s_cluster.main.id
  name               = "${var.cluster_name}-workers"
  node_type          = var.node_type
  size               = var.pool_initial_size
  min_size           = var.pool_min_size
  max_size           = var.pool_max_size
  autoscaling        = true
  autohealing        = true
  container_runtime  = "containerd"
  public_ip_disabled = true
  security_group_id  = scaleway_instance_security_group.kapsule_nodes.id
  region             = var.region
  zone               = var.zone
  tags               = var.tags

  depends_on = [
    scaleway_k8s_acl.main,
    scaleway_vpc_gateway_network.main,
  ]

  lifecycle {
    precondition {
      condition = (
        var.pool_min_size <= var.pool_initial_size &&
        var.pool_initial_size <= var.pool_max_size
      )
      error_message = "Pool sizing must satisfy min_size <= initial_size <= max_size."
    }
  }
}
