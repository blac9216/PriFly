# Acceptance contract

Kind: reference

## Acceptance layers

A candidate is not accepted on a single undifferentiated “looks good” judgment. Acceptance composes three separately inspectable results:

1. **Standards-backed quality** — applicable profiles from [Quality rubrics](quality-rubrics.md), including `acceptance-quality/v1`, required Verification/Validation profiles, and applicable product/security/accessibility/supply-chain/documentation profiles.
2. **Project conformance** — exact candidate behavior/implementation conforms to the governing Planning Baseline, Work Item, Requirements, Design, Constraints, and predeclared project-specific acceptance thresholds.
3. **PriFly workflow eligibility** — exact subject freshness, independent evidence/review, lifecycle state, authority, Findings, evidence durability, and publication rules all permit acceptance.

A pass in one layer cannot substitute for a failure/`UNKNOWN` in another.

## Acceptance subject

PriFly accepts an exact candidate, not an abstract Work Item. An immutable Acceptance Certificate binds at least the Planning Baseline, Work Item revision, implementation job attempt, exact candidate Git commit, target repository, exact target/base revision, verification-plan revision, exact applicable quality-rubric profile/evaluation versions, Acceptance Evidence Manifest, Reviewer verdict, and governing policy version. Relevant changes invalidate current use of the certificate rather than carrying acceptance forward to a different subject.

## Standards-backed acceptance quality

`acceptance-quality/v1` requires, at minimum, predeclared measurable criteria, exact subject identity, required V&V completion, applicable product-quality satisfaction, documentation/configuration readiness where relevant, explicit deviations/Findings, residual-risk disposition, credible evidence provenance, and a recorded acceptance decision.

Other profiles compose according to project scope:

- `verification-plan-quality/v1` and/or `validation-plan-quality/v1`;
- `product-quality-evaluation/v1` for applicable product-quality Requirements;
- `security-engineering-quality/v1`;
- `documentation-quality/v1`;
- WCAG/ASVS/SLSA or other activated conditional profiles;
- any additional standards profile declared by the governing Planning Baseline.

Project-specific thresholds required to turn a standards-backed quality dimension into PASS/FAIL must already be fixed in the Planning Baseline. A missing threshold is blocking `UNKNOWN`; Review/Acceptance may not invent one after observing the candidate.

## Acceptance Evidence Manifest

Before acceptance can be released, Factory builds an immutable manifest separating required evidence, optional diagnostics, and code recovery roots. Required evidence includes the exact blocking quality-rubric evaluation results required by policy as well as machine-observed V&V evidence and project-conformance evidence. Every required external object carries immutable content identity/hash, storage location, size/kind, and retention/root membership. Optional logs/raw context may expire unless policy made them required.

## Publish-before-acceptance ordering

```text
produce candidate/evidence
→ complete required quality evaluations
→ complete exact project-conformance evaluation
→ independent Review resolves required findings
→ upload required evidence to R2 / durable store
→ verify object identity/presence
→ construct Acceptance Evidence Manifest
→ record manifest + retention pins in authoritative SQLite transaction
→ remote database durability + coordination publication
→ release Acceptance Certificate
```

Factory may not authoritatively accept a result while required evidence or an applicable blocking quality/conformance criterion is `FAIL`, unresolved `UNKNOWN`, pending, or unverified.

## Recovery-root closure

Each supported recovery/rollback checkpoint has an immutable Recovery Root Manifest identifying the external dependencies needed to honor the authoritative state contained in that checkpoint, including required R2 evidence/artifacts, accepted Git commit/ref recovery roots, required quality/V&V evaluation evidence, and required key/secret generations. Cleanup protects both current pins and every supported Recovery Root Manifest. Retiring a root is authoritative; uncertain reachability leaks storage rather than deleting a potentially required object.

## Attempt identity and integration freshness

Results carry exact job-attempt identity. Late results from cancelled/superseded attempts cannot revive old work. Candidate implementation is verified/reviewed, then an exact integration subject is constructed against the current target and independently verified before merge eligibility. A target/base change invalidates integration eligibility unless the admitted protocol validates the exact resulting integration subject.

A candidate Acceptance Certificate remains an immutable binding to the candidate subject; later integration eligibility binds the exact integration subject separately rather than editing the original certificate.

## Independent Verification Runner

Producer-supplied “tests passed” is not acceptance evidence. Factory launches independent verification against the exact candidate/integration subject using the exact Verification definition that already passed `verification-plan-quality/v1`. The runner records actual/skipped checks, exact candidate/base/integration identity, Verification revision, environment/tool identity where material, observed results, and required evidence identities/provenance.

AI Review then judges whether those independently observed facts satisfy the predeclared Verification and semantic Required Outcomes. Material changes to the Verification plan or acceptance threshold require the governing change/review path.

## Multi-repository delivery

PriFly may validate a multi-repository Release Set. v1 does not claim atomic distributed merge; each repository integration independently satisfies its exact-target contract while planning tolerates partial sequential delivery through compatibility design, sequencing, flags, or migrations.
