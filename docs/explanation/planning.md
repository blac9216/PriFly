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

Zero unresolved blocking concerns before decomposition.

### Gate 2 — Delivery Readiness

Before release, requirements/design/work traceability is complete under declared policy; dependencies are valid and acyclic; slices are bounded; early integrated/testable value exists; Work Items have Goal/Outcomes/Constraints/Verification; verification design survived fresh challenge; and the plan survived fresh adversarial review.

PriFly claims deterministic enforcement of declared gates, **not mathematical proof that AI discovered every possible semantic concern**.

## Baselines, Change Requests, and impact uncertainty

Released planning state uses immutable versioned baselines. Semantic changes use typed Change Requests. Impact classification is AFFECTED, PROVEN_UNAFFECTED, or UNKNOWN. UNKNOWN never means safe to continue: AFFECTED work pauses/revalidates; UNKNOWN work conservatively revalidates; only PROVEN_UNAFFECTED work continues without revalidation.

Code-intelligence providers can provide evidence toward PROVEN_UNAFFECTED, but absence of a discovered edge never proves non-impact. Where PriFly cannot soundly narrow impact, it broadens invalidation/revalidation.

## Findings and triage

A Finding is not automatically a Work Item. Dispositions include current-work correction, bounded Candidate, planning amendment, new Planning Record, duplicate, or no action with rationale. Findings/review verdicts are AUTHORITATIVE semantic state.

## Initiative closure and lessons

Initiative closure requires terminal released Work Items, required validation, no unresolved blocking Findings/owner decisions, reconciled provider projection, and explicit residual risks. Factory computes deterministic metrics, then may run a bounded independently reviewed lessons analysis.

```text
Observation
→ Lesson Candidate
→ reviewed Lesson
→ repeated evidence
→ Recommendation
→ owner/policy decision
```

Factory does not autonomously rewrite Constitution or routing policy.
