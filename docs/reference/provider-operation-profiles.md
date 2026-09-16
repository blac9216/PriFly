# Provider operation profiles

Kind: reference

## Admission contract

Every enabled mutation pins the provider/adapter/profile version, target and conflict scope, native preconditions, stable correlation and its limitations, safe-retry rules, terminal evidence, read-after-unknown reconciliation, cancellation/compensation behavior, field ownership and observation ordering. An operation without an admitted profile is disabled. Concrete provider versions and merge/projection/release settings remain explicit [admission parameters](deployment-parameters.md), not implicit defaults.

## Possible-send boundary

```text
PREPARED (durably recorded, known unsent)
→ SEND_ARMED (authoritatively published, may have been sent)
→ first network byte is permitted
→ SUCCEEDED | FAILED | UNKNOWN
```

The Broker cannot send before `SEND_ARMED` is published through [persistence and durability](../explanation/persistence-and-durability.md). Recovery treats unresolved armed work as possibly sent. `UNKNOWN` retains its conflict scope until the admitted profile establishes terminal evidence or authorized disposition. Missing lookup, access denial, delayed search and an expired handle do not themselves prove non-execution; blind retries are forbidden.

## Required operation families

These are semantic families, not invented API command names.

| Family | Preconditions and terminal evidence | Ambiguity and limits |
|---|---|---|
| Candidate branch/checkpoint publication | Exact repository/ref/commit, expected prior ref or absence where supported, and successful reconstruction of required Git dependencies. | Correlate the desired ref/commit; inspect before retry. This never authorizes a target-branch integration push. |
| Pull request creation/update | Published exact candidate branch, target and canonical PR Draft; mapping to the Work Item and native PR. | Reconcile possible duplicate creation and independently observed edits; do not treat missing search results as non-execution. |
| Review/comment/check publication | Canonical review-history entry and exact subject; admitted native identity/capability; provider receipt. | A comment is not native approval. Required approval must use an eligible independent identity; same-account limitations remain visible. |
| GitHub PR merge | Usable acceptance, exact expected head, admitted method/checks/protection, current authority and no blocking Finding; native merge receipt and actual merged SHA. | Expected head is not expected base. Qualify concurrent-base behavior; pause/revalidate when the profile cannot establish eligibility. Reconcile unknown outcomes before another conflicting mutation. |
| Optional planning/progress projection | Canonical record revision, enabled profile slot and field ownership; mapped provider object/version. | Lag/drift is visible. Optional projection failure does not invent a canonical workflow veto; required PR controls remain mandatory. |
| Release/artifact publication | Exact Release Manifest/version set and admitted provider-specific preconditions; per-destination receipts. | Partial publication is explicit. No distributed atomicity or universal retry semantics are assumed. |

Read-only observations also retain provider/object identity, observation/correlation IDs, versions where available, timestamp and provenance. Profile-specific ordering prevents stale observations overwriting newer accepted facts. Provider-owned fields remain distinct from Factory desired projections.

## Related contracts

[Providers](../explanation/providers.md) defines reconciliation and configurable projections. [Git integration](../explanation/git-integration.md) defines PR-only integration. [Conformance](conformance.md) supplies failure-injection oracles. Adding or changing ambiguity, authority, conflict or acceptance guarantees requires design/policy review; formatting and backoff within those guarantees are adapter details.
