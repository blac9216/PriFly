# Overnight limits

Standing rules for unattended runs in this repository:

- work only on planned, sequenced, `Ready` issues whose dependencies and `area:*` locks
  ([labels.md](labels.md)) permit dispatch — a Project `Ready` column entry is a
  projection of the owner's DP4 execution release, not a substitute for checking each
  issue's own named dependency/live-predicate state (see [work-tracking.md](work-tracking.md),
  [validation.md](validation.md));
- use local or explicitly disposable test resources unless `*.local.md` guidance
  authorizes a named external environment; no live provisioning or product-dispatch
  action without a concrete, current owner authorization;
- do not mutate production/provider systems, perform owner-confirmation actions, change
  repository/Project **configuration** (permissions, rulesets, Project field and option
  definitions, workflow settings), merge, or weaken a conformance oracle unattended.
  Exactly two exceptions apply, at any hour, each under the record that authorizes it:
  - **Bootstrap PR merge** (owner instruction,
    [#38](https://github.com/blac9216/PriFly/issues/38#issuecomment-5703543813): "I want
    you to be able to merge anything"). An approved bootstrap PR may be squash-merged
    only by the independent reviewer or merge-verifier for that PR, never by the
    orchestrator, implementer or fix agent, and only after independent review with no
    blocking `FAIL` or unresolved `UNKNOWN`, green required checks, and an up-to-date
    branch. Product and provider merges remain Factory Provider Broker authority and
    stay prohibited unattended.
  - **Board field values** (DP4 execution release,
    [#38](https://github.com/blac9216/PriFly/issues/38#issuecomment-5702259082), which
    assigns the orchestration's "claims, isolated worktrees, implementation/fix agents,
    PRs, review rounds, reviewer merges, board state and evidence" to `github-workflow`).
    Each role may update only the Project field values the `github-workflow` skill
    assigns it, exactly as its `references/orchestration.md` "Column ownership" table
    and `references/claims.md` state:
    - orchestrator (during triage): Triage → Backlog / Ready and Backlog → Ready, plus
      `Claimed by` per `references/claims.md`;
    - implementer or fix-round agent, at its start: → In progress, assigning the issue
      to the acting account in the same breath;
    - reviewer, at its start, every round: → In review;
    - reviewer on the ordinary merge path, or merge-verifier on the hand-back path:
      `Verified` at merge (`n/a` / `pending-live`);
    - validation agent: `Verified` → `live-verified` / `live-failed`;
    - no role: → Done, which is board automation on close.

    Field and option definitions remain configuration and stay prohibited;
- do not invent credentials, owner decisions, security exceptions, quality thresholds,
  architecture changes, or vendor behavior to keep a run moving; missing environmental
  access holds the dependent item rather than being worked around;
- apply the `help` label and record the blocker when owner authority, unavailable
  evidence, an ambiguous design decision, or an unsafe resource collision prevents
  progress;
- do not broaden an issue's scope to consume unattended time; file newly noticed work
  through the deferred-finding path instead (type + `deferred` + `concern:*` or
  `documentation` + `area:*`, per the current dispatch's filing convention);
- do not exceed a Work Item's or the milestone's cumulative execution envelope
  (attempts/hours) to finish overnight; exhaustion holds and replans, per the
  [DP4 operating contract](https://github.com/blac9216/PriFly/issues/38#issuecomment-5702104540).
