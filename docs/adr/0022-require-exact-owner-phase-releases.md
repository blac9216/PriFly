# ADR-0022: Require exact owner phase releases independently of quality gates

Status: Proposed
Amends: 0008, 0010
Date: 2026-09-16

## Context

The revised product direction separates recording an idea, authorized architecture, delivery planning and execution. This amends ADR-0008's baseline/release boundary and clarifies ADR-0010's consequential owner actions. The source is the owner's PRD Candidate 2.1 §§8–11 and explicit reconciliation request in issue #36; it does not grant execution release.

## Decision Drivers

- Saving an idea must not fan out project Workers or provider planning objects.
- The owner needs a coherent, reviewable package and annotation history before each phase.
- Passing engineering criteria and having owner authority are independent obligations.

## Considered Options

### Exact-package owner releases plus independent engineering gates

The selected PRD design gives the owner control of scope and budget while allowing bounded work within a released phase.

### Gate-driven progression from a saved Planning Record

The earlier documentation permitted reading a successful gate as release. It reduces confirmation steps but can start unwanted planning or implementation.

These alternatives compare the supplied product direction with the prior documented mechanisms; they do not reconstruct an unrecorded owner interrogation.

## Decision

Intake records owner needs without project dispatch. A separately authorized investigation is bounded to its question. Architecture, design approval/delivery planning, and execution each require an owner-confirmed package identity, revision/digest, scope and budget. Design Completeness and Delivery Readiness remain separate required engineering gates. Design and Delivery Baselines bind the same package the owner confirmed. Material replacement or scope expansion requires the applicable renewed release; replacing an attempt within unchanged authorized scope does not. Review Packages expose the resulting canonical docs, diffs, diagrams, evaluations and annotation dispositions.

## Consequences

Factory must retain releases, packages and annotations as canonical state and validate them at dispatch. The owner can revise a package without silently approving its replacement. Documentation PR approval and future product execution remain distinct.

Canonical contracts: [documentation index](../README.md) and [source traceability](../reference/traceability.md). Proposed here for independent review; no implementation certification is implied.
