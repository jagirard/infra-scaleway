# kapsule-infra

Infrastructure-as-code folder for Scaleway Kapsule.

This folder provisions the Scaleway Kubernetes runtime foundation: remote state prerequisites, VPC networking, Private Network, controlled egress, Kapsule cluster, API ACL, and private worker pool.

## What this folder is for

Use `kapsule` to:

- bootstrap the Terraform state bucket and GitHub Actions IAM identity when they do not already exist,
- provision Kapsule clusters and node pools per environment,
- configure the VPC, Private Network, Public Gateway, NAT egress, and node security group,
- restrict the public Kapsule API endpoint to approved CIDRs,
- validate nodes, DNS, egress, private LoadBalancer provisioning, and dynamic storage.

Azure, NetBird, private DNS, Helm, and Onizuka integrations are deferred to later lots.

## Repository layout

- `bootstrap/`: optional one-time local-state stack for the Object Storage backend and CI IAM application.
- `00-kapsule/`: main Terraform stack for Kapsule and network dependencies.
- `environments/<env>/`: backend and variables per environment.
- `scripts/`: post-deployment runtime validation.

Known environments:

- `scw-dev-01`

## Why bootstrap exists

Terraform cannot store the Kapsule stack state in an Object Storage bucket that does not exist yet. The CI identity that operates the stack also has to exist before the first CI plan.

The `bootstrap` stack breaks this dependency cycle:

1. an operator runs it once with temporary privileged Scaleway credentials,
2. it creates a private, versioned state bucket,
3. it creates a project-scoped IAM application and policy,
4. the operator creates the application API key outside Terraform,
5. `00-kapsule` then uses the bucket and identity.

The bootstrap intentionally keeps local state and does not create an API key, so no API key secret is stored in Terraform state. Preserve this state securely. If the bucket and CI identity are managed elsewhere, skip this stack and provide their existing values.

## Prerequisites

- Terraform 1.14.x
- a Scaleway organization and project
- provider credentials exported as `SCW_ACCESS_KEY` and `SCW_SECRET_KEY`
- backend credentials exported as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
- `kubectl` for runtime validation
- an approved stable public egress CIDR for the Kapsule API allowlist

Do not place credentials in Terraform files, backend files, command-line arguments, or Git history.

## Operations runbook

### 1. Bootstrap state and CI identity

Skip this step when equivalent resources already exist.

```bash
cp kapsule/bootstrap/terraform.tfvars.example kapsule/bootstrap/terraform.tfvars
terraform -chdir=kapsule/bootstrap init
terraform -chdir=kapsule/bootstrap plan -out=bootstrap.tfplan
terraform -chdir=kapsule/bootstrap apply bootstrap.tfplan
```

Create an API key manually for the IAM application ID returned by:

```bash
terraform -chdir=kapsule/bootstrap output -raw ci_application_id
```

Store the access and secret keys directly in the protected GitHub environment `scaleway-dev`.

### 2. Select the environment

```bash
cp kapsule/environments/scw-dev-01/backend.tfvars.example kapsule/environments/scw-dev-01/backend.tfvars
cp kapsule/environments/scw-dev-01/variables.tfvars.example kapsule/environments/scw-dev-01/variables.tfvars
```

Replace all placeholders and verify that the Private Network (`172.30.0.0/20`), pod (`172.31.0.0/16`), and service (`172.29.0.0/20`) CIDRs do not overlap with any Azure, on-premises, VPN, or NetBird range.

### 3. Initialize Terraform

```bash
cd kapsule/00-kapsule
terraform init -backend-config=../environments/scw-dev-01/backend.tfvars
```

### 4. Plan

```bash
terraform fmt -check -recursive ../..
terraform validate
terraform plan \
  -var-file=../environments/scw-dev-01/variables.tfvars \
  -lock-timeout=10m \
  -out=plan.out
```

Confirm that:

- the ACL contains only approved CIDRs and never `0.0.0.0/0`,
- workers have `public_ip_disabled = true`,
- the Gateway Network enables masquerade and pushes the default route,
- `delete_additional_resources = false`,
- no resource targets Azure or inter-cloud connectivity.

### 5. Apply

```bash
terraform apply -lock-timeout=10m plan.out
```

### 6. Validate

Run from the repository root on an ACL-authorized network:

```bash
./kapsule/scripts/validate-cluster.sh
```

The script obtains the sensitive kubeconfig without printing it, validates the autonomous cluster, and removes its validation namespace by default.

## Known limitations

- The Kapsule control plane is public and ACL-filtered; it is not private.
- Scaleway initially creates a default open ACL before Terraform replaces it with the explicit allowlist.
- The current pilot has one worker pool in `fr-par-1`.
- Inter-cloud connectivity and shared private DNS are not part of Lots 1 to 3.
- Kubernetes-created load balancers and volumes are preserved when the cluster is deleted and require deliberate cleanup.
