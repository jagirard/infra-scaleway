# Runbook: kapsule-scw-prod-01

## Operating boundaries

This runbook creates only the Terraform foundation for the sovereign production cluster.

Stop if a plan contains Azure resources, NetBird, DNS records, Helm releases, Onizuka, or any resource outside the dedicated production Scaleway project.

The initial topology intentionally matches development:

- Region: `fr-par`
- Zone: `fr-par-1`
- Cluster: `kapsule-scw-prod-01`
- Two autoscaled pools in `fr-par-1`:
  - `kapsule-scw-prod-01-workers`: `GP1-XS`, minimum 0, initial 0, maximum 0. Kept as an empty pool. Workloads drained from this pool are scheduled on the GP1-M pool.
  - `kapsule-scw-prod-02-workers`: `GP1-M` (16 vCPU / 64 GiB), minimum 3, initial 3, maximum 10, label `NodeType=apps`. This pool is where pods with a 16 GiB memory limit can schedule.
- Gateway: `VPC-GW-S`
- Private Network: `172.28.0.0/20`
- Pods: `172.27.0.0/16`
- Services: `172.26.0.0/20`
- State key: `kapsule/scw-prod-01/terraform.tfstate` in the existing state bucket

One zone means one failure domain. Do not describe this rollout as highly available.

## 1. Create the isolated project

Create a new Scaleway project for production. Do not reuse `c1b38e1f-9d02-40a0-8e70-c1973b2862ad`.

Record the new project UUID and the existing organization UUID.

## 2. Bootstrap only the production identity

The original `kapsule/bootstrap` stack already owns the state bucket and development identity. Do not apply it again with production values.

```bash
cp kapsule/bootstrap/prod/terraform.tfvars.example kapsule/bootstrap/prod/terraform.tfvars
```

Set the production project UUID, the organization UUID, and `state_bucket_project_id` to the project that owns `biolevate-poc-tfstate-01`. The production policy keeps full permissions on the production project and grants only object-storage permissions on the state-bucket project. Then review and apply:

```bash
terraform -chdir=kapsule/bootstrap/prod init
terraform -chdir=kapsule/bootstrap/prod plan -out=bootstrap-prod.tfplan
terraform -chdir=kapsule/bootstrap/prod apply bootstrap-prod.tfplan
terraform -chdir=kapsule/bootstrap/prod output -raw ci_application_id
```

Create the API key manually on that IAM application. Store it in a protected operator secret store. Do not add a GitHub Actions apply workflow and do not commit the key.

Back up `kapsule/bootstrap/prod/terraform.tfstate`. It is local state and must stay out of Git.

## 3. Prepare the production configuration

```bash
cp kapsule/environments/scw-prod-01/backend.tfvars.example kapsule/environments/scw-prod-01/backend.tfvars
cp kapsule/environments/scw-prod-01/variables.tfvars.example kapsule/environments/scw-prod-01/variables.tfvars
```

In `backend.tfvars`, set `bucket` to the existing bucket name. Keep the key `kapsule/scw-prod-01/terraform.tfstate`.

In `variables.tfvars`:

- set the production `project_id`,
- keep the organization UUID,
- replace `api_allowed_cidrs` with approved stable egress CIDRs,
- confirm the CIDRs do not overlap development `172.29.0.0/20` through `172.31.0.0/16`, Azure `10.5.0.0/16` and `10.6.0.0/16`, or NetBird allocations.

## 4. Select the production credentials

`kapsule/scripts/export-scaleway-env.sh` defaults to the development project. Override both identifiers before sourcing it:

```bash
export SCW_ACCESS_KEY="<production-access-key>"
export SCW_SECRET_KEY="<production-secret-key>"
export SCW_DEFAULT_PROJECT_ID="<production-project-uuid>"
export SCW_DEFAULT_ORGANIZATION_ID="<organization-uuid>"
source kapsule/scripts/export-scaleway-env.sh
```

The production identity must be allowed to read and write the existing state bucket.

## 5. Plan and review

```bash
cd kapsule/00-kapsule
terraform init -backend-config=../environments/scw-prod-01/backend.tfvars -reconfigure
terraform fmt -check -recursive ../..
terraform validate
terraform plan \
  -var-file=../environments/scw-prod-01/variables.tfvars \
  -lock-timeout=10m \
  -out=plan.out
terraform show plan.out
```

Approve the plan only when all of these are true:

- the Scaleway project is the production project,
- the state key is `kapsule/scw-prod-01/terraform.tfstate`,
- the three production CIDRs are present and do not overlap reserved ranges,
- the ACL has no `0.0.0.0/0`,
- `public_ip_disabled` is true,
- the pool has one zone, `fr-par-1`,
- `delete_additional_resources` is false,
- the plan contains no Azure or inter-cloud resource.

## 6. Apply and validate

```bash
terraform apply -lock-timeout=10m plan.out
```

Run from an ACL-authorized network at the repository root:

```bash
./kapsule/scripts/validate-cluster.sh --terraform-dir kapsule/00-kapsule
```

Do not print the kubeconfig output.

## Known limits

- A failure of `fr-par-1` interrupts the whole cluster. The two pools share that zone.
- The Public Gateway is a shared egress dependency.
- The Kubernetes API remains public and ACL-filtered.
- Load balancers and volumes created by Kubernetes survive cluster deletion.
- Platform services are not part of this runbook.
