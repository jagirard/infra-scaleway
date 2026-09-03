variable "project_id" {
  description = "Scaleway project UUID used by the development pilot."
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

variable "state_bucket_name" {
  description = "Globally unique Object Storage bucket name for Terraform state."
  type        = string

  validation {
    condition = (
      length(var.state_bucket_name) >= 3 &&
      length(var.state_bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.state_bucket_name)) &&
      !can(regex("\\.\\.", var.state_bucket_name))
    )
    error_message = "state_bucket_name must be a valid globally unique S3 bucket name."
  }
}

variable "region" {
  description = "Scaleway Object Storage region."
  type        = string
  default     = "fr-par"

  validation {
    condition     = var.region == "fr-par"
    error_message = "This bootstrap is restricted to the fr-par region."
  }
}

variable "zone" {
  description = "Scaleway default zone."
  type        = string
  default     = "fr-par-1"

  validation {
    condition     = var.zone == "fr-par-1"
    error_message = "This bootstrap is restricted to the fr-par-1 zone."
  }
}

variable "ci_application_name" {
  description = "Name of the IAM application used by GitHub Actions."
  type        = string
  default     = "infra-scaleway-github-actions"

  validation {
    condition     = length(trimspace(var.ci_application_name)) >= 3
    error_message = "ci_application_name must contain at least three characters."
  }
}
