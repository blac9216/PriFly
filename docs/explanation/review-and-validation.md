# Review and validation

Kind: explanation

PriFly treats independent adversarial verification as a lifecycle property, not merely a pull-request convention. Consequential AI-produced artifacts cannot promote themselves.

### Acceptance subject

PriFly accepts an exact candidate, not an abstract Work Item. An immutable Acceptance Certificate binds at least the Planning Baseline, Work Item revision, implementation job attempt, exact candidate Git commit, target repository and base revision, verification-plan revision, Acceptance Evidence Manifest, Reviewer verdict, and governing policy version. Relevant changes do not rewrite that certificate; they make it no longer current under the acceptance lifecycle projection.

### Acceptance Evidence Manifest

Before acceptance can be released, Factory builds an immutable manifest that separates required evidence, optional diagnostics, and code recovery roots. Required evidence can include machine-observed verification summaries, required compatibility/migration/recovery objects, the exact verification execution manifest, and other artifacts explicitly required by policy. Every required external object carries immutable identity/hash, storage location, size/kind, and retention/root requirements fixed at acceptance time.

### Publish-before-acceptance ordering

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

### Recovery-root closure

Each supported recovery/rollback checkpoint has an immutable Recovery Root Manifest identifying the external dependencies needed to honor the authoritative state it contains, including required R2 evidence/artifacts, accepted Git commit/ref recovery roots, and required key/secret generations. A separate authoritative recovery-root lifecycle records whether that immutable manifest remains supported or has been retired. Cleanup protects both current active/accepted pins and every supported Recovery Root Manifest. Retiring a recovery root is itself authoritative; uncertain reachability leaks storage instead of deleting a potentially required object.

### Attempt identity and integration freshness

Results carry exact job-attempt identity. Late results from cancelled/superseded attempts cannot revive old work. Candidate implementation is independently verified/reviewed and receives an immutable candidate Acceptance Certificate. Factory then constructs the exact integration subject against the **current** target/base and independently verifies that result before issuing a separate immutable integration binding/certificate for merge eligibility.

The candidate Acceptance Certificate is never edited to add a later integration commit. A target/base change invalidates use of an existing integration binding unless the admitted integration protocol itself validates the exact resulting integration subject; PriFly constructs and verifies a new integration subject instead.

### Independent Verification Runner

Producer-supplied "tests passed" is not acceptance evidence. Factory launches independent verification against the exact candidate/integration subject and records actual/skipped checks, exact code/base identity, verification revision, exit results, runner manifest, and required evidence identities. AI Review judges whether those facts adequately prove the semantic Outcomes. Material changes to the verification plan require independent review.

### Multi-repository delivery

PriFly may validate a multi-repository Release Set, but v1 does not claim atomic distributed merge. Each repository integration must independently satisfy its admitted exact-target integration contract while planning tolerates partial sequential delivery through compatibility design, sequencing, flags, or migrations.

## Adversarial review principle

> **No consequential AI-produced artifact may promote itself.**

Independence includes fresh Worker identity/context, no producer private reasoning, immutable/revision-bound review subjects, machine-observed evidence where factual execution claims matter, and a Reviewer that does not mutate the artifact reviewed. Model/harness diversity is preferred at higher risk when historical evidence supports it, but demonstrated review quality remains more important than diversity for its own sake.
