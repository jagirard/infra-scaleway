variable "project_id" {
  description = "Scaleway project UUID hosting the development pilot."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", var.project_id))
    error_message = "project_id must be a valid lowercase UUID."
  }
}

variable "organization_id" {
  description = "Scaleway organization UUID owning the project."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", var.organization_id))
    error_message = "organization_id must be a valid lowercase UUID."
  }
}

variable "region" {
  description = "Scaleway region for regional resources."
  type        = string
  default     = "fr-par"

  validation {
    condition     = var.region == "fr-par"
    error_message = "This pilot is restricted to the fr-par region."
  }
}

variable "zone" {
  description = "Scaleway zone for zonal resources."
  type        = string
  default     = "fr-par-1"

  validation {
    condition     = var.zone == "fr-par-1"
    error_message = "This pilot is restricted to the fr-par-1 zone."
  }
}

variable "cluster_name" {
  description = "Kapsule cluster name."
  type        = string
  default     = "kapsule-scw-dev-01"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.cluster_name))
    error_message = "cluster_name must be a valid lowercase DNS label."
  }
}

variable "kubernetes_version" {
  description = "Explicit Kubernetes patch version supported by Kapsule."
  type        = string
  default     = "1.36.1"

  validation {
    condition     = can(regex("^1\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must be an explicit Kubernetes 1.x patch version."
  }
}

variable "private_network_cidr" {
  description = "Dedicated IPv4 CIDR for the Scaleway Private Network."
  type        = string
  default     = "172.30.0.0/20"

  validation {
    condition     = can(cidrnetmask(var.private_network_cidr)) && var.private_network_cidr != "0.0.0.0/0"
    error_message = "private_network_cidr must be a non-default IPv4 CIDR."
  }
}

variable "pod_cidr" {
  description = "Dedicated IPv4 CIDR for Kubernetes pods."
  type        = string
  default     = "172.31.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.pod_cidr)) && var.pod_cidr != "0.0.0.0/0"
    error_message = "pod_cidr must be a non-default IPv4 CIDR."
  }
}

variable "service_cidr" {
  description = "Dedicated IPv4 CIDR for Kubernetes services."
  type        = string
  default     = "172.29.0.0/20"

  validation {
    condition     = can(cidrnetmask(var.service_cidr)) && var.service_cidr != "0.0.0.0/0"
    error_message = "service_cidr must be a non-default IPv4 CIDR."
  }
}

variable "api_allowed_cidrs" {
  description = "Non-empty IPv4 CIDR allowlist for the public Kapsule API server."
  type        = list(string)

  validation {
    condition = (
      length(var.api_allowed_cidrs) > 0 &&
      length(var.api_allowed_cidrs) == length(distinct(var.api_allowed_cidrs)) &&
      alltrue([for cidr in var.api_allowed_cidrs : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"])
    )
    error_message = "api_allowed_cidrs must contain unique IPv4 CIDRs and must not include 0.0.0.0/0."
  }
}

variable "gateway_type" {
  description = "Scaleway Public Gateway commercial type."
  type        = string
  default     = "VPC-GW-S"

  validation {
    condition     = contains(["VPC-GW-S", "VPC-GW-M", "VPC-GW-L"], var.gateway_type)
    error_message = "gateway_type must be VPC-GW-S, VPC-GW-M, or VPC-GW-L."
  }
}

variable "node_type" {
  description = "Scaleway Instance type used by the Kapsule pool."
  type        = string
  default     = "DEV1-M"

  validation {
    condition     = var.node_type == "DEV1-M"
    error_message = "This pilot is restricted to DEV1-M nodes."
  }
}

variable "pool_initial_size" {
  description = "Initial number of nodes in the autoscaling pool."
  type        = number
  default     = 2

  validation {
    condition     = var.pool_initial_size == 2
    error_message = "The pilot pool initial size must be 2."
  }
}

variable "pool_min_size" {
  description = "Minimum number of nodes in the autoscaling pool."
  type        = number
  default     = 1

  validation {
    condition     = var.pool_min_size == 1
    error_message = "The pilot pool minimum size must be 1."
  }
}

variable "pool_max_size" {
  description = "Maximum number of nodes in the autoscaling pool."
  type        = number
  default     = 3

  validation {
    condition     = var.pool_max_size == 3
    error_message = "The pilot pool maximum size must be 3."
  }
}

variable "tags" {
  description = "Tags applied to supported Scaleway resources."
  type        = list(string)
  default     = ["managed-by=terraform", "environment=dev", "pilot=kapsule"]

  validation {
    condition     = length(var.tags) > 0 && alltrue([for tag in var.tags : length(trimspace(tag)) > 0])
    error_message = "tags must contain at least one non-empty value."
  }
}

check "network_cidrs_do_not_overlap" {
  assert {
    condition     = !local.network_cidrs_overlap
    error_message = "private_network_cidr, pod_cidr, and service_cidr must not overlap."
  }
}
