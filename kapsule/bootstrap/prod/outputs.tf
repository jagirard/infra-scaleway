output "ci_application_id" {
  description = "IAM application ID used to create the production API key manually."
  value       = scaleway_iam_application.production.id
}

output "ci_policy_id" {
  description = "Project-scoped IAM policy ID assigned to the production identity."
  value       = scaleway_iam_policy.production.id
}
