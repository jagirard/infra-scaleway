# ADR 0004: Bootstrap remote state and CI identity separately

- Status: Accepted
- Date: 2026-08-26

## Context

The main Kapsule stack requires a remote Object Storage backend and a CI identity before its first initialization. Those prerequisites cannot be created by a stack that already depends on them.

## Decision

Keep a separate one-time stack under `kapsule/bootstrap`.

The bootstrap uses local state to create:

- a private, versioned Object Storage bucket,
- a project-scoped IAM application,
- the IAM policy required by Terraform and runtime validation.

Create the IAM API key outside Terraform so its secret is never persisted in Terraform state.

## Consequences

- The bootstrap local state must be encrypted, backed up, and retained.
- Bootstrap credentials require temporary IAM and Object Storage administration rights.
- The stack is optional when another platform process provides equivalent resources.
- Moving bootstrap state to remote storage requires a separate reviewed migration.
