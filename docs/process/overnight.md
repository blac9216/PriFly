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
- do not perform product/provider merges (Factory Provider Broker authority), owner-
  confirmation actions, repository/Project **configuration** changes (permissions,
  rulesets, field/option definitions, workflow settings), or weaken a conformance oracle
  unattended. Two things stay permitted at any hour under the owner's explicit session
  authority ([owner instruction](https://github.com/blac9216/PriFly/issues/38#issuecomment-5703543813):
  "I want you to be able to merge anything"): an independent reviewer's or merge-
  verifier's squash-merge of an approved bootstrap PR (never a self-merge — the
  independent-review and blocking-criteria rules in
  [work-tracking.md](work-tracking.md) and [validation.md](validation.md) stay intact),
  and a role's own board field **value** updates (Status, Verified, Claimed by,
  assignment) for work it owns — never a field's configuration;
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
