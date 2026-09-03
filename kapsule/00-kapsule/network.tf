resource "scaleway_vpc" "main" {
  name                             = "${var.cluster_name}-vpc"
  project_id                       = var.project_id
  region                           = var.region
  enable_routing                   = true
  enable_custom_routes_propagation = true
  tags                             = var.tags
}

resource "scaleway_vpc_private_network" "main" {
  name                             = "${var.cluster_name}-pn"
  project_id                       = var.project_id
  region                           = var.region
  vpc_id                           = scaleway_vpc.main.id
  enable_default_route_propagation = true
  tags                             = var.tags

  ipv4_subnet {
    subnet = var.private_network_cidr
  }
}

resource "scaleway_vpc_public_gateway_ip" "main" {
  project_id = var.project_id
  zone       = var.zone
  tags       = var.tags
}

resource "scaleway_vpc_public_gateway" "main" {
  name        = "${var.cluster_name}-gateway"
  project_id  = var.project_id
  zone        = var.zone
  type        = var.gateway_type
  ip_id       = scaleway_vpc_public_gateway_ip.main.id
  tags        = var.tags
  enable_smtp = false
}

resource "scaleway_vpc_gateway_network" "main" {
  gateway_id         = scaleway_vpc_public_gateway.main.id
  private_network_id = scaleway_vpc_private_network.main.id
  zone               = var.zone
  enable_masquerade  = true

  ipam_config {
    push_default_route = true
  }
}

resource "scaleway_instance_security_group" "kapsule_nodes" {
  name                    = "${var.cluster_name}-nodes"
  description             = "Private security group for the Kapsule worker nodes"
  project_id              = var.project_id
  zone                    = var.zone
  stateful                = true
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"
  enable_default_security = true
  tags                    = var.tags

  inbound_rule {
    action   = "accept"
    protocol = "ANY"
    ip_range = var.private_network_cidr
  }
}
