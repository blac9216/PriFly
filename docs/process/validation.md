# Live validation

PriFly has no executable or deployed Factory stack yet (source baseline
`60472c9cb089e367f94c9257a6b0045c11b24093`). A merged bootstrap PR in this milestone can
prove documentation and repository configuration. It cannot by itself claim runtime
durability, provider, recovery, security, planning, or end-to-end product conformance.
The board's `Verified` field and this file exist to keep that distinction visible; see
[work-tracking.md](work-tracking.md) for the field and option IDs.

## What "live" means here

- **`n/a`**: the Work Item is a bounded merge-time deliverable (documentation, process,
  or repository configuration) with no separate runtime claim.
- **`pending-live`**: the candidate is merged, but a required live/runtime proof named
  by its Work Item or the governing D3 verification table has not yet run against a real
  system. Merged runner tests (unit/integration tests exercising local, deterministic
  fixtures) **never by themselves establish live qualification**. They validate the
  runner, not the target system.
- **`live-verified`**: the named live proof ran against the real target and passed.
- **`live-failed`**: the named live proof ran and failed; a bug is filed and linked.

Absence of live evidence is `UNKNOWN`, never a silent `PASS`. An unresolved `UNKNOWN`
blocks the same as a `FAIL` ([ADR-0021](../adr/0021-use-standards-backed-quality-rubrics.md)
item 5: "Unresolved `UNKNOWN` blocks"). Missing evidence is reported as missing, not
inferred from a green merge-time suite.

## Named gates observed in the DP4 delivery index

Two exact-item live gates are named in the current DP4 delivery package (governing
comments on [issue #38](https://github.com/blac9216/PriFly/issues/38)):

- **Q12** ([#120](https://github.com/blac9216/PriFly/issues/120)) gates broad
  implementation on **R01** ([#74](https://github.com/blac9216/PriFly/issues/74)). R01's
  dependency edge reads "PR integrated AND independent real E1/E4 PASS for both exact
  harness tuples; otherwise broad runtime implementation remains held."
- **Q13** ([#121](https://github.com/blac9216/PriFly/issues/121)) gates broad
  implementation on **D01** ([#65](https://github.com/blac9216/PriFly/issues/65)). D01's
  dependency edge reads "PR integrated AND independent early real remote-publication
  PASS at fixed D3 thresholds; otherwise broad durability implementation remains held."

Merging or closing #120 or #121 alone does **not** satisfy either gate. Each also needs a
real, measured, independently observed PASS record. Without one, R01 and D01 stay held,
and the gate evidence stays `pending-live`/`UNKNOWN`. The
[DP4 operating contract](https://github.com/blac9216/PriFly/issues/38#issuecomment-5702104540)
states the same rule: "issue closure alone never proves a live profile or Validation
Target."

## Live-run inputs and blockers

A live check or live provisioning step needs three named inputs for its exact target.
Machine-local `*.local.md` guidance supplies each one as a `<Input>: <reference>` line.
The reference is a pointer, never a secret value; credentials themselves never appear in
issues, logs, scratch, or committed files.

| Input | What it names |
|---|---|
| `Live account` | The named capability reference the check acts through. |
| `Live environment` | The reserved, isolated environment or test subject the check may touch. |
| `Live authorization` | The concrete, current owner authorization for this subject and capability (a link to the release or authorization record). |

If any input is not named, that is an explicit blocker. The dependent live item reports
`BLOCKED: <input> missing`, holds, and keeps its result `UNKNOWN`. The input is never
guessed, substituted, or worked around, and the run is never reported as `PASS`. Naming
all three removes only this blocker. It does not itself authorize, run, or pass anything.

This is the bootstrap reading of the DP4 operating contract: "Operator provides named
capability references and reserved environment; no secrets in issues, logs or scratch";
"Live provisioning or test mutation requires concrete subject/capability authorization;
a future execution release may supply it, otherwise Q01 reports the missing authority and
dependent run waits"; "Unsupported prerequisites are blocked/UNKNOWN, never PASS". Q01
([#109](https://github.com/blac9216/PriFly/issues/109)) owns the executable preflight
that will replace this manual reading.

## Evidence locations

Evidence lives in the acting agent's own scratch directory, outside the repository tree
(`<scratch>/evidence/issue<N>/`, per [worktrees.md](worktrees.md)), and is never
committed. Environment inventory and current authorization for a specific host or target
belong in `*.local.md` guidance, not here.

## No-workaround bar

An accepted live result cannot rest on any of these:

- **A stale, partial, or undocumented-workaround result.** Released DP4 Work Items (for
  example [#56](https://github.com/blac9216/PriFly/issues/56)) state: "Independent
  Validator must reject stale/partial/undocumented-workaround results". D3 V13 requires
  operator recipes to run "with no undocumented workaround"
  ([D3 verification](https://github.com/blac9216/PriFly/issues/38#issuecomment-5701521439)).
- **A protection bypass or a weakened threshold.** The DP4 operating contract excludes
  "direct target push, protection bypass, or paid API path", and says "no redesign or
  threshold weakening is implicit".
- **A deterministic fixture standing in for the real target.** Code "can be implemented
  against isolated deterministic adapters beforehand; those cannot admit product
  operation" (DP4 operating contract).
- **Test success without the expected behavior.** D3 C6: "Test success without the
  expected behavior is a Finding"
  ([D3 contracts](https://github.com/blac9216/PriFly/issues/38#issuecomment-5701520946)).

A Reviewer or Validator that cannot reproduce the claimed evidence records `UNKNOWN`
rather than giving the benefit of the doubt.

## Live-validation threshold

No numeric bootstrap pending-live threshold is set. Live validation of runtime claims is
owned by the planned qualification items, for example Q01
([#109](https://github.com/blac9216/PriFly/issues/109)), Q11
([#119](https://github.com/blac9216/PriFly/issues/119)), Q12, Q13, and the handover
trials Q09 ([#117](https://github.com/blac9216/PriFly/issues/117)) and Q10
([#118](https://github.com/blac9216/PriFly/issues/118)). The independent Validator named
in each Work Item's "Home and responsibility" section owns the result. D3 C8's Validation
Target scheduling governs the future Factory product and is not this workflow's
threshold. Choosing a bootstrap threshold is an owner/planning decision.

## Evaluation discipline

A round's evaluation keeps three questions separate, and a round cap never waives a
blocking result ([AGENTS.md](../../AGENTS.md);
[ADR-0021](../adr/0021-use-standards-backed-quality-rubrics.md)):

- **Engineering quality**: the pinned, versioned profiles in
  [quality-rubrics.md](../reference/quality-rubrics.md), sourced from
  [standards-registry.md](../reference/standards-registry.md). The DP4 operating contract
  pins these for implementation and review: "implementation-quality/v1,
  review-inspection-quality/v1, evidence-provenance-quality/v1 and applicable
  security/documentation profiles". For a bootstrap docs/process change, the applicable
  ones are `documentation-quality/v1`, `evidence-provenance-quality/v1` for its evidence,
  `review-inspection-quality/v1` for its review, and `security-engineering-quality/v1`
  where it applies. `plan-quality/v1` and the other delivery
  profiles in the contract's list apply to delivery evaluation, not to this workflow's
  implementation or review rounds.
- **Project conformance**: does the change obey the governing D3 contracts, the DP4
  operating contract, the ADRs, and its Work Item's own Constraints
  ([design-governance.md](../reference/design-governance.md)).
- **PriFly workflow authority**: is the candidate allowed to advance, given the
  independence, evidence, and Finding rules in this directory and
  [ADR-0009](../adr/0009-require-independent-adversarial-review.md)/[ADR-0024](../adr/0024-reuse-evidence-within-independent-review.md) (Proposed).

Each applicable criterion resolves `PASS`/`FAIL`/`NOT_APPLICABLE`/`UNKNOWN` with its
exact subject and evidence. Per-item and milestone attempt/hour envelopes are set by the
[DP4 operating contract](https://github.com/blac9216/PriFly/issues/38#issuecomment-5702104540)
and each Work Item's Estimate section. Exhausting a round cap or an envelope never turns a
blocking `FAIL`/`UNKNOWN` into a pass. It forces a stop, a replan, or an escalation.
