# ADR 0002: Filter the public Kapsule API

- Status: Accepted
- Date: 2026-08-26

## Context

Kapsule does not provide the same private control-plane access model as the existing private AKS clusters. The Kubernetes API remains publicly addressed.

## Decision

Manage `scaleway_k8s_acl` in Terraform and require a non-empty list of explicit IPv4 CIDRs. Reject `0.0.0.0/0`.

Operators and CI must reach the API from stable approved egress addresses. The architecture must describe this endpoint as public and ACL-filtered, never as private.

## Consequences

- API access depends on stable operator or runner egress addresses.
- GitHub-hosted runner ranges are unsuitable for a narrow long-lived allowlist.
- Scaleway initially creates a default open ACL before Terraform replaces it, creating a short documented provisioning window.
- A future private connectivity feature requires a superseding ADR.
