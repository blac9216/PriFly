# Review and validation

Kind: explanation

PriFly treats independent adversarial verification as a lifecycle property, not merely a pull-request convention. Consequential AI-produced artifacts cannot promote themselves.

## What review evaluates

Every consequential Review distinguishes three questions:

1. **General engineering quality** — evaluate the exact artifact with the applicable standards-backed profile(s) from [Quality rubrics](../reference/quality-rubrics.md).
2. **Project conformance** — evaluate whether the artifact obeys the governing Requirements, Design, Constraints, Planning Baseline, Work Item, and other project-specific authority.
3. **PriFly workflow eligibility** — evaluate lifecycle state, required independence, authority, Findings, freshness, evidence completeness, and other promotion rules.

The Reviewer must not collapse these into one free-form judgment. A conforming artifact can still be poor engineering; a generally high-quality artifact can still violate the Project Design; neither advances when workflow conditions remain blocking.

Artifact-specific quality profiles are selected before the Review begins. The Reviewer records the exact rubric profile/version and criterion results; it cannot silently create a new quality bar after inspecting the work. If official-source ambiguity cannot be resolved, the affected criterion remains `UNKNOWN`.

The review process itself is evaluated using `review-inspection-quality/v1`, grounded in IEEE V&V and NASA peer-review/inspection guidance. This requires an exact subject, readiness, appropriate reviewer perspectives, the applicable artifact rubrics, separate project-conformance checks, evidence-backed Findings, completion criteria, outcome records, and required independence.

### Acceptance subject

PriFly accepts an exact candidate, not an abstract Work Item. An immutable Acceptance Certificate binds at least the Planning Baseline, Work Item revision, implementation job attempt, exact candidate Git commit, target repository and base revision, verification-plan revision, applicable quality-rubric evaluation refs, Acceptance Evidence Manifest, Reviewer verdict, and governing policy version. Relevant changes do not rewrite that certificate; they make it no longer current under the acceptance lifecycle projection.

### Acceptance Evidence Manifest

Before acceptance can be released, Factory builds an immutable manifest that separates required evidence, optional diagnostics, and code recovery roots. Required evidence can include machine-observed verification summaries, standards-backed quality evaluation results required by policy, required compatibility/migration/recovery objects, the exact verification execution manifest, and other artifacts explicitly required by policy. Every required external object carries immutable identity/hash, storage location, size/kind, and retention/root requirements fixed at acceptance time.

### Publish-before-acceptance ordering

```text
produce evidence
→ complete required quality + conformance evaluations
→ upload required evidence to R2 / durable store
→ verify object identity/presence
→ construct Acceptance Evidence Manifest
→ record manifest + retention pins in authoritative SQLite transaction
→ remote database durability + coordination publication
→ release Acceptance Certificate
```

Factory may not authoritatively accept a result while required evidence or required blocking quality/conformance evaluations are pending, failed, or unresolved.

### Recovery-root closure

Each supported recovery/rollback checkpoint has an immutable Recovery Root Manifest identifying the external dependencies needed to honor the authoritative state it contains, including required R2 evidence/artifacts, accepted Git commit/ref recovery roots, and required key/secret generations. A separate authoritative recovery-root lifecycle records whether that immutable manifest remains supported or has been retired. Cleanup protects both current active/accepted pins and every supported Recovery Root Manifest. Retiring a recovery root is itself authoritative; uncertain reachability leaks storage instead of deleting a potentially required object.

### Attempt identity and integration freshness

Results carry exact job-attempt identity. Late results from cancelled/superseded attempts cannot revive old work. Candidate implementation is independently verified/reviewed and receives an immutable candidate Acceptance Certificate. Factory then constructs the exact integration subject against the **current** target/base and independently verifies that result before issuing a separate immutable integration binding/certificate for merge eligibility.

The candidate Acceptance Certificate is never edited to add a later integration commit. A target/base change invalidates use of an existing integration binding unless the admitted integration protocol itself validates the exact resulting integration subject; PriFly constructs and verifies a new integration subject instead.

### Verification design and execution

A shell command, test-suite name, or producer statement is not by itself an adequate Verification definition. Verification design is evaluated against `verification-plan-quality/v1`: exact Requirement/Outcome, objective, method, environment/configuration, inputs/preconditions, expected observable result, objective criterion, coverage basis, independence, evidence retention, tool/runner identity where material, exception handling, and traceability.

Producer-supplied "tests passed" is not acceptance evidence. Factory launches independent verification against the exact candidate/integration subject and records actual/skipped checks, exact code/base identity, verification revision, exit/results, runner manifest, evidence provenance, and required evidence identities. AI Review judges whether those independently observed facts satisfy the predeclared Verification and Required Outcomes.

Validation of intended use is separate from verification of specification conformance and uses `validation-plan-quality/v1` when applicable.

Material changes to the Verification/Validation plan or project-specific pass threshold require the governing change/review path; a Reviewer may not weaken the criterion after seeing the result.

### Candidate acceptance quality

Candidate/product acceptance uses `acceptance-quality/v1` plus the applicable product-quality, V&V, security, accessibility, supply-chain, documentation, and other activated profiles. The standards-backed quality decision remains separate from PriFly's exact Acceptance Certificate/publication mechanism.

Where a product-quality standard defines a measure/dimension but leaves the acceptable value to project context, the accepted target/range must already be part of the governing Planning Baseline. Missing thresholds remain blocking `UNKNOWN` rather than becoming reviewer discretion.

### Multi-repository delivery

PriFly may validate a multi-repository Release Set, but v1 does not claim atomic distributed merge. Each repository integration must independently satisfy its admitted exact-target integration contract while planning tolerates partial sequential delivery through compatibility design, sequencing, flags, or migrations.

## Adversarial review principle

> **No consequential AI-produced artifact may promote itself.**

Independence includes fresh Worker identity/context, no producer private reasoning, immutable/revision-bound review subjects, machine-observed evidence where factual execution claims matter, and a Reviewer that does not mutate the artifact reviewed. Model/harness diversity is preferred at higher risk when historical evidence supports it, but demonstrated review quality remains more important than diversity for its own sake.
