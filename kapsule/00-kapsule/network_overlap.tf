locals {
  network_cidr_prefix_lengths = {
    private_network = tonumber(split("/", var.private_network_cidr)[1])
    pod             = tonumber(split("/", var.pod_cidr)[1])
    service         = tonumber(split("/", var.service_cidr)[1])
  }

  network_cidr_network_addresses = {
    private_network = cidrhost(var.private_network_cidr, 0)
    pod             = cidrhost(var.pod_cidr, 0)
    service         = cidrhost(var.service_cidr, 0)
  }

  private_network_contains_pod = (
    local.network_cidr_prefix_lengths.pod < local.network_cidr_prefix_lengths.private_network ? false : (
      local.network_cidr_prefix_lengths.pod == local.network_cidr_prefix_lengths.private_network ?
      local.network_cidr_network_addresses.private_network == local.network_cidr_network_addresses.pod :
      contains(
        [
          for index in range(pow(2, local.network_cidr_prefix_lengths.pod - local.network_cidr_prefix_lengths.private_network)) :
          cidrhost(cidrsubnet(var.private_network_cidr, local.network_cidr_prefix_lengths.pod - local.network_cidr_prefix_lengths.private_network, index), 0)
        ],
        local.network_cidr_network_addresses.pod
      )
    )
  )

  pod_contains_private_network = (
    local.network_cidr_prefix_lengths.private_network < local.network_cidr_prefix_lengths.pod ? false : (
      local.network_cidr_prefix_lengths.private_network == local.network_cidr_prefix_lengths.pod ?
      local.network_cidr_network_addresses.private_network == local.network_cidr_network_addresses.pod :
      contains(
        [
          for index in range(pow(2, local.network_cidr_prefix_lengths.private_network - local.network_cidr_prefix_lengths.pod)) :
          cidrhost(cidrsubnet(var.pod_cidr, local.network_cidr_prefix_lengths.private_network - local.network_cidr_prefix_lengths.pod, index), 0)
        ],
        local.network_cidr_network_addresses.private_network
      )
    )
  )

  private_network_contains_service = (
    local.network_cidr_prefix_lengths.service < local.network_cidr_prefix_lengths.private_network ? false : (
      local.network_cidr_prefix_lengths.service == local.network_cidr_prefix_lengths.private_network ?
      local.network_cidr_network_addresses.private_network == local.network_cidr_network_addresses.service :
      contains(
        [
          for index in range(pow(2, local.network_cidr_prefix_lengths.service - local.network_cidr_prefix_lengths.private_network)) :
          cidrhost(cidrsubnet(var.private_network_cidr, local.network_cidr_prefix_lengths.service - local.network_cidr_prefix_lengths.private_network, index), 0)
        ],
        local.network_cidr_network_addresses.service
      )
    )
  )

  service_contains_private_network = (
    local.network_cidr_prefix_lengths.private_network < local.network_cidr_prefix_lengths.service ? false : (
      local.network_cidr_prefix_lengths.private_network == local.network_cidr_prefix_lengths.service ?
      local.network_cidr_network_addresses.private_network == local.network_cidr_network_addresses.service :
      contains(
        [
          for index in range(pow(2, local.network_cidr_prefix_lengths.private_network - local.network_cidr_prefix_lengths.service)) :
          cidrhost(cidrsubnet(var.service_cidr, local.network_cidr_prefix_lengths.private_network - local.network_cidr_prefix_lengths.service, index), 0)
        ],
        local.network_cidr_network_addresses.private_network
      )
    )
  )

  pod_contains_service = (
    local.network_cidr_prefix_lengths.service < local.network_cidr_prefix_lengths.pod ? false : (
      local.network_cidr_prefix_lengths.service == local.network_cidr_prefix_lengths.pod ?
      local.network_cidr_network_addresses.pod == local.network_cidr_network_addresses.service :
      contains(
        [
          for index in range(pow(2, local.network_cidr_prefix_lengths.service - local.network_cidr_prefix_lengths.pod)) :
          cidrhost(cidrsubnet(var.pod_cidr, local.network_cidr_prefix_lengths.service - local.network_cidr_prefix_lengths.pod, index), 0)
        ],
        local.network_cidr_network_addresses.service
      )
    )
  )

  service_contains_pod = (
    local.network_cidr_prefix_lengths.pod < local.network_cidr_prefix_lengths.service ? false : (
      local.network_cidr_prefix_lengths.pod == local.network_cidr_prefix_lengths.service ?
      local.network_cidr_network_addresses.pod == local.network_cidr_network_addresses.service :
      contains(
        [
          for index in range(pow(2, local.network_cidr_prefix_lengths.pod - local.network_cidr_prefix_lengths.service)) :
          cidrhost(cidrsubnet(var.service_cidr, local.network_cidr_prefix_lengths.pod - local.network_cidr_prefix_lengths.service, index), 0)
        ],
        local.network_cidr_network_addresses.pod
      )
    )
  )

  network_cidrs_overlap = (
    local.private_network_contains_pod ||
    local.pod_contains_private_network ||
    local.private_network_contains_service ||
    local.service_contains_private_network ||
    local.pod_contains_service ||
    local.service_contains_pod
  )
}
