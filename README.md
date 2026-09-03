# infra-scaleway

Global infrastructure repository for Scaleway platform operations.

The current scope contains one core infrastructure folder:

- `kapsule`: Scaleway Kapsule runtime foundation, including network, cluster, node pools, state bootstrap, and standalone validation.

Azure, NetBird, private DNS, Helm, and Onizuka integrations are intentionally outside Lots 1 to 3.

## Repository schema

```text
infra-scaleway/
|
+-- kapsule/
|   +-- bootstrap/                  # one-time state bucket and CI identity bootstrap
|   +-- 00-kapsule/                 # main Terraform stack
|   +-- environments/scw-dev-01/    # backend and variables per environment
|   +-- scripts/                    # runtime validation
|   +-- README.md                   # operating runbook
|
+-- docs/
    +-- adr/                        # architecture decision records
    +-- runbook-lots-1-3.md         # detailed delivery and validation runbook
```

## How to use this repository

Operate the Kapsule infrastructure from [`kapsule/README.md`](kapsule/README.md).

The `kapsule/bootstrap` stack solves the initial dependency cycle: the remote Terraform state bucket and the CI identity must exist before `kapsule/00-kapsule` can initialize its backend. It is applied once with local state. It is optional when an equivalent bucket and IAM application are provisioned by another platform repository.

## Common Terraform workflow

From `kapsule/00-kapsule`:

1. `terraform init -backend-config=../environments/<env>/backend.tfvars`
2. `terraform plan -var-file=../environments/<env>/variables.tfvars -out=plan.out`
3. `terraform apply plan.out`

See [`docs/adr`](docs/adr) for the decisions governing the current architecture.
