# ADR-0029: Admit external reviewed execution packages

Status: Proposed
Amends: 0008, 0022
Date: 2026-09-16

## Context

Justin wants Factory to implement Factory before autonomous planning is built. The accepted product requires exact planning baselines, engineering gates and separate owner releases. GitHub issue prose and producer assertions are insufficient execution authority.

## Decision Drivers

Earliest useful self-development; no second canonical database; auditable review independence and phase authority; bounded bootstrap scope; later internal planners must produce the same semantic artifacts.

## Considered Options

(1) Implement all native planning jobs before execution handover: stronger single-runtime provenance but substantially more work before use. (2) A typed external reviewed-package import: permits early execution and reuses the eventual artifact/gate semantics, but explicitly trusts registered external evaluator provenance. Blind issue execution was considered and fails governing requirements, so is not a valid alternative.

## Decision

Adopt the external admission and owner/API contracts: exact immutable bundles, registered external reviewer provenance bound by owner authority, deterministic gate/graph/coverage evaluation, three actual exact-package phase releases and no dispatch from import alone. External planning remains the supported path for follow-up/change work. Do not fabricate Factory attempts, historical review evidence or old phase releases. Unsupported planning scope is explicit.

## Consequences

Import trust is a first-class attack surface with admission and owner-capability conformance evidence. Factory can build its planning capabilities later without replacing execution records. Owner review must resolve the proposed external trust boundary before it can be treated as an admitted profile. Change to these authority semantics needs a new architectural decision, not only a schema tweak.

Refs: [owner scope and ratified research](https://github.com/blac9216/PriFly/issues/38), [architecture](../explanation/architecture.md), [parameters](../reference/deployment-parameters.md), [conformance](../reference/conformance.md). This is a proposal, not a record that the new narrowed choice already received owner approval.
