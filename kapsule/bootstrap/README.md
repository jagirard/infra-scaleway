# Kapsule bootstrap

This optional one-time Terraform stack creates prerequisites that must exist before the main Kapsule stack can initialize:

- a private, versioned Scaleway Object Storage bucket for remote Terraform state,
- a Scaleway IAM application for GitHub Actions,
- a project-scoped IAM policy for the required Scaleway products.

It does not create an IAM API key. Create that key manually and store it directly in the protected CI environment so its secret never enters Terraform state.

## When to use it

Use this stack for the first environment when the state bucket and CI application do not exist.

Skip it when those resources are managed by a central platform process. In that case, configure the existing bucket in `kapsule/environments/<env>/backend.tfvars` and the existing identity in CI.

## State handling

The bootstrap starts with local state because its purpose is to create the remote backend. Keep `kapsule/bootstrap/terraform.tfstate` encrypted, restricted, and backed up. Do not delete it after the first apply.

## Commands

From the repository root:

```bash
cp kapsule/bootstrap/terraform.tfvars.example kapsule/bootstrap/terraform.tfvars
terraform -chdir=kapsule/bootstrap init
terraform -chdir=kapsule/bootstrap plan -out=bootstrap.tfplan
terraform -chdir=kapsule/bootstrap apply bootstrap.tfplan
```

See [ADR 0004](../../docs/adr/0004-bootstrap-remote-state-and-ci-identity.md) for the decision and consequences.
