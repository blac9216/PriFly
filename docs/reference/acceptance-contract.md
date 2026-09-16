# Acceptance contract

Kind: reference

## Three separate judgments

Acceptance composes separately inspectable results:

1. **Engineering quality:** the exact policy-selected versions in [Quality rubrics](quality-rubrics.md), including the applicable acceptance, verification, product-quality, security and documentation criteria.
2. **Project conformance:** the candidate satisfies the governing Requirements, Design, Constraints, baselines, Work Item and predeclared thresholds.
3. **Workflow eligibility:** authority, freshness, independent review, lifecycle state, Findings, evidence durability and publication permit the transition.

A pass in one does not substitute for a failure or blocking `UNKNOWN` in another. A criterion's project-specific threshold is fixed before the result is observed. Acceptance cannot invent or weaken it.

## Exact subject and immutable certificate

An Acceptance Certificate binds the exact Candidate, Work Item revision, producing attempt, repository/branch/commit, relevant base observations, governing Design and Delivery Baseline revisions, Verification definition, policy/profile versions, Rubric Evaluations, independent Review Result, and Acceptance Evidence Manifest. A base observation is evidence about a particular review context, not a claim that the GitHub merge API offers an expected-base compare-and-swap.

The certificate is immutable. Its **current usability** is a separate revision-controlled projection: changed candidates, revoked authority, relevant baseline or policy changes, unresolved blockers, or loss of supported evidence can prevent further use without rewriting the historical decision. Late results from cancelled or superseded attempts cannot revive authority.

## Evidence credibility and independence

Reviewer is independent of the producer; every test process need not be. Reviewer may accept attributable Implementer or CI evidence that covers the exact subject and required check, is credible, and meets the pinned evidence-independence policy. Missing or insufficient evidence is gathered during the same review where its envelope permits. Running a check does not create an infinite review-of-review chain.

Required independent checks are selected by the project/risk profile before acceptance. A changed candidate requires a fresh review. A producer's unsupported assertion that tests passed is not evidence. Record actual, skipped and failed checks; subject/configuration identity; tools/environment where material; results and limitations; and durable evidence references.

See [Review](../explanation/review.md), [Attack profiles](attack-profiles.md), and [RP-08](deployment-parameters.md#fixed-direction-versus-unselected-parameters). No universal independently reconstructed integration commit or separate Verification Runner is required by this design.

## Evidence publication and retention

The Acceptance Evidence Manifest separates required evidence, optional diagnostics and code recovery roots. Required external objects carry immutable digest, location, size/kind and retention/root membership. Required rubric, verification and conformance results belong in this manifest; optional raw logs may expire only when they are not necessary to support the decision.

```text
exact candidate and attributable evidence
→ required quality and conformance evaluations
→ independent review and required finding dispositions
→ upload and verify required evidence identities
→ record manifest and retention pins in SQLite
→ remote database durability and coordination publication
→ release the Acceptance Certificate
```

Pending uploads, unverified required objects, or applicable blocking `FAIL`/`UNKNOWN` prevent release. Supported Recovery Root Manifests protect historical evidence, Git recovery roots and key generations. Root retirement must be authoritative before cleanup; uncertain reachability retains data.

## Acceptance is not integration, validation or release

Factory's Broker integrates only through the admitted GitHub PR merge operation. It checks the accepted head and current merge eligibility, represents native head/base guarantees honestly, and records the actual merge receipt. Concurrent-base safety must be established by the qualified checks/protection profile, not assumed from a pre-send read. No direct target-branch push is a fallback. See [Git integration](../explanation/git-integration.md) and [Provider operation profiles](provider-operation-profiles.md).

`INTEGRATED` does not mean `VALIDATED` or released. Validation assesses versioned targets in the representative integrated environment. A Release Manifest names its exact repository version set and applicable validated targets; multi-repository publication is not an atomic distributed merge. [Validation](../explanation/validation.md) and [Release and closeout](../explanation/release-and-closeout.md) own those later gates.
