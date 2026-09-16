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
  The owner's instruction
  ([#38](https://github.com/blac9216/PriFly/issues/38#issuecomment-5703543813): "I want
  you to be able to merge anything", as recorded there) permits exactly two exceptions,
  at any hour:
  - **Bootstrap PR merge.** An approved bootstrap PR may be squash-merged only by the
    independent reviewer or merge-verifier for that PR, never by the orchestrator,
    implementer or fix agent, and only after independent review with no blocking `FAIL`
    or unresolved `UNKNOWN`, green required checks, and an up-to-date branch. Product
    and provider merges remain Factory Provider Broker authority and stay prohibited
    unattended.
  - **Board field values.** Each role may update only the Project field values the
    `github-workflow` skill assigns it, in `references/orchestration.md` ("Column
    ownership") and `references/claims.md` (the `Claimed by` field): implementer or fix
    agent, In progress and assignment; reviewer, In review and Verified at merge;
    merge-verifier, Verified on its hand-back path; orchestrator, Triage/Backlog/Ready
    moves and Claimed by. Field and option definitions remain configuration and stay
    prohibited;
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
