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

  # Tuned for sequential Helm installs: a node added for one release must not be
  # reclaimed while the next release is still installing. Both delays are aligned
  # on the 20-minute per-release timeout used by the Onizuka bootstrap script,
  # against autoscaler defaults of 10 minutes.
  autoscaler_config {
    disable_scale_down               = var.autoscaler_disable_scale_down
    scale_down_delay_after_add       = "20m"
    scale_down_unneeded_time         = "20m"
    scale_down_utilization_threshold = 0.3
    estimator                        = "binpacking"
    expander                         = "least_waste"
    balance_similar_node_groups      = true
    ignore_daemonsets_utilization    = true
    max_graceful_termination_sec     = 600
  }
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

  # max_unavailable = 0 is rejected by the Scaleway API, which constrains the value
  # to 1-20, so surge-before-drain cannot be enforced here. With max_surge = 1 and
  # max_unavailable = 1 the pool may drain a node while the surge node is still
  # booting. GP1-XS exposes about 16 GiB RAM (~14–15 GiB allocatable after Kapsule
  # reservation). Keep min_size at 4 so a degraded upgrade window still covers the
  # Onizuka application sequence without waiting on a scale-up.
  upgrade_policy {
    max_surge       = 1
    max_unavailable = 1
  }

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
