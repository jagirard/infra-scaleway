# ADR 0008: Start sovereign production on one zone and one pool

- Status: Accepted
- Date: 2026-10-10

## Context

`kapsule-scw-prod-01` is a new sovereign production cluster. It is independent from `aks-az-prod-01` and from the Scaleway development pilot.

The development foundation is already validated with one Public Gateway, one Private Network, one Kapsule control plane, and one private worker pool in `fr-par-1`. Multi-zone pools and separate system, application, and GPU pools would change scheduling, persistent-volume placement, and failure behavior before the production foundation is proven.

## Decision

Reuse the single `kapsule/00-kapsule` stack for production. Do not copy it.

Isolate production with:

- a dedicated Scaleway project,
- a dedicated IAM application and project-scoped policy created by `kapsule/bootstrap/prod`,
- the existing private versioned Object Storage bucket,
- the distinct state key `kapsule/scw-prod-01/terraform.tfstate`.

Keep the development topology for the first production rollout:

- region `fr-par`,
- one zone, `fr-par-1`,
- one autoscaled pool, initially `GP1-XS` with sizes 4/4/6,
- Public Gateway type `VPC-GW-S`,
- workers without public IPs,
- a public API filtered by an explicit ACL that rejects `0.0.0.0/0`.

Reserve these production CIDRs and reject reuse of the development ranges:

| Network | Production CIDR | Occupied range to avoid |
| --- | --- | --- |
| Private Network | `172.28.0.0/20` | Development `172.30.0.0/20` |
| Pods | `172.27.0.0/16` | Development `172.31.0.0/16` |
| Services | `172.26.0.0/20` | Development `172.29.0.0/20` |

Kapsule rejects pod and service CIDRs outside RFC 1918 and RFC 6598. `172.32.0.0/12` is outside that range, so production uses the last free `172.16.0.0/12` blocks below the development ranges.

Also keep these ranges clear: Azure `10.5.0.0/16`, Azure services `10.6.0.0/16`, and any allocated NetBird range.

Terraform remains locally operated. This decision does not enable a GitHub Actions apply workflow.

## Consequences

- A zone or pool failure takes the whole production cluster down. Multi-zone isolation is a later, explicit decision.
- Persistent volumes remain zonal and need their own backup and replication strategy.
- Helm, Onizuka, Infisical, NetBird, DNS, certificates, and application migration stay outside this foundation.
- The production API key is created manually and must not be stored in Terraform state or Git.
