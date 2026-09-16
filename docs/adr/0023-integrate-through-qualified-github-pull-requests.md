# ADR-0023: Integrate through qualified GitHub pull requests

Status: Proposed
Supersedes: 0012
Amends: 0021
Date: 2026-09-16

## Context

ADR-0012 selected exact expected-base target-ref integration and treated PRs as projections. [PRD v2.1](../reference/product-requirements.md) §17 instead explicitly requires GitHub PR merge and rejects claiming that its expected-head parameter is an expected-base CAS. This replaces ADR-0012 and amends only ADR-0021 Decision item 8's example of exact-ref integration; its quality-layer separation remains intact. Owner direction is recorded in issue #36.

## Decision Drivers

- All v1 integration must have a provider PR and observe repository protection.
- Evidence must bind exact candidates without attributing unsupported atomic base guarantees to GitHub.
- Exact Worker commits and host-loss-recoverable checkpoints remain required.

## Considered Options

### Factory publishes candidate branches and requests protected GitHub PR merges

Selected by the PRD. Fits the owner workflow and provider checks, with explicit provider qualification and actual merged identity.

### Factory builds M and atomically updates target B to M

ADR-0012's former choice supplies an exact-base condition but violates the new PR-only integration requirement.

These alternatives compare the supplied product direction with the prior documented mechanisms; they do not reconstruct an unrecorded owner interrogation.

## Decision

Workers commit on assigned branches. Factory's trusted Branch Publisher preserves exact Git objects and proves remote reconstructibility without executing Worker-controlled privileged hooks/configuration. Provider Broker creates/updates the PR before review and requests merge only after exact candidate acceptance and all required repository checks/reviews. The merge request binds expected PR head. Factory serializes its requests per target and qualifies actual base-race/check/protection behavior; it never claims an expected-base CAS or bypasses the PR by pushing the target. A changed candidate receives fresh review. Only an observed merge records INTEGRATED and the actual merged revision; ambiguous requests retain their obligations and conflicts.

## Consequences

The separate exact-integration-commit certificate/target-ref operation is removed from current contracts. Required native approval needs an eligible distinct provider identity. Stronger combined-tree guarantees require a qualified profile; they cannot be simulated by bypass. Accepted candidate identity, observed merge identity and later validation remain separate.

Canonical contracts: [documentation index](../README.md) and [source traceability](../reference/traceability.md). Proposed here for independent review; no implementation certification is implied.
