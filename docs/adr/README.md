# Architecture decision records

Architecture decisions are immutable once accepted. A superseding decision must add a new ADR and link to the previous record.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-use-scaleway-kapsule.md) | Use Scaleway Kapsule for managed Kubernetes | Accepted |
| [0002](0002-filter-the-public-kapsule-api.md) | Filter the public Kapsule API with explicit ACLs | Accepted |
| [0003](0003-use-private-workers-with-gateway-egress.md) | Use private workers with Public Gateway egress | Accepted |
| [0004](0004-bootstrap-remote-state-and-ci-identity.md) | Bootstrap remote state and CI identity separately | Accepted |
| [0005](0005-defer-intercloud-integration.md) | Defer inter-cloud integration beyond the autonomous pilot | Accepted |
| [0006](0006-reject-scaleway-dns-for-kapsule-tls.md) | Reject Scaleway DNS and DNS-01 for public `*.biolevatecloud.com` TLS | Accepted |
| [0007](0007-biolevate-cloud-is-private-netbird-dns.md) | `*.biolevate.cloud` is private Netbird DNS | Accepted |
