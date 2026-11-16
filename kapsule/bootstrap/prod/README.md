# Production identity bootstrap

This separate local-state stack creates the IAM application and project-scoped policy for `kapsule-scw-prod-01`.

It does not create:

- a Scaleway project,
- an Object Storage bucket,
- an IAM API key.

Create the production project in the Scaleway console first. Reuse the private versioned state bucket created by [`../`](../README.md). Set `state_bucket_project_id` to the project that already owns that bucket. The second policy rule grants only object-storage access there, so the production identity can use the existing state key without receiving the development project's other permissions. Create the API key manually after apply so its secret never enters Terraform state.

This stack is intentionally separate from the original bootstrap. Reapplying `kapsule/bootstrap` with production identifiers would try to manage the existing development bucket and identity.

Keep `terraform.tfstate` in this directory encrypted, access-restricted, and backed up. Do not commit it.
