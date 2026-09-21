# ADR 0007: `*.biolevate.cloud` is private Netbird DNS

- Status: Accepted
- Date: 2026-09-21
- Supersedes: the HTTP-01 / public-A-record treatment of `*.biolevate.cloud` on
  `kapsule-scw-dev-01` (helm-values TLS notes and the public wildcard
  `*.scw-dev1.biolevate.cloud`). Does not change [ADR 0006](0006-reject-scaleway-dns-for-kapsule-tls.md),
  which remains valid for public `*.biolevatecloud.com` hosts.

## Context

Platform DNS is split by zone:

| Zone | Reachability | Typical ingress |
| --- | --- | --- |
| `*.biolevatecloud.com` | Public Internet | `nginx` (public LoadBalancer) |
| `*.biolevate.cloud` | Private, Netbird only | `nginx-internal` (private LoadBalancer) |

On AKS this split is already in force: tenant hosts such as
`elise.dev1.biolevate.cloud` use `ingressClassName: nginx-internal` and
`external-dns: internal`.

On `kapsule-scw-dev-01` the same names (`elise.scw-dev1.biolevate.cloud`,
`admin.scw-dev1.biolevate.cloud`, …) were published on the public Azure DNS
zone `biolevate.cloud` as an unmanaged wildcard `*.scw-dev1` → public
LoadBalancer `51.15.141.169`, and served by the public `nginx` class so that
Let's Encrypt HTTP-01 could issue certificates. That made the private zone
reachable without Netbird.

Netbird split DNS was only an override (`scw-dev1.biolevate.cloud` → in-cluster
ingress IP). When Netbird was down, public Azure DNS answered and the hosts
were on the Internet.

## Decision

Treat every name under `*.biolevate.cloud` as private DNS, reachable only
through Netbird.

For Kapsule tenant hosts under `*.scw-dev1.biolevate.cloud`:

1. Do not publish A, AAAA, or CNAME records for those names in the public
   Azure DNS zone `biolevate.cloud`. Delete the unmanaged wildcard
   `*.scw-dev1`.
2. Serve them on `nginx-internal`, whose Service is a Scaleway **private**
   LoadBalancer (`service.beta.kubernetes.io/scw-loadbalancer-private: "true"`).
3. Resolve them only via Netbird split DNS / in-cluster CoreDNS hosts, pointing
   at the private ingress.
4. Do not use Let's Encrypt HTTP-01 for `biolevate.cloud`. HTTP-01 requires a
   publicly reachable name and would recreate the leak. Keep the already-issued
   TLS secret until a private issuance path exists; do not re-apply the
   `letsencrypt-prod-biolevate-cloud` Certificate.

Public hosts under `*.scw-dev.biolevatecloud.com` stay on the public `nginx`
controller and keep HTTP-01 as decided in ADR 0006.

## Consequences

- `elise.scw-dev1.biolevate.cloud` (and the other tenant hosts) no longer
  resolve on the public Internet. Access requires Netbird.
- Knowing the public LoadBalancer IP is not enough once the Ingress objects
  have left the public controller.
- Certificate renewal for those names cannot use HTTP-01. The current secret
  `scw-dev1-wildcard-certificates-letsencrypt-scw-dev1` remains in
  `scw-dev1-biolevate-apps` until a DNS-01 or private-CA path is chosen.
- Onizuka value generation for Kapsule must emit `nginx-internal` (not `nginx`)
  for tenant ingresses on `biolevate.cloud`.
- `external-dns` annotations on those Ingresses are still inert on this
  cluster; they must never be wired to the public Azure zone.
