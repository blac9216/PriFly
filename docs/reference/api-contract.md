# Local application API contract

Kind: reference

This document defines PriFly's **semantic local API contract**. It intentionally does not freeze HTTP resource paths, Go handler layout, database tables, or a specific local IPC implementation. The initial transport may use HTTP/JSON semantics over an OS-protected Unix socket or platform-equivalent local transport, but every supported transport must preserve the authority, idempotency, consistency, and versioning rules below.

The contract is consumed by Pilot, future Bridge, CLI/admin tooling, Worker runtime adapters, and Factory subsystems. These clients may present different UX, but they do not get different workflow semantics.

## Contract principles

1. **Commands express intent.** They are the only authoritative mutation path.
2. **Queries observe state.** They never mutate canonical state.
3. **Events report facts.** Event delivery is notification/audit, not authority.
4. **Actor identity is authenticated, not self-asserted.** The transport/runtime adapter stamps the canonical actor from the authenticated capability.
5. **Authoritative success means released.** A mutation is not successful merely because SQLite committed locally or remote bytes exist.
6. **Retries preserve command identity.** A client that does not know whether a command completed retries the same `command_id`; it does not manufacture a new operation.
7. **Schema identity is explicit.** Envelopes and logical operations are independently versioned.
8. **Transport is replaceable.** Endpoint paths, socket names, HTTP status mappings, and serialization framing may evolve without changing the semantic contract.

## Common scalar and reference conventions

These conventions apply across Commands, Queries, Events, and canonical schema families.

| Concept | Contract |
|---|---|
| ID | Opaque, stable string. Callers must not infer time, type, ordering, or storage layout from its encoding. |
| Revision | Positive monotonic integer scoped to one mutable canonical object. Revision equality is meaningful; revision values across objects are not ordered. |
| Time | RFC 3339 UTC timestamp when a timestamp is semantically useful. Timestamps do not establish workflow ordering. |
| Schema | String identity in `<family>/vN` form, for example `command/v1` or `work-item/v1`. |
| Logical operation/event type | String identity in `<domain>.<verb>/vN` or `<domain>.<fact>/vN` form, for example `work.pause/v1` or `work.paused/v1`. |
| Object reference | Kind + opaque ID; exact revision is included when correctness depends on a specific revision. |
| Content identity | Cryptographic content hash plus algorithm when bytes must be immutable/reconstructible. |
| Correlation | Opaque ID grouping related work across Commands/Events/jobs. It is diagnostic/tracing context, not authority. |
| Causation | The immediate Command/Event/job identity that caused a semantic fact, when applicable. |

## Actor and capability model

The canonical `actor` is established by the authenticated connection/capability. A client cannot gain authority by placing a different actor in its JSON payload.

Minimum actor kinds are:

| Actor kind | Meaning | Typical authority |
|---|---|---|
| `owner_control` | Human owner using the protected owner-control surface. | Consequential confirmation plus normal owner commands. |
| `pilot` | Conversational owner client. | Query/explain, draft actions, routine delegated commands; never human-only confirmation. |
| `bridge` | Future graphical owner client. | Same semantic authority model as Pilot unless using a separately authenticated owner-control action. |
| `worker_attempt` | One exact Worker Job Attempt. | Only capabilities granted to that attempt. |
| `factory` | Deterministic internal Factory subsystem. | Internal lifecycle/state commands allowed by policy. |
| `provider_observer` | Provider Broker/reconciler observation principal. | Submit external facts/observations; cannot retroactively create PriFly approval. |
| `recovery_operator` | Restricted pre-ACTIVE recovery/admin surface. | Recovery-only operations; no normal project delivery authority. |

An actor may carry an applicable `delegation_id`, `worker_attempt_id`, or subsystem identity. Those references explain the authority path; they do not replace policy validation.

## Command envelope

Every authoritative mutation becomes a canonical Command with this minimum semantic shape:

| Field | Required | Meaning |
|---|---:|---|
| `schema` | yes | `command/v1`. |
| `command_id` | yes | Globally unique idempotency identity for this intent. |
| `type` | yes | Versioned logical operation, e.g. `work.pause/v1`. |
| `actor` | yes | Factory-stamped authenticated actor reference. |
| `issued_at` | yes | Time the Factory admitted the command envelope; not an ordering primitive. |
| `correlation_id` | yes | Groups the command with its wider workflow/owner interaction. |
| `causation_id` | no | Immediate cause when the command is derived from another canonical fact. |
| `target` | operation-specific | Exact object reference when the command acts on one canonical object. |
| `expected_revision` | operation-specific | Required whenever stale-object protection matters. |
| `payload` | yes | Command-specific JSON object governed by the command `type`. |

Representative shape:

```json
{
  "schema": "command/v1",
  "command_id": "opaque-command-id",
  "type": "work.pause/v1",
  "actor": {
    "kind": "pilot",
    "principal_id": "opaque-principal-id",
    "delegation_id": "opaque-delegation-id"
  },
  "issued_at": "2026-09-13T18:00:00Z",
  "correlation_id": "opaque-correlation-id",
  "target": {
    "kind": "work-item",
    "id": "opaque-work-item-id"
  },
  "expected_revision": 7,
  "payload": {
    "reason": "owner-requested pause"
  }
}
```

The API transport may omit client-supplied `actor` and `issued_at`; Factory stamps them into the canonical Command. If a transport accepts those fields for diagnostics, they cannot override authenticated identity or server time.

## Command admission and idempotency

Factory evaluates a Command in this order conceptually:

1. authenticate the caller/capability;
2. validate envelope schema and command-specific payload schema;
3. resolve an existing `command_id`, if any;
4. validate actor authority/delegation;
5. validate target existence/revision/current lifecycle state;
6. validate Factory generation/policy/domain invariants;
7. execute the local authoritative transaction;
8. satisfy remote durability and Published Frontier publication;
9. return authoritative result.

### Duplicate command IDs

- Same `command_id`, same authenticated actor, same logical type, and semantically identical request returns the original authoritative result.
- Reuse of a `command_id` with a different actor, type, target, expected revision, or payload is rejected as `IDEMPOTENCY_CONFLICT`.
- A transport timeout after submission is resolved by retrying the **same** `command_id`.
- Clients must not generate a new command merely because the prior response was lost.

Canonical request equality may be implemented using a deterministic request digest; the digest algorithm/storage is an implementation detail so long as the semantic rule above is preserved.

## Command result envelope

An authoritative command response has this minimum shape:

| Field | Required | Meaning |
|---|---:|---|
| `schema` | yes | `command-result/v1`. |
| `command_id` | yes | Command whose disposition this is. |
| `type` | yes | Mirrors the command logical type. |
| `status` | yes | `RELEASED` or `REJECTED`. |
| `result` | on release when operation returns data | Operation-specific result object. |
| `resulting_objects` | no | Exact object refs/revisions changed or created. |
| `event_refs` | no | Ledger Event refs emitted by the transaction. |
| `published_frontier` | on release | Factory Generation + application sequence proving the release point; the transport need not expose storage-private restore internals. |
| `error` | on rejection | Structured error object. |

`LOCAL_PENDING`, `REMOTE_DURABLE`, and `FRONTIER_PUBLISHED` are internal lifecycle states, not authoritative success responses. A diagnostic/admin surface may expose provisional progress, but it must use an explicitly provisional schema and cannot be consumed as a successful Command result.

## Structured error contract

Errors are semantic, transport-neutral objects:

```json
{
  "code": "STALE_REVISION",
  "message": "work item revision no longer matches the command precondition",
  "retry": "AFTER_STATE_CHANGE",
  "details": {
    "expected_revision": 7,
    "current_revision": 8
  }
}
```

`message` is for humans and must not be parsed by clients. Clients branch on `code` and, where useful, typed `details`.

### Retry classes

| Retry value | Meaning |
|---|---|
| `NEVER` | Repeating the same request without changing intent/state cannot succeed. |
| `SAME_COMMAND` | Retry the same `command_id`; creating a new command would be unsafe or incorrect. |
| `AFTER_STATE_CHANGE` | The caller must refresh/reconcile state, then decide whether to issue a new command. |
| `AFTER_CAPACITY` | Retry only after capacity/resource pressure changes; same logical intent may keep the same command only when the operation contract permits. |

### Core error codes

| Code | Typical retry | Meaning |
|---|---|---|
| `SCHEMA_INVALID` | `NEVER` | Envelope/payload does not match the declared schema. |
| `SEMANTIC_INVALID` | `NEVER` | Structurally valid request violates a domain invariant. |
| `UNAUTHENTICATED` | `AFTER_STATE_CHANGE` | No acceptable caller identity/capability. |
| `UNAUTHORIZED` | `AFTER_STATE_CHANGE` | Authenticated actor lacks required authority/delegation. |
| `OWNER_CONFIRMATION_REQUIRED` | `AFTER_STATE_CHANGE` | Consequential action needs the owner-only confirmation path. |
| `NOT_FOUND` | `AFTER_STATE_CHANGE` | Required canonical target does not exist in authoritative state. |
| `STALE_REVISION` | `AFTER_STATE_CHANGE` | Target revision does not match the command precondition. |
| `INVALID_STATE` | `AFTER_STATE_CHANGE` | Operation is not allowed from the target's current lifecycle state. |
| `POLICY_BLOCKED` | `AFTER_STATE_CHANGE` | Current planning/security/routing/etc. policy forbids the transition. |
| `UNKNOWN_BLOCKING` | `AFTER_STATE_CHANGE` | Required applicability/impact/provider fact is unresolved and conservatively blocks progress. |
| `IDEMPOTENCY_CONFLICT` | `NEVER` | Command ID was reused for different intent. |
| `CONFLICT` | `AFTER_STATE_CHANGE` | Another active obligation/operation owns an incompatible conflict scope. |
| `CAPACITY_UNAVAILABLE` | `AFTER_CAPACITY` | No eligible Route/capacity can currently admit the work. |
| `EXECUTION_ENVELOPE_EXHAUSTED` | `AFTER_STATE_CHANGE` | Work Item cumulative autonomy envelope is exhausted and requires policy/owner disposition. |
| `DURABILITY_UNAVAILABLE` | `SAME_COMMAND` | Factory cannot safely publish authoritative success through the required durability frontier. |
| `FACTORY_NOT_ACTIVE` | `AFTER_STATE_CHANGE` | Normal project mutation is unavailable during recovery/quiesce/initialization. |
| `PROVIDER_AMBIGUOUS` | `AFTER_STATE_CHANGE` | External operation remains UNKNOWN; blind retry/new conflicting intent is forbidden. |
| `UNSUPPORTED` | `NEVER` | Requested schema/operation/profile is not admitted by this Factory version/configuration. |

Individual operations may define additional typed error codes, but they must preserve these retry semantics.

## Query envelope

Queries are non-mutating and have this minimum semantic shape:

| Field | Required | Meaning |
|---|---:|---|
| `schema` | yes | `query/v1`. |
| `query_id` | yes | Correlation identity for the read; not an idempotency key. |
| `type` | yes | Versioned logical query type. |
| `actor` | yes | Factory-stamped authenticated actor. |
| `issued_at` | yes | Admission timestamp. |
| `consistency` | yes | `AUTHORITATIVE` for canonical clients; provisional admin queries use a distinct explicitly diagnostic contract. |
| `parameters` | yes | Query-specific filters/refs. |

### Query result

Every authoritative Query result includes:

- `schema: query-result/v1`;
- `query_id` and query `type`;
- `snapshot_frontier` containing at least Factory Generation + published application sequence;
- operation-specific `data`;
- optional opaque collection cursor metadata when that query defines pagination.

A collection cursor, if used, is opaque and bound to the query type/filter/snapshot semantics that created it. Clients must not construct or interpret cursors. The exact cursor encoding and transport pagination parameters remain implementation details.

## Read consistency

Owner-facing and workflow-relevant Queries read the latest **released Published Frontier**, not arbitrary LOCAL_PENDING rows.

Factory may implement that contract by blocking behind publication, maintaining a released read view, or another mechanism. A diagnostic view of provisional state must be visibly separate and must never satisfy a gate, authority check, or client assumption of authoritative success.

## Event envelope

A Ledger Event records a semantic fact committed in the same authoritative transaction as current state.

Minimum shape:

| Field | Required | Meaning |
|---|---:|---|
| `schema` | yes | `event/v1`. |
| `event_id` | yes | Stable opaque event identity. |
| `type` | yes | Versioned semantic fact type, e.g. `work.paused/v1`. |
| `position` | yes | Published Ledger position: application sequence plus event index within that transaction. |
| `occurred_at` | yes | Fact timestamp; position, not time, establishes order. |
| `actor` | yes | Actor responsible for the authoritative transition. |
| `subject` | yes | Primary object ref/revision the fact concerns. |
| `correlation_id` | yes | Wider workflow correlation. |
| `causation_id` | no | Immediate Command/Event/job cause. |
| `payload` | yes | Event-specific immutable data. |

Historical Ledger Events are immutable. A newer event schema does not rewrite an old Event merely to modernize its shape.

## Event stream semantics

- Delivery is **at least once**; clients must tolerate duplicate Event delivery by `event_id`/position.
- Released Events are ordered by Ledger position.
- A stream cursor is an opaque representation of the last processed Ledger position.
- Reconnect may resume after a cursor when the endpoint supports replay; clients still query canonical state after reconnect because Events are notification, not authority.
- No consumer may mutate canonical state by editing/replaying an Event object; resulting actions must enter through Commands.

## Initial logical command catalog

The following catalog defines v1 semantic operation families. It is not a promise that every operation is implemented in the first executable milestone; unsupported operations return `UNSUPPORTED` rather than inventing ad hoc semantics.

### Owner/Pilot/Bridge workflow commands

| Logical type | Authority | Semantic effect |
|---|---|---|
| `planning.start/v1` | owner or delegated Pilot/Bridge | Create/open a Planning Record for an owner goal/change. |
| `research.request/v1` | owner or delegated Pilot/Bridge | Ask Factory to schedule bounded research; client does not perform research itself. |
| `lane.pause/v1` | owner or allowed delegation | Prevent new work admission in a Lane while preserving state. |
| `lane.resume/v1` | owner or allowed delegation | Re-enable a paused Lane if blockers/policy allow. |
| `work.pause/v1` | owner or allowed delegation | Stop new progress on one Work Item and drain/cancel according to runtime policy. |
| `work.resume/v1` | owner or allowed delegation | Return a paused Work Item to scheduling when eligible. |
| `work.cancel/v1` | owner or policy-authorized action | Terminate future execution; already SEND_ARMED external obligations remain subject to reconciliation. |
| `change-request.open/v1` | owner, Factory, or authorized planning role | Create a typed post-baseline semantic change request. |
| `decision.select/v1` | authority determined by Decision class/policy | Select one Decision option; Strategic/Constitutional paths may require Owner Action confirmation. |
| `risk.accept/v1` | owner-control when policy says consequential | Record explicit accepted residual risk. |
| `attention.act/v1` | authority encoded by Attention Item action | Execute one currently permitted action on an Attention Item. |
| `owner-action.confirm/v1` | **owner_control only** | Confirm the exact immutable Owner Action package/digest. Pilot/Worker credentials cannot call it. |

### Worker-attempt commands

| Logical type | Authority | Semantic effect |
|---|---|---|
| `worker-result.submit/v1` | exact active Worker Job Attempt | Submit typed output for that attempt; submission is not self-acceptance. |
| `finding.submit/v1` | exact active Worker Job Attempt | Submit a structured Finding for Factory triage. |
| `scope-expansion.request/v1` | exact active Worker Job Attempt | Request a larger Implementation Envelope; Worker cannot grant itself scope. |
| `worker-blocker.report/v1` | exact active Worker Job Attempt | Report a semantic blocker requiring Factory disposition. |

Progress/heartbeat/stdout telemetry is EPHEMERAL operational telemetry, not automatically a Command or Ledger Event.

### Factory-internal commands

| Logical type | Typical issuer | Semantic effect |
|---|---|---|
| `baseline.publish/v1` | planning subsystem | Publish a Design/Delivery baseline only after its gate passes. |
| `job.dispatch/v1` | scheduler | Create/admit an exact Worker Job Attempt under a Route and execution envelope. |
| `job.cancel/v1` | scheduler/runtime controller | Begin bounded cancellation/drain of an attempt. |
| `job.complete/v1` | scheduler/result processor | Record terminal attempt result after validation. |
| `review.record/v1` | review processor | Record independent Review Result and Findings. |
| `verification.record/v1` | Verification Runner/processor | Record machine-observed verification evidence. |
| `acceptance.release/v1` | acceptance subsystem | Release an exact Acceptance Certificate after all required evidence and review predicates hold. |
| `provider.prepare/v1` | Provider Broker | Create a durable provider obligation in PREPARED. |
| `provider.arm/v1` | Provider Broker | Publish SEND_ARMED before any provider mutation byte may be sent. |
| `provider.observe/v1` | provider observer/reconciler | Record provider facts under the admitted operation profile's observation rules. |
| `recovery-root.retire/v1` | retention/recovery subsystem with policy authority | Authoritatively retire a supported recovery root before cleanup may drop its last dependency. |

Adding a logical operation that changes authority, idempotency, acceptance, conflict, or side-effect semantics is a contract/design change. Adding an internal transport route for an existing operation is not.

## Initial logical query catalog

At minimum the local API must support query semantics for:

| Logical type | Purpose |
|---|---|
| `factory.status/v1` | Active/recovery/upgrade state, generation, published application sequence, health summary. |
| `project.get/v1` / `project.list/v1` | Canonical Project state. |
| `planning-record.get/v1` | Planning graph summary, current baselines, gaps, questions, Decisions, and traceability references. |
| `work.get/v1` / `work.list/v1` | Work Item contract/status/dependencies/Lane/attempt summary. |
| `attention.list/v1` | Durable pending Attention Items and permitted actions. |
| `owner-action.get/v1` | Exact immutable package/digest and confirmation state. |
| `job.get/v1` | Worker Job/attempt, Route, envelope, terminal result summary. |
| `finding.list/v1` | Findings by subject/status/severity/disposition. |
| `route.list/v1` | Admitted Routes, capability metadata, Capacity Pool/pressure state. |
| `provider-obligation.list/v1` | Outstanding PREPARED/SEND_ARMED/UNKNOWN provider obligations and conflicts. |
| `acceptance.get/v1` | Acceptance Certificate plus evidence/recovery-root references. |
| `metrics.query/v1` | Authoritative historical metrics available under retained metric schemas. |

Large artifact bytes are retrieved through an artifact mechanism/reference rather than embedded indiscriminately in Query results.

## Worker job capability boundary

A Worker Attempt receives only the capabilities its job requires. Typical allowed operations are:

- retrieve its approved Context Packet and Work Item/Implementation Envelope;
- read allowed repository/worktree state;
- submit typed Worker Result;
- submit Finding/blocker/scope-expansion requests;
- access job-scoped runtime/tooling capabilities.

It does **not** receive:

- owner confirmation capability;
- authority to create arbitrary Factory jobs;
- protected target-ref/provider credentials;
- another attempt's worktree/capability;
- direct canonical SQLite mutation authority.

## Owner confirmation capability

Consequential Owner Actions are confirmed through a separate owner-control capability unavailable to Pilot and Worker credentials.

`owner-action.confirm/v1` binds at least:

- Owner Action ID;
- immutable package digest;
- exact target revision(s);
- scope;
- confirmation command ID;
- owner-control principal.

A stale/changed/expired package is rejected. Conversational text, including an apparent "yes", is not a confirmation proof.

## Attention actions

An Attention Item carries the exact state-dependent action descriptors currently available to the owner. Pilot/Bridge may render and discuss them, but execution becomes a typed Command subject to normal authority/revision rules.

An action disappearing because state changed is not a client error; a stale attempted action is rejected with the appropriate state/revision error and the client refreshes the Attention Item.

## Compatibility and negotiation

Factory binary version, DB schema, local API envelope versions, logical operation versions, Worker protocol, canonical object schemas, and execution manifests evolve independently.

A connection/session exposes enough capability metadata for a client to determine supported envelope and operation/query versions. The exact handshake endpoint/transport is implementation-specific.

Rules:

- unknown major schema/operation version is rejected as `UNSUPPORTED`;
- clients do not silently reinterpret one operation version as another;
- backward-compatible additions inside a schema version are allowed only when the schema contract explicitly permits unknown optional fields; otherwise bump the version;
- a breaking semantic change requires a new logical operation/schema version even if the transport route stays the same;
- unsupported combinations fail admission rather than weakening authority/durability guarantees.

## Deliberately not fixed yet

This contract does **not** decide:

- concrete HTTP paths or verbs;
- Unix-socket/Windows IPC path names;
- REST-resource versus command-bus route layout;
- Go package/type names;
- SQLite table layout;
- JSON Schema file/package directory layout;
- cursor encoding;
- compression/framing;
- implementation-specific timeout values;
- API pagination defaults before a concrete query needs them.

Those decisions may be made during implementation so long as they preserve this semantic contract.
