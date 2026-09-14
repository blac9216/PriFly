# Planning architecture

Kind: explanation

Planning is PriFly's highest-leverage subsystem. The design intentionally spends more rigor before decomposition, when the project trajectory is still cheap to change, and treats delivery feedback as evidence for future planning rather than allowing policy to rewrite itself.

The Planning Record is a graph of typed objects: Goal, Requirement, Constraint, Assumption, Question, Research Claim, Option, Decision, Design, Risk, Dependency, Impact, and Work Proposal.

```text
owner need
→ Goal
→ Requirement
→ Question
→ Research Claim
→ Decision
→ Design
→ Work Item
→ candidate code
→ Verification
→ Evidence
```

Changing an upstream object can invalidate downstream objects and Acceptance Certificates.

## Quality, project conformance, and workflow policy

PriFly deliberately separates three different questions that AI systems often blur together:

```text
INDUSTRY QUALITY
Is this Requirement/plan/architecture/verification/etc. good engineering?

PROJECT CONFORMANCE
Does it obey this Project's owner needs, Requirements, Design, Constraints and baseline?

PRIFLY WORKFLOW POLICY
Is it allowed to advance now?
```

General engineering quality is evaluated with the reusable standards-backed profiles in [Quality rubrics](../reference/quality-rubrics.md), whose pinned sources live in [Standards registry](../reference/standards-registry.md). Project conformance is evaluated against the actual Planning Baseline. PriFly workflow policy then applies authority, applicability, traceability, blocking-state, review independence and lifecycle rules.

This prevents two opposite failure modes:

- a work product cannot pass merely because it conforms to a weak/incomplete Design; general engineering quality is evaluated separately;
- a generally high-quality solution cannot pass if it violates this Project's governing Requirements/Design.

Where an industry standard defines a quality dimension but leaves the acceptable threshold context-dependent, the Planning Baseline fixes the target/range before affected Work Items are released. Reviewers do not invent thresholds after seeing the implementation.

## Planning Policy Envelope and effective authority

PriFly separates **proposed semantic classification** from **effective authorization**.

### Mandatory concern inventory

Factory owns a versioned mandatory concern inventory including product/user behavior, functional requirements, quality attributes, persisted data, migration/compatibility, security/trust, public/external contracts, recovery/destructive behavior, operations/observability, verification/testing, rollout/rollback, documentation/support, and dependency/risk. A concern family not covered by active policy remains `UNKNOWN` and cannot clear a blocking gate.

### Applicability state

Each concern has `proposed_applicability` and `effective_applicability`, each one of APPLICABLE, NOT_APPLICABLE, or UNKNOWN. A Worker may propose the first; only Factory policy establishes the second. UNKNOWN is conservative.

### Initial effective authority

- Constitution changes are owner-gated and cannot be suppressed by Worker classification.
- Security/trust-boundary changes are at least Strategic; N/A requires evidence and fresh independent review with no trigger/uncertainty.
- Persisted schema/state/migration concerns are forced applicable when declared persisted semantics change; N/A requires evidence and fresh review that no persisted compatibility behavior changes.
- Material destructive/data-loss/recovery semantics are at least Strategic and material residual risk requires owner action.
- Public/external compatibility changes are at least Project, Strategic when materially breaking.
- Material cross-project architecture is Strategic.
- Ordinary local implementation details may use standing Local delegation only when no protected trigger/UNKNOWN exists.
- Any mandatory concern without an explicit rule or adequate evidence/coverage remains UNKNOWN and blocking.

Absence of a rule never becomes permission.

### Protected triggers and delegation grants

Factory applies deterministic/procedural triggers where independently observable surfaces exist, such as declared persisted schema/migration changes, new external/public interfaces, auth/trust-boundary configuration changes, destructive/recovery operations, and cross-Project work. Trigger results retain provenance. If PriFly cannot determine the condition from an admitted observable surface, it records UNKNOWN rather than accepting a producer's “nothing changed” assertion.

Standing delegations are versioned owner/policy-authorized objects with scope, allowed classes, protected surfaces, expiry/version, and evidence/review requirements. Local authority is effective only inside an applicable delegation. Protected-surface change, uncertainty, or cumulative expansion outside the grant invalidates it and escalates.

A proposed NOT_APPLICABLE becomes effective only when an active policy rule names the path, required evidence exists, independent review passes, no protected trigger conflicts, required coverage is not UNKNOWN, and the assertion stays within any applicable delegation. A reviewed string alone is never authority.

## Planning completeness and adversarial review

Planning uses strict gates, not aggregate readiness thresholds; percentages are owner-facing diagnostics only.

### Gate 1 — Design Completeness

Design Completeness is not “the Architect thinks the design is done.” The quality layer normally requires successful standards-backed evaluations for Requirements, applicable quality Requirements, architecture description, architecture evaluation, material Risks, consequential evidence/provenance, and applicable secure-development concerns. Project conformance must show that the Design faithfully addresses the governing owner needs/Requirements/Constraints/Decisions. Workflow policy then requires zero unresolved blocking concerns, authority resolution, traceability and fresh challenge.

The exact profile composition is normative in [Planning policy](../reference/planning-policy.md).

### Gate 2 — Delivery Readiness

Delivery Readiness similarly composes standards-backed plan quality, Verification-plan quality, estimate quality where relevant, material risk quality, and applicable security/documentation obligations. Project conformance proves the decomposition and Verification faithfully cover the Design Baseline. Workflow policy separately checks dependencies, bounded slices, early integrated/testable value, lane/collision assumptions, fresh verification challenge, and fresh Plan Review.

Each Work Item still has Goal, Required Outcomes, Constraints, and Verification. Tests/commands are evidence mechanisms, not semantic Outcomes and not complete Verification definitions by themselves.

PriFly claims deterministic enforcement of declared gates, **not mathematical proof that AI discovered every possible semantic concern**.

## Baselines, Change Requests, and impact uncertainty

Released planning state uses immutable versioned baselines. Semantic changes use typed Change Requests. Impact analysis itself is evaluated using the standards-backed `change-impact-quality/v1` profile; PriFly then applies its project-specific downstream classification of AFFECTED, PROVEN_UNAFFECTED, or UNKNOWN.

UNKNOWN never means safe to continue: AFFECTED work pauses/revalidates; UNKNOWN work conservatively revalidates; only PROVEN_UNAFFECTED work continues without revalidation.

Code-intelligence providers can provide evidence toward PROVEN_UNAFFECTED, but absence of a discovered edge never proves non-impact. Where PriFly cannot soundly narrow impact, it broadens invalidation/revalidation.

## Findings and triage

A Finding is not automatically a Work Item. Dispositions include current-work correction, bounded Candidate, planning amendment, new Planning Record, duplicate, or no action with rationale. Findings/review verdicts are AUTHORITATIVE semantic state.

## Initiative closure and lessons

Initiative closure requires terminal released Work Items, required validation, no unresolved blocking Findings/owner decisions, reconciled provider projection, and explicit residual risks. General closure quality is evaluated using `closure-quality/v1` plus applicable acceptance/product/documentation profiles; project conformance and PriFly closure policy remain separate.

Factory computes deterministic metrics, then may run a bounded independently reviewed lessons analysis.

```text
Observation
→ Lesson Candidate
→ reviewed Lesson
→ repeated evidence
→ Recommendation
→ owner/policy decision
```

DORA-style delivery metrics may be used as diagnostic evidence for learning, not universal pass/fail thresholds. Factory does not autonomously rewrite Constitution or routing policy.
