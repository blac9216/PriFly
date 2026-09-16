# Design review, approval and change governance

Kind: reference

## Review subject

The owner reviews the product promise, scope, roles, records, lifecycle paths, quality policy,
authority, cost trade-offs and failure behavior. [Traceability](traceability.md) gives stable
requirement, criterion and figure identities and their canonical homes.

A documentation review is not an implementation qualification, standards certification or execution
release. The three exact-package owner releases and independent engineering gates in
[Planning policy](planning-policy.md) remain separate. Acceptance of the design authorizes delivery
planning only when that phase is explicitly released; the resulting delivery package needs its own
confirmation before execution.

## Independent review mission

Assess engineering quality, product fidelity and workflow correctness separately. Walk complete
nominal, adverse and recovery paths, including:

- Intake without unauthorized fan-out; each exact-package release; changed package after confirmation.
- New-project and feature design packages, annotations, source/rendered/diff identity and disposition.
- Fresh correction attempts in a retained workspace; exclusive writer handoff; independent review view.
- Credible reused evidence and same-review check collection without recursive reviewers.
- PR-only integration, changed head/base, unavailable native approval and unknown merge outcomes.
- Common Triage with held/batched/planned obligations; versioned target failure and re-pending.
- Initiative-to-milestone mapping and optional projections without a second workflow authority.
- Published-frontier recovery, possible-send obligations and upgrade rollback cutoff.
- Closeout that cannot hide deferred scope, pending validation or unresolved authority.

Look for contradictions, missing states/authority, unsupported dependency claims and tests that could
pass without delivering the intended behavior. Diagram shorthand never overrides the detailed contract.

Distinguish owner product choices, documentation defects, missing implementation contracts,
dependency qualification and configurable parameters. An implementation limitation changing a
promised guarantee requires a design decision; it cannot be hidden in an implementation detail.

## Review evidence and disposition

A review identifies the exact commit/package, applicable profile versions and scope/phase;
separate quality, conformance and workflow results; evidence and limitations; and a verdict.
Every substantive Finding cites the exact requirement/document, a failing scenario, severity and
reason, affected contracts and required disposition. Absence of runtime evidence in a design review
is not runtime PASS. A required source interpretation or design feasibility claim without adequate
evidence is `UNKNOWN` and remains a release constraint.

The assessment and audit gap report belong in the review thread/evidence record, not this canonical
doc set. Reading a document grants no mutation or release authority.

## Durable change control

Keep requirement and criterion IDs stable while meaning is stable. Material revisions preserve
rationale and impact relationships through the reviewed change. Rehome diagrams with explicit
cross-references; never silently promote illustrative names or measurements into defaults.

Accepted ADR Context, Decision Drivers, Considered Options and Decision are immutable.
A changed architectural choice uses a new Proposed amendment/superseding ADR and updates every
affected canonical contract in the same PR. The ADR index exposes both history and current proposals.
Do not fabricate an owner interrogation for a decision supplied directly in the owner's PRD.

Executable schemas, operational profiles and implementation evidence must later be reviewed against
these contracts before admission. [Conformance](conformance.md) and
[Product acceptance](product-acceptance.md) state required observations, not completed tests.
