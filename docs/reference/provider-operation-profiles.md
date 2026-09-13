# Provider operation profiles

Kind: reference

PriFly supports only provider operations whose ambiguity rules are explicitly defined.

## Operation profile fields

Every enabled operation declares target/conflict scope, native preconditions, stable correlation and limitations, safe-retry rules, terminal evidence, read-after-unknown reconciliation, compensation/cancellation semantics, field ownership, and observation ordering/version rules. An operation without an admitted profile is disabled.

## Crash-safe possible-send boundary

```text
PREPARED
  ↓ authoritative publication
SEND_ARMED
  ↓ authoritative publication
  ↓ only now may the first network byte be sent
SUCCEEDED | FAILED | UNKNOWN
```

`SEND_ARMED` means the operation **may have been sent**. The Broker cannot send before that transition is authoritatively published through [persistence and durability](../explanation/persistence-and-durability.md). A recovered PREPARED operation is known unsent; unresolved SEND_ARMED becomes UNKNOWN.

## UNKNOWN and conflict lifetime

UNKNOWN never means failure or absence. Conflict scope remains reserved until the operation profile establishes authoritative success, authoritative failure/non-execution, or explicit owner disposition of otherwise unprovable ambiguity. Negative lookup, access denial, missing search results, or expired operation handles do not automatically prove non-execution.

## Observation admission

Provider observations carry provider identity, request/observation identity, object/version identifier where available, and source operation/correlation where available. Operation-specific ordering prevents older delayed observations from blindly overwriting newer accepted observations. Provider-owned fields, Factory projections, and external facts remain distinct.

## Initial v1 profiles

### `git.publish_job_ref`

- purpose: checkpoint an exact Worker commit to a namespaced remote job ref;
- correlation: deterministic PriFly job ref;
- precondition: expected prior ref SHA or ref absence;
- retry: only after remote inspection proves desired SHA already exists or the expected old state still holds;
- conflict scope: job ref;
- terminal result: exact remote ref SHA.

### `git.integrate_target_ref`

Factory builds exact integration commit `M` against target/base `B`, independently verifies `M`, then arms a target-ref update from exact expected old SHA `B` to exact new SHA `M`. The remote update must fail if the target is no longer exactly `B`. Target movement causes revalidation. Pull requests remain projections/UI; ordinary provider PR merge is not the v1 authoritative integration primitive.

### Projection creates/updates

Issues, PR projections, comments, and statuses are not workflow authority. Without proven idempotency, PriFly uses stable correlation where practical, reconciles SEND_ARMED ambiguity, never blindly retries solely because the projection was not observed, and may leave ambiguity UNKNOWN or surface owner Attention.

## Evolution

Adding a provider mutation profile is an architecture/policy change when it changes retry, conflict, authority, or acceptance semantics. HTTP formatting, polling cadence, and backoff remain adapter implementation details after the profile is fixed.
