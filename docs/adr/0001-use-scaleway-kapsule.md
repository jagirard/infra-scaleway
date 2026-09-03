# ADR 0001: Use Scaleway Kapsule

- Status: Accepted
- Date: 2026-08-26

## Context

The platform needs a Scaleway Kubernetes foundation comparable in operational responsibility to the existing AKS foundation. The initial scope is a development pilot, not a multi-cloud worker cluster.

## Decision

Use a mutualized Scaleway Kapsule cluster in `fr-par` with Cilium and an explicit Kubernetes patch version.

Keep the Terraform stack under `kapsule/00-kapsule` and environment configuration under `kapsule/environments/<env>`, matching the repository conventions used by `infra-aks`.

## Consequences

- Scaleway operates the Kubernetes control plane.
- The pilot avoids the additional complexity of Kosmos external nodes.
- Kubernetes upgrades remain explicit Terraform changes.
- Dedicated control-plane offers can be evaluated later without changing the repository ownership model.
