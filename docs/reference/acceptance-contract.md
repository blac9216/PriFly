# Acceptance contract

Kind: reference

## Acceptance subject

PriFly accepts an exact candidate, not an abstract Work Item. An immutable Acceptance Certificate binds at least the Planning Baseline, Work Item revision, implementation job attempt, exact candidate Git commit, target repository, exact target/base revision, verification-plan revision, Acceptance Evidence Manifest, Reviewer verdict, and governing policy version. Relevant changes invalidate the certificate.

## Acceptance Evidence Manifest

Before acceptance can be released, Factory builds an immutable manifest separating required evidence, optional diagnostics, and code recovery roots. Every required external object carries immutable content identity/hash, storage location, size/kind, and retention/root membership. Optional logs/raw context may expire unless policy made them required.

## Publish-before-acceptance ordering

```text
produce evidence
→ upload to R2 / required durable store
→ verify object identity/presence
→ construct Acceptance Evidence Manifest
→ record manifest + retention pins in authoritative SQLite transaction
→ remote database durability + coordination publication
→ release Acceptance Certificate
```

Factory may not authoritatively accept a result while required evidence is pending or unverified.

## Recovery-root closure

Each supported recovery/rollback checkpoint has an immutable Recovery Root Manifest identifying the external dependencies needed to honor the authoritative state contained in that checkpoint, including required R2 evidence/artifacts, accepted Git commit/ref recovery roots, and required key/secret generations. Cleanup protects both current pins and every supported Recovery Root Manifest. Retiring a root is authoritative; uncertain reachability leaks storage rather than deleting a potentially required object.

## Attempt identity and integration freshness

Results carry exact job-attempt identity. Late results from cancelled/superseded attempts cannot revive old work. Candidate implementation is verified/reviewed, then an exact integration subject is constructed against the current target and independently verified before merge eligibility. A target/base change invalidates integration eligibility unless the admitted protocol validates the exact resulting integration subject.

## Independent Verification Runner

Producer-supplied “tests passed” is not acceptance evidence. Factory launches independent verification against the exact candidate/integration subject and records actual/skipped checks, exact candidate/base/integration identity, verification revision, exit results, runner/execution manifest, and required evidence identities. AI Review judges whether those facts prove the semantic Outcomes. Material changes to the verification plan require independent review.

## Multi-repository delivery

PriFly may validate a multi-repository Release Set. v1 does not claim atomic distributed merge; each repository integration independently satisfies its exact-target contract while planning tolerates partial sequential delivery through compatibility design, sequencing, flags, or migrations.
