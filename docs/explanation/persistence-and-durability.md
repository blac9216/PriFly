# Persistence and durability

Kind: explanation

PriFly uses SQLite as canonical local state and R2/Litestream as the off-host durability path. The core rule is stronger than “the bytes were uploaded”: authoritative state is released only after its exact recoverable frontier is published through the coordination record.

### SQLite is canonical Factory state

SQLite stores compact authoritative state and semantic history, including:

- Projects;
- Planning Records and graph objects;
- baselines and Change Requests;
- Work Items, dependencies, and lanes;
- Worker jobs and attempts;
- Findings/reviews;
- Owner Actions and Attention Items;
- provider objects/outbox obligations;
- routing/experiment state;
- historical metrics;
- artifact references;
- semantic Ledger Events.

Current-state rows and semantic Ledger Events change in the same SQLite transaction.

PriFly does not require full event sourcing.

### Authoritative versus ephemeral data

PriFly distinguishes ephemeral data from authoritative semantic state.

#### EPHEMERAL

Examples:

- heartbeats;
- live progress;
- transient process identifiers;
- cache/index state;
- stdout tails;
- temporary scheduler telemetry.

EPHEMERAL data may be lost on host destruction.

#### AUTHORITATIVE

Examples:

- owner decisions;
- Constitution changes;
- actionable Attention Items;
- Findings and review verdicts;
- baseline state;
- accepted Work Item/result state;
- scope grants;
- real experiment assignments;
- routing-policy changes;
- consequential provider obligations;
- historical metrics that PriFly intends to use for long-term planning/routing analysis.

AUTHORITATIVE mutations must satisfy the durable acknowledgement protocol below before Factory publishes them as authoritative success or releases dependent authoritative work.

### Large artifacts

Large diagnostic/evidence objects live outside SQLite, normally in R2, with hashes/metadata/references in SQLite.

Code artifacts use Git as described in [Git artifact recovery](execution.md#git-artifact-recovery).

## Single mutation path

All authoritative mutations enter Factory through typed, versioned Commands.

Commands carry a unique command ID, actor identity, expected object/revision where relevant, and a versioned payload. Factory validates authority, state/revision, Factory generation, domain invariants, and relevant policy.

A successful local transaction updates current state, appends Ledger Events, records any outbox obligation, and records the transaction's durability sequence/marker. Command IDs are idempotent; reuse with a materially different actor or payload is rejected.

Queries inspect state without mutation. Events notify clients that state changed; reconnecting clients query canonical state rather than treating event delivery as authority.

## Durable acknowledgement and published recovery frontier

PriFly binds authoritative acknowledgement to both **remote database durability** and an **R2-published authoritative frontier**.

### Local commit is not acknowledgement

An AUTHORITATIVE command progresses:

```text
RECEIVED
→ validated
→ SQLite committed (LOCAL-PENDING)
→ Litestream remotely durable through transaction marker N / remote TXID T
→ coordination publication CAS succeeds for N/T
→ RELEASED/DURABLE
```

Until final coordination publication succeeds, the mutation is not returned as authoritative success, exposed as a released authoritative Query result, emitted as a final owner-visible success Event, used to release dependent authoritative scheduling, or allowed to dispatch consequential provider effects. Uploaded-but-unpublished database tails are recoverable bytes but are **not authoritative history**.

If Factory cannot determine whether the publication CAS succeeded, the command has **no definitive disposition yet**. It must be resolved/read back/retried using the same command identity as defined by the [API contract](../reference/api-contract.md#nonfinal-command-status); publication uncertainty is not authoritative rejection.

### Application sequence and remote position

Every authoritative SQLite transaction receives a monotonic Factory application sequence `N`. The durability adapter proves that the replica contains SQLite state through `N` and records the concrete remote restore position `T` required by the pinned Litestream integration.

```text
SyncThrough(N) -> RemotePosition T
```

The implementation must demonstrate that restoring through `T` contains transaction `N`. PriFly does not assume its application sequence and Litestream's internal transaction identifiers are numerically identical.

The durability adapter must also preserve an **exactly reconstructible** published frontier for the entire period that the coordination record or any supported Recovery Root Manifest depends on that frontier. Passing an immediate restore test or recording a synced remote transaction identifier is insufficient if compaction, retention, chain expiry, or interrupted initialization can later make the published position unreconstructible. Retention/compaction policy therefore participates in the recovery guarantee.

### Coordination publication

R2 holds one CAS-protected coordination object:

```json
{
  "generation": 44,
  "state": "ACTIVE",
  "factory_instance": "...",
  "published_sequence": 101,
  "published_remote_position": "T101",
  "recoverable_replica": "epochs/44/..."
}
```

For the active generation, Factory may acknowledge sequence `N` only after SQLite transaction `N` commits, the generation replica is remotely durable through `N`, Factory obtains `T`, and Factory CAS-updates the exact prior coordination-object version to publish `N/T`. A lost CAS response may be treated as success only when read-back proves the exact intended state. If the CAS fails because ownership/generation changed, the old Factory must not acknowledge `N` even if bytes exist in its abandoned replica.

Coordination publication is the linearization point for authoritative semantic release.

### Serialized publication lane in v1

v1 uses one authoritative publication lane:

```text
authoritative transaction N
→ remote sync through N
→ publish N/T via coordination CAS
→ release N
→ next authoritative transaction
```

Ephemeral telemetry/logging do not use this lane.

### Crash semantics

- Crash before SQLite commit: the command did not occur.
- Crash after local commit but before remote durability: no authoritative success exists.
- Remote bytes exist but coordination publication did not occur: the tail is non-authoritative and may be discarded during recovery.
- Coordination publication succeeds but the publication/client response is lost: the command remains nonfinal to the caller until read-back/recovery proves the published result; recovery restores through the published position and a same-command retry returns the original `RELEASED` result.
- Authoritative success returned: every permitted successor must restore at least the published frontier containing that result.

No recursive receipt transaction is required; the CAS-published remote frontier is itself the recovery authorization.

### Query and event visibility

Internally, Factory may know about LOCAL_PENDING state, but owner-facing canonical reads and downstream authoritative workflow operate on the latest Published Frontier. Implementations may block an authoritative query behind the publication lane or expose an explicitly provisional diagnostic view; provisional state must never be confused with authoritative state.

## Factory ownership, generations, and authoritative takeover cutover

PriFly uses one CAS-protected R2 coordination record as both ownership state and authoritative recovery-frontier publication.

### Coordination record

The object carries generation, state, Factory instance, published sequence, published remote position, and recoverable replica. Its object version/ETag is part of every CAS.

### Active-generation publication rule

Every AUTHORITATIVE semantic release in generation `G` must CAS-publish its remote frontier through that object. Therefore a transaction uploaded after a successor changes the coordination object cannot later become acknowledged by the old generation; if the old Factory's publication CAS fails, its uploaded tail is non-authoritative; if the old Factory publishes first, a successor acquisition based on an older object version fails and must reread the newer frontier.

### Takeover initiation

v1 has no timer-based leader election. Takeover is explicit through the Recovery Kit/owner recovery workflow. The replacement CAS-transitions:

```text
generation G / ACTIVE / published frontier N/T
        ↓ CAS
generation G+1 / INITIALIZING / predecessor frontier N/T
```

The successful takeover CAS fences further authoritative publication by generation `G`. Uploaded-but-unpublished tails are not authoritative. Already-published SEND_ARMED obligations are part of the predecessor Published Frontier and are inherited.

### Recovery source

The successor restores **exactly through the predecessor's CAS-published remote position `T`**, not the latest bytes present in the old epoch. The restore is validated to contain published application sequence `N`.

### Interrupted INITIALIZING

While generation `G+1` is `INITIALIZING`, no normal new authoritative project work is accepted. If it dies, the coordination object still records the predecessor Published Frontier. A later recovery advances generation again and restarts from the last published authoritative frontier unless activation had already completed. Missing or inaccessible recovery data never means initialize a fresh empty Factory.

### Reconciliation during initialization

The successor restores the complete published obligation set, including every SEND_ARMED/UNKNOWN operation in the frontier. Before ACTIVE, provider reconciliation is read-only with respect to new project effects; unresolved conflict scopes remain reserved and conflicting successor operations are not authorized.

### Activation

After restore, validation, reconciliation, and establishment of the new replica, Factory CAS-publishes generation `G+1` as ACTIVE with its restorable Published Frontier. Only after that succeeds may new authoritative project Commands be released.

### Lost CAS responses

A lost publication/takeover CAS response is resolved by exact read-back of generation, Factory instance, state, and published sequence/position. If exact read-back is temporarily unavailable, Factory does not assert success **or rejection** for the affected command/transition. It fails closed operationally and resumes resolution from the newly observed authoritative record once available.

### Scope of fencing

Generation coordination fences authoritative semantic release, new Worker dispatch, transition to SEND_ARMED, and new consequential provider authorization. It does not cancel a request already SEND_ARMED/sent; those obligations are handled by [Provider integration](providers.md).
