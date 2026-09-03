output "state_bucket_name" {
  description = "Name of the versioned private Terraform state bucket."
  value       = scaleway_object_bucket.terraform_state.name
}

output "state_bucket_endpoint" {
  description = "S3-compatible endpoint for the Terraform backend."
  value       = "https://s3.${var.region}.scw.cloud"
}

output "ci_application_id" {
  description = "IAM application ID for the manually created CI API key."
  value       = scaleway_iam_application.github_actions.id
}

output "ci_policy_id" {
  description = "Project-scoped IAM policy ID assigned to the CI application."
  value       = scaleway_iam_policy.github_actions.id
}
