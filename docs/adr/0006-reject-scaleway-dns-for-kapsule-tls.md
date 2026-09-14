# ADR 0006: Reject Scaleway DNS and DNS-01 for Kapsule TLS

- Status: Accepted
- Date: 2026-09-13

## Context

`kapsule-scw-dev-01` needs TLS certificates for six public hosts under
`scw-dev.biolevatecloud.com`. Two ACME challenge types were considered: HTTP-01, which
validates over the public ingress, and DNS-01, which validates by writing a TXT record.

DNS-01 was attractive on paper: it does not depend on public exposure, it supports
wildcards, and it would have paired with `external-dns` using the Scaleway provider to
automate the ingress records. cert-manager has no built-in Scaleway solver, but Scaleway
publishes a maintained ACME webhook (chart `scaleway-certmanager-webhook` 0.4.3), whose
Kubernetes libraries match this cluster's control plane at v1.36.1.

Investigation established where the zone actually lives:

- `biolevatecloud.com` is authoritative on **Azure DNS** (`ns1-04.azure-dns.com` and
  peers), in subscription `biolevate-dev`, resource group `rg-hub`, with 300 record sets
  serving production.
- The Scaleway account held **no public DNS zone**, only a VPC `privatedns` zone.
- `scw-dev.biolevatecloud.com` did not exist; Azure answered `NXDOMAIN`.

A dedicated Terraform stack was written to create the zone and its records. It validated
and planned cleanly — `7 to add, 0 to change, 0 to destroy` — but `apply` failed at the
first resource:

```
Error: scaleway-sdk-go: http error 403 Forbidden: domain not found
```

This is not a permissions problem: the credential used belongs to the account owner.
Scaleway refuses to create a DNS zone under a domain that is absent from the account. The
prerequisite is to register `biolevatecloud.com` as an **external domain**, validated by a
`_scaleway-challenge` TXT record published in the Azure zone.

That prerequisite is the reason for this ADR. Scaleway's external-domain flow is designed
for taking over an entire domain, and its documented final step is repointing the root
nameservers to `ns0.dom.scw.cloud` / `ns1.dom.scw.cloud`. Performing that step on
`biolevatecloud.com` would move authority for all 300 production record sets away from
Azure DNS. Scaleway further states that the external domain is deleted if the process is
not completed within 14 days, and it is not established that TXT validation alone keeps it
alive indefinitely when only a subdomain zone is used.

## Decision

Do not register `biolevatecloud.com` with Scaleway, do not delegate
`scw-dev.biolevatecloud.com`, and do not use DNS-01 on Kapsule.

Use **HTTP-01** against the public ingress LoadBalancer, with the six ingress A records
held directly in the Azure parent zone.

The trade the rejected option asked for was poor: it put the production DNS of the whole
platform at risk to serve one development cluster, in exchange for benefits that do not
apply here. The ingress is public, so HTTP-01's exposure requirement is already satisfied,
and no wildcard certificate is required — the six hosts are enumerated and stable.

Remove the `kapsule/01-dns` Terraform stack. Terraform that must never be applied is a
trap: the directory invites `terraform apply`, and a README is weaker protection than not
shipping the code. The reasoning worth preserving is this ADR, not the resources.

## Consequences

- HTTP-01 is proven end to end on this cluster. All six production certificates were
  issued by Let's Encrypt on 2026-09-13 and expire 2026-12-12.
- Certificate renewal now depends on `/.well-known/acme-challenge/` staying reachable over
  plain HTTP. See the renewal risk recorded in the `biolevops-helm-values` TLS README for
  `kapsule-scw-dev-01`.
- Wildcard certificates are unavailable on this cluster. Adding a seventh public host means
  adding an A record and a `Certificate`.
- **The six A records are unmanaged.** `biolevatecloud.com` is not an `azurerm_dns_zone` in
  `infra-aks` — it appears there only as a role-assignment scope string — so the records
  exist in no Terraform state and no `external-dns` scope. Nothing recreates them. This is
  accepted debt, recorded so that it is not rediscovered during an incident.
- An empty `kapsule/scw-dev-01/dns.tfstate` object remains in the state bucket. It holds no
  resources and can be removed at any time.
- Revisiting DNS-01 requires either Scaleway confirming that TXT validation alone sustains
  an external domain used only for a subdomain zone, or moving to cert-manager's native
  `azureDNS` solver. The latter was also rejected: Kapsule's OIDC issuer is
  `https://kubernetes.default.svc.cluster.local`, unreachable publicly, so Azure Workload
  Identity federation is impossible and only a long-lived service principal secret scoped
  to the production zone would work.
