# Planning authority and gate policy

Kind: reference

## Quality is not authority

Every transition separately evaluates standards-backed engineering quality, project conformance, and PriFly workflow eligibility. A complete or high-quality artifact cannot grant permission for the next phase. The independent engineering gate and the exact-package owner release must both permit progression.

| From | Required owner release | What becomes authorized |
|---|---|---|
| `INTAKE` | Requirements Review Package accepted and requirements-to-architecture release confirmed. | Architecture work within the released scope and envelope. Intake alone does not authorize architecture fan-out or provider-plan projection; bounded inquiry needs its own authority. |
| `ARCHITECTURE` | Exact Design Review Package approved and design-to-delivery-planning release confirmed, with Design Completeness satisfied. | Immutable Design Baseline and bounded delivery planning, not implementation. |
| `DELIVERY_PLANNING` | Exact Delivery Review Package approved and delivery-to-execution release confirmed, with Delivery Readiness satisfied. | Immutable Delivery Baseline and execution eligibility for its released Work Items. |

Releases bind package ID/revision/digest, Planning Record revision, scope, budget, limitations, dependencies and owner confirmation. A material package change cannot reuse an old confirmation. Annotation provenance and disposition remain in the review package. See [Planning](../explanation/planning.md), [Delivery planning](../explanation/delivery-planning.md), and [Pilot](../explanation/pilot.md).

## Effective applicability and delegation

Factory owns the mandatory concern inventory and versioned applicability rules. Product behavior, requirements, quality attributes, persisted data/migration, security/trust, external contracts, recovery/destructive behavior, operations, verification, rollout, documentation, dependencies and risk must be covered. Missing policy coverage or insufficient evidence is blocking `UNKNOWN`.

A Worker proposes `APPLICABLE`, `NOT_APPLICABLE` or `UNKNOWN`; Factory establishes effective applicability from the pinned rule, independently observable triggers and required review/authority. A producer's assertion cannot suppress a protected trigger. N/A requires the criterion's declared evidence and approval path; it is not a convenience waiver.

Local decisions are permitted only inside an applicable standing delegation. Project, Strategic and Constitutional changes follow their governing authority, as defined in [Change control](../explanation/change-control.md). Changes to trust, persisted state, external contracts, recovery or protected scope cannot be silently recast as local details. Uncertainty or cumulative expansion beyond a delegation stops dependent work and escalates.

## Design Completeness

The engineering gate applies the policy-selected versions of stakeholder-need, requirement, quality-requirement, architecture-description, architecture-evaluation, risk-record and evidence-provenance profiles, plus relevant security and conditional overlays. It evaluates traceability, coherent boundaries/interfaces, quality-attribute reasoning, evidence, alternatives, risk treatment and consistency with owner constraints.

All blocking applicable concerns must have disposition; required fresh independent challenge/review must be complete; relevant decisions must have authority; and traceability must support downstream impact. This is deterministic enforcement of declared criteria, not proof that AI discovered every possible concern. Passing the gate does not issue the owner's next-phase release.

## Delivery Readiness

The gate applies plan-quality, verification-plan-quality, estimate-quality and risk-record-quality, plus applicable security/documentation and project overlays. Work Item outcomes and constraints inherit relevant requirement-quality criteria. Validation plans receive their own applicable profile rather than being conflated with verification.

Coverage must connect baseline obligations to delivery and verification without orphan work. Dependencies must be valid and acyclic; Work Items and cumulative execution envelopes bounded; predicted footprints, collision lanes and estimates coherent; Verification and the plan independently challenged; no blocking Finding/`UNKNOWN` outstanding. Walking skeletons and `SLICE`-first decomposition are PriFly policy, not invented industry standards. An exceptional `ENABLER` requires its declared justification and downstream use.

## Thresholds, versions and unresolved parameters

Policy pins exact profile and criterion versions, applicability, blocking/advisory effect, stage, evidence rules and independence requirements. [Quality rubrics](quality-rubrics.md) defines engineering criteria; [Standards registry](standards-registry.md) identifies official sources; project baselines supply contextual thresholds. Neither source identity nor schema validity proves criterion satisfaction.

Performance, capacity, recovery time, accessibility/security/supply-chain targets and other source-delegated thresholds are selected before releasing dependent work and before observing implementation results. [Deployment parameters](deployment-parameters.md) identifies the unselected controls and qualification evidence. Missing licensed source interpretation or necessary evidence remains `UNKNOWN`; do not invent clauses, accept certification by assertion, or silently weaken the gate.

Implementation acceptance, integrated product validation, and release/closeout are later, distinct gates. [Acceptance contract](acceptance-contract.md) defines candidate acceptance; [Validation](../explanation/validation.md) defines target confidence; [Release and closeout](../explanation/release-and-closeout.md) defines fulfillment.
