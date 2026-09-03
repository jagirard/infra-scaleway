# ADR 0003: Use private workers with gateway egress

- Status: Accepted
- Date: 2026-08-26

## Context

Kubernetes workers need outbound access for image pulls and managed services, but they do not require direct public addresses.

## Decision

Attach Kapsule to an explicit Private Network. Disable public IPs on the worker pool and route outbound traffic through a Scaleway Public Gateway with a Flexible IP, masquerade, and default-route propagation.

Apply a stateful node security group that drops unmatched inbound traffic and permits traffic from the Private Network.

## Consequences

- Workers have no direct public IPv4 address.
- Outbound traffic uses a stable gateway address.
- Public Gateway health becomes a runtime dependency for image pulls and external access.
- Additional worker zones require corresponding zonal gateway and security-group review.
