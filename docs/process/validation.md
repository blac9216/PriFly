# Live validation

PriFly has no executable or deployed Factory stack yet (source baseline
`60472c9cb089e367f94c9257a6b0045c11b24093`). A merged bootstrap PR in this milestone can
prove documentation and repository configuration; it cannot by itself claim runtime
durability, provider, recovery, security, planning, or end-to-end product conformance.
That distinction is what the board's `Verified` field and this file exist to keep
visible — see [work-tracking.md](work-tracking.md) for the field/option IDs.

## What "live" means here

- **`n/a`** — the Work Item is bounded merge-time deliverable (documentation, process,
  or repository configuration) with no separate runtime claim; this issue (#56) records
  `Verified expectation: n/a` for exactly that reason.
- **`pending-live`** — the candidate is merged, but a required live/runtime proof named
  by its Work Item or the governing D3 verification table has not yet run against a real
  system. Merged runner tests (unit/integration tests exercising local, deterministic
  fixtures) **never by themselves establish live qualification** — they validate the
  runner, not the target system.
- **`live-verified`** — the named live proof ran against the real target and passed.
- **`live-failed`** — the named live proof ran and failed; a bug is filed and linked.

Absence of live evidence is `UNKNOWN`, never a silent `PASS` — an unresolved `UNKNOWN`
blocks the same as a `FAIL` ([ADR-0021](../adr/0021-use-standards-backed-quality-rubrics.md)
item 5). Missing evidence is reported as missing, not inferred from a green merge-time
suite.

## Named gates observed in the DP4 delivery index

Two exact-item live gates are named in the current DP4 delivery package (governing
comments on [issue #38](https://github.com/blac9216/PriFly/issues/38)); they hold
independently of this issue's own scope:

- **Q12** ([#120](https://github.com/blac9216/PriFly/issues/120)) real PASS gates
  broad implementation on **R01** ([#74](https://github.com/blac9216/PriFly/issues/74)).
- **Q13** ([#121](https://github.com/blac9216/PriFly/issues/121)) real PASS gates
  broad implementation on **D01** ([#65](https://github.com/blac9216/PriFly/issues/65)).

Neither gate is affected by this issue; they are recorded here because this file is
where a Worker looks up what "live" requires before treating any merge as runtime proof.

## Evidence locations

Evidence lives in the acting agent's own scratch directory, outside the repository tree
(`<scratch>/evidence/issue<N>/`, per `worktrees.md`) — never committed. Credentials
needed for a live check are supplied only through the `with-secrets` mechanism, never
written into an issue, PR, log, or scratch file; environment inventory and current
authorization for a specific host/target belong in `*.local.md` guidance, not here.

## No-workaround bar

An accepted result cannot rest on a documented workaround, a weakened repository
protection, a skipped required check, or a substituted deterministic fixture standing in
for a claimed real target ([D3 contract C6](https://github.com/blac9216/PriFly/issues/38#issuecomment-5701520946);
[ADR-0009](../adr/0009-require-independent-adversarial-review.md)). A Reviewer or
Validator that cannot reproduce the claimed evidence records `UNKNOWN`, not a benefit of
the doubt.

Batch threshold: the current D3 contract (C8, governing comment on
[issue #38](https://github.com/blac9216/PriFly/issues/38)) schedules a Validation Target
run at one pending integration or five minutes' oldest-pending, and groups at most two
compatible integrated changes for this handover, in one validation environment. This
file does not invent a different number; it only points at the governing one so a
Worker does not have to guess before a runnable stack exists.

## Evaluation discipline

A round's evaluation keeps three questions separate and never lets a round cap waive a
blocking one ([AGENTS.md](../../AGENTS.md); [ADR-0021](../adr/0021-use-standards-backed-quality-rubrics.md)):

- **Engineering quality** — the pinned, versioned profiles in
  [quality-rubrics.md](../reference/quality-rubrics.md), sourced from
  [standards-registry.md](../reference/standards-registry.md). A bootstrap docs/process
  change is evaluated against `documentation-quality/v1`, `plan-quality/v1` (where a
  workflow/process rule is itself a plan-shaped artifact), and `evidence-provenance-quality/v1`
  for its own evidence; implementation work additionally uses
  `implementation-quality/v1`.
- **Project conformance** — does the change obey the governing D3 contracts, DP4
  operating contract, ADRs, and this issue's own Constraints
  ([design-governance.md](../reference/design-governance.md)).
- **PriFly workflow authority** — is the candidate allowed to advance given the
  independence, evidence, and Finding rules in this directory and
  [ADR-0009](../adr/0009-require-independent-adversarial-review.md)/[ADR-0024](../adr/0024-reuse-evidence-within-independent-review.md) (Proposed).

Each applicable criterion resolves `PASS`/`FAIL`/`NOT_APPLICABLE`/`UNKNOWN` with its
exact subject and evidence; a round cap (see the per-item attempt/hour budgets in
[overnight.md](overnight.md) and [maintenance.md](maintenance.md), and the DP4
per-item/milestone envelope in the
[operating contract](https://github.com/blac9216/PriFly/issues/38#issuecomment-5702104540))
never converts a blocking `FAIL`/`UNKNOWN` into a pass — it only forces a stop, replan,
or escalation.
