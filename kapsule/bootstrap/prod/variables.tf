variable "project_id" {
  description = "Dedicated Scaleway project UUID for the production Kapsule cluster."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", var.project_id))
    error_message = "project_id must be a valid lowercase UUID."
  }
}

variable "organization_id" {
  description = "Scaleway organization UUID owning the production project."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", var.organization_id))
    error_message = "organization_id must be a valid lowercase UUID."
  }
}

variable "state_bucket_project_id" {
  description = "Project that owns the existing Terraform state bucket. The production identity receives only object-storage permissions in this project."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", var.state_bucket_project_id))
    error_message = "state_bucket_project_id must be a valid lowercase UUID."
  }
}

variable "region" {
  description = "Scaleway region for the production identity."
  type        = string
  default     = "fr-par"

  validation {
    condition     = var.region == "fr-par"
    error_message = "This production bootstrap is restricted to the fr-par region."
  }
}

variable "zone" {
  description = "Scaleway default zone."
  type        = string
  default     = "fr-par-1"

  validation {
    condition     = var.zone == "fr-par-1"
    error_message = "This production bootstrap is restricted to the fr-par-1 zone."
  }
}

variable "ci_application_name" {
  description = "Name of the IAM application dedicated to the production Kapsule project."
  type        = string
  default     = "infra-scaleway-prod"

  validation {
    condition     = length(trimspace(var.ci_application_name)) >= 3
    error_message = "ci_application_name must contain at least three characters."
  }
}
