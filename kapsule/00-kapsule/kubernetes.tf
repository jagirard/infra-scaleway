data "scaleway_k8s_version" "selected" {
  name   = var.kubernetes_version
  region = var.region
}

resource "scaleway_k8s_cluster" "main" {
  name                        = var.cluster_name
  description                 = var.cluster_description
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

  lifecycle {
    precondition {
      condition = alltrue([
        for cidr in [var.private_network_cidr, var.pod_cidr, var.service_cidr] :
        (
          tonumber(split(".", cidrhost(cidr, 0))[0]) == 10 &&
          tonumber(split("/", cidr)[1]) >= 8
          ) || (
          tonumber(split(".", cidrhost(cidr, 0))[0]) == 192 &&
          tonumber(split(".", cidrhost(cidr, 0))[1]) == 168 &&
          tonumber(split("/", cidr)[1]) >= 16
          ) || (
          tonumber(split(".", cidrhost(cidr, 0))[0]) == 172 &&
          tonumber(split(".", cidrhost(cidr, 0))[1]) >= 16 &&
          tonumber(split(".", cidrhost(cidr, 0))[1]) <= 31 &&
          tonumber(split("/", cidr)[1]) >= 12
          ) || (
          tonumber(split(".", cidrhost(cidr, 0))[0]) == 100 &&
          tonumber(split(".", cidrhost(cidr, 0))[1]) >= 64 &&
          tonumber(split(".", cidrhost(cidr, 0))[1]) <= 127 &&
          tonumber(split("/", cidr)[1]) >= 10
        )
      ])
      error_message = "Private, pod, and service CIDRs must stay inside RFC 1918 or RFC 6598."
    }
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

  # Kapsule exposes tags on nodes as k8s.scaleway.com/<tag> labels, so tags cannot
  # satisfy a bare label key. The pool labels map is applied verbatim by Kapsule to
  # every node it provisions, including autoscaled and platform-replaced ones.
  labels = var.pool_node_labels

  # max_unavailable = 0 is rejected by the Scaleway API, which constrains the value
  # to 1-20, so surge-before-drain cannot be enforced here. With max_surge = 1 and
  # max_unavailable = 1 the pool may drain a node while the surge node is still
  # booting. GP1-XS exposes about 16 GiB RAM (~14 GiB allocatable). Production keeps
  # this pool at one node; workloads that need more memory run on the GP1-M pool.
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

    precondition {
      condition     = contains(var.tags, "environment=${var.environment}")
      error_message = "tags must include environment=<environment>."
    }

    precondition {
      condition = (
        var.environment != "prod" ||
        (
          var.private_network_cidr != "172.30.0.0/20" &&
          var.pod_cidr != "172.31.0.0/16" &&
          var.service_cidr != "172.29.0.0/20"
        )
      )
      error_message = "Production must not reuse the scw-dev-01 private, pod, or service CIDRs."
    }
  }
}

resource "scaleway_k8s_pool" "apps" {
  count = var.apps_pool.name == "" ? 0 : 1

  cluster_id         = scaleway_k8s_cluster.main.id
  name               = var.apps_pool.name
  node_type          = var.apps_pool.node_type
  size               = var.apps_pool.initial_size
  min_size           = var.apps_pool.min_size
  max_size           = var.apps_pool.max_size
  autoscaling        = true
  autohealing        = true
  container_runtime  = "containerd"
  public_ip_disabled = true
  security_group_id  = scaleway_instance_security_group.kapsule_nodes.id
  region             = var.region
  zone               = var.zone
  tags               = var.tags
  labels             = var.apps_pool.labels

  upgrade_policy {
    max_surge       = 1
    max_unavailable = 1
  }

  depends_on = [
    scaleway_k8s_acl.main,
    scaleway_vpc_gateway_network.main,
  ]

  lifecycle {
    # GP1-M is 16 vCPU / 64 GiB and can place three 16 GiB pods. size is the
    # initial count only; the autoscaler owns it afterwards, up to max_size.
    ignore_changes = [size]

    precondition {
      condition     = contains(var.tags, "environment=${var.environment}")
      error_message = "tags must include environment=<environment>."
    }

    precondition {
      condition     = contains(var.tags, "managed-by=terraform")
      error_message = "tags must include managed-by=terraform."
    }
  }
}
