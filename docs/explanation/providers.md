# Provider integration

Kind: explanation

GitHub and future providers are projections and external systems, not Factory workflow stores. Provider operations are admitted individually because retry, ambiguity, and concurrency semantics differ by operation.

PriFly does not claim generic exactly-once provider semantics. It supports only operation profiles whose ambiguity rules are explicitly defined.

### Provider operation profile

Every enabled operation type declares target/conflict scope, native preconditions, stable correlation strategy and limitations, whether retry can be proven safe, authoritative success/failure evidence, read-after-unknown reconciliation, permissible compensation/cancellation, field ownership, and observation ordering/version rules. An operation without an admitted profile is disabled.

### Crash-safe possible-send boundary

Consequential/external mutations use:

```text
PREPARED
  ↓ authoritative publication
SEND_ARMED
  ↓ authoritative publication
  ↓ only now may the first network byte be sent
SUCCEEDED | FAILED | UNKNOWN
```

`SEND_ARMED` means the operation **may have been sent** and must be treated as such after any crash. The Broker is forbidden from sending before the `SEND_ARMED` transition is AUTHORITATIVELY published through [persistence and durability](persistence-and-durability.md). If the process dies after `SEND_ARMED` but before a terminal result, recovery enters `UNKNOWN`. A recovered `PREPARED` operation is known unsent because provider code cannot send from that state.

### UNKNOWN and conflict lifetime

`UNKNOWN` never means failure or absence. The operation's conflict scope remains reserved while UNKNOWN. Factory releases the conflict only when the admitted profile establishes authoritative success, authoritative failure/non-execution, or explicit owner disposition for ambiguity that cannot be proven automatically. Negative lookup, access denial, missing search results, or expired provider operation handles do not automatically prove non-execution.

### Observation admission

Provider observations carry provider identity, observation/request identity, object/version identifier where available, and source operation/correlation where available. Factory applies operation-specific ordering rules so older delayed observations cannot blindly overwrite newer accepted observations. Provider-owned fields, Factory-projected fields, and external facts are declared separately. External merge/close is recorded as fact; reconciliation never invents retroactive PriFly approval.

### Initial v1 provider operation matrix

#### `git.publish_job_ref`

Purpose: durably checkpoint an exact Worker commit to a namespaced remote job ref.

- correlation: deterministic PriFly job ref;
- precondition: expected prior ref SHA or ref absence;
- retry: allowed only after remote inspection proves the desired exact SHA is already present or the expected old state still holds;
- conflict scope: that job ref;
- result: exact remote ref SHA.

#### `git.integrate_target_ref`

Purpose: integrate a verified exact commit into a managed target branch.

PriFly builds exact integration commit `M` against target/base `B`, independently verifies `M`, arms update of target ref `R` from exact expected old SHA `B` to exact new SHA `M`, and requires the remote update to fail if `R` is no longer exactly `B`. Target movement causes revalidation, not retrospective acceptance.

The deployment configures the managed target so the Factory integration identity can perform this exact compare-and-update while repository rules prevent uncontrolled writes inconsistent with project policy. Pull requests remain useful projections/review UI, but ordinary GitHub PR merge is not the v1 authoritative integration primitive.

#### Projection creates/updates

Issues, PR projections, comments, and statuses are not workflow authority. Where the provider offers no proven idempotency/exactly-once mechanism, PriFly uses stable correlation where practical, reconciles after `SEND_ARMED` ambiguity, does not blindly retry merely because the projection was not observed, and may leave unresolved ambiguity UNKNOWN or surface owner Attention.

### Provider matrix evolution

Adding a provider mutation profile is a versioned architecture/policy change if it changes retry, conflict, authority, or acceptance semantics. HTTP formatting, polling cadence, and backoff remain adapter details once the profile is fixed.
