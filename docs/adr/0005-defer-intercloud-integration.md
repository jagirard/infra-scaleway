# ADR 0005: Defer inter-cloud integration

- Status: Accepted
- Date: 2026-08-26

## Context

The target architecture will eventually connect Azure and Scaleway private networks through NetBird and provide shared private `biolevate.cloud` resolution. Changing both clouds during the initial provisioning would widen the failure domain and make the Kapsule foundation harder to validate independently.

## Decision

Lots 1 to 3 provision and validate Scaleway resources only.

Do not change Azure, NetBird, private DNS, Helm values, Onizuka, or cross-cloud routes until the autonomous Scaleway pilot satisfies its exit criteria and an inter-cloud approval gate is passed.

## Consequences

- The pilot can be tested and rolled back without affecting Azure.
- Private Azure services and shared private DNS are unavailable from Kapsule during these lots.
- Address ranges must still be checked for future non-overlap before provisioning.
- Later inter-cloud work must reference this ADR and define routing, DNS authority, and failure isolation.
