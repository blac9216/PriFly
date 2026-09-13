# Recovery and upgrades

Kind: explanation

The local PriFly host is disposable. v1 recovery is intentionally scoped to replacing that host while R2, Git remotes, accounts, and the independently retained Recovery Kit remain available.

### 22.1 Recovery Kit

v1 uses a small independently retained encrypted **Recovery Kit** rather than assuming local cached credentials survive.

The Recovery Kit contains or makes available the minimum material required to:

- identify the Factory;
- authenticate/access R2;
- locate the coordination record/state;
- obtain provider credentials or reauthorization information required for normal operation;
- validate bootstrap identity/configuration.

A non-secret manifest may also be versioned in Git, but fresh-host recovery must not depend on already having a local clone whose access credentials are inside the lost Factory.

The owner retains the Recovery Kit/root recovery material separately from the disposable PriFly host.

### 22.2 Automated recovery

Given:

- PriFly release/binary/container images;
- Recovery Kit/root material;

Factory recovery is automated:

```text
BOOTSTRAP
→ SECRETS
→ REMOTE DISCOVERY
→ EXPLICIT TAKEOVER
→ RESTORE
→ VALIDATE
→ MIGRATE IF REQUIRED
→ RECONCILE UNKNOWN OBLIGATIONS
→ ESTABLISH REPLICA
→ ACTIVATE
```

Source/code work is recovered from configured Git remotes; Factory state/metrics are recovered from R2.

### 22.3 Recovery goals

The practical v1 goal is:

- preserve authoritative history and historical metrics;
- avoid losing substantial completed/in-progress Worker work through periodic upstream branch checkpointing;
- make local host replacement a minutes-scale automated process where dependencies are available.

v1 does not attempt enterprise multi-cloud disaster recovery.

---

## Pre-ACTIVE recovery and repair mode

PriFly provides a restricted local recovery CLI/mode available even when normal Factory cannot reach `ACTIVE`.

It uses Recovery Kit authority rather than normal Owner Attention state.

Allowed operations are narrowly bounded, for example:

- inspect bootstrap/recovery status;
- inspect last known coordination/recovery metadata;
- provide/rotate required recovery credential;
- retry restore;
- retry provider read-only reconciliation;
- abort/reset an incomplete local recovery attempt;
- produce a diagnostic bundle.

It may not perform normal project delivery or silently mutate canonical workflow state before restore/authority is established.

This prevents the failure mode where the Factory required to repair Factory cannot start because ordinary Pilot/Attention services are unavailable.

---

## Recovery testing and protected recovery roots

PriFly periodically restores Factory state into disposable storage and validates:

- SQLite integrity;
- domain/schema invariants;
- preservation of authoritative historical metrics;
- the published coordination frontier;
- required Recovery Root Manifest dependencies for the tested checkpoint.

v1 keeps at least one verified known-good recovery root protected from ordinary cleanup until a newer root is verified and authoritatively replaces it.

A Recovery Root Manifest identifies the required external closure for the supported checkpoint as defined in [recovery-root closure](review-and-validation.md#recovery-root-closure).

This protection addresses ordinary retention/cleanup mistakes under the declared local-host-loss failure model. It does not claim resistance to malicious destruction of the entire cloud account.

Major persistence, coordination, artifact-retention, migration, or recovery changes require a recovery simulation that exercises the published-frontier protocol and an empty-host restore.

## Factory updates and rollback cutoff

Factory upgrades follow:

```text
ACTIVE
→ QUIESCE
→ DURABLE PRE-UPGRADE CHECKPOINT
→ INSTALL/START NEW VERSION
→ VALIDATE/MIGRATE
→ HEALTH CHECK
→ ACTIVE
```

### Database migration policy

[ADR-0020](../adr/0020-use-timestamped-forward-only-migrations.md) defines the database migration strategy.

Migration files are forward-only and ordered by UTC timestamp IDs using the form:

```text
YYYYMMDDHHMMSSffffff_<kebab-slug>.sql
```

The timestamp prefix is the migration ordering key. CI rejects malformed or duplicate IDs. This avoids the merge-collision pattern created when parallel Workers both choose the same next sequential number; it does not remove semantic conflicts between migrations that touch the same schema surface.

Only the Factory migration runner applies migrations to the canonical Factory database. Workers may author and test migrations only against disposable/test databases. Canonical migration therefore occurs while Factory is quiesced or before it reaches `ACTIVE`.

Each applied migration is recorded in a migration ledger containing at least:

- migration ID;
- content checksum;
- application time;
- Factory version;
- active schema baseline/epoch.

An already-recorded migration ID with a different checksum is a hard compatibility failure. A migration becomes immutable when it lands on `main`; unmerged branches may replace their migration before merge when integration requires it.

PriFly deliberately has no paired `down` migration contract. Before the rollback cutoff, the durable pre-upgrade checkpoint is the rollback mechanism. After the cutoff, recovery is roll-forward.

### Pre-v1 consolidation

Pre-v1 migration history is provisional because no supported external upgrade path exists yet. PriFly may consolidate development migrations at deliberate milestones so the first supported release does not inherit every exploratory schema step.

A consolidation follows this order:

```text
QUIESCE DEVELOPMENT FACTORY
→ APPLY ALL CURRENT DEVELOPMENT MIGRATIONS
→ DURABLE CHECKPOINT
→ VALIDATE SCHEMA + DOMAIN INVARIANTS
→ GENERATE + CHECKSUM NEW BASELINE
→ VERIFY BASELINE REPRODUCES RESULTING SCHEMA
→ PROMOTE CURRENT DATABASE TO BASELINE MARKER
→ REMOVE SUPERSEDED PRE-V1 MIGRATIONS FROM ACTIVE TREE
→ RESUME
```

Promotion to the new baseline does **not** rebuild the current development database or discard its authoritative data. The migration runner verifies that the database is at the exact expected pre-consolidation migration frontier and passes the required schema/domain checks, then records the new baseline/epoch marker.

Fresh databases initialize directly from the new baseline. A pre-v1 database that did not reach the consolidation frontier before the old migrations were removed is not a supported upgrade path; it must either be brought forward using the older source revision that still contains those migrations or be rebuilt. This is acceptable before v1 because pre-release database compatibility is explicitly not promised.

Before the first supported v1 release, PriFly performs a final consolidation. v1 therefore begins from one clean schema baseline plus any migrations intentionally added after the cut, normally none.

### Post-v1 migration history

After v1, migrations required by a supported release-to-release upgrade path are compatibility artifacts and remain immutable. PriFly may later introduce a newer fresh-install baseline, but it may not remove migrations still required by the declared supported upgrade window.

CI and release conformance must test:

- migration ID syntax and uniqueness;
- immutable checksums for shipped migrations;
- fresh creation from the current baseline plus pending migrations;
- every declared supported release-to-release upgrade path;
- schema/domain invariants after migration;
- semantic equivalence between a consolidation baseline and the migration frontier it replaces.

The concrete Go migration library, source-tree path, migration transaction wrapper, and schema-fingerprint implementation are implementation choices. They must preserve this policy rather than redefine it.

### 25.1 Health checks

Before the upgraded Factory accepts new authoritative mutations it verifies, at minimum:

- SQLite integrity;
- migration ledger integrity and expected baseline/epoch;
- schema/domain invariants;
- compatibility manifest;
- R2 replication/durability;
- coordination ownership;
- Recovery Kit/SecretProvider access required for continued operation;
- provider read/reconciliation access;
- ability to restore the pre-upgrade checkpoint.

### 25.2 Rollback cutoff

Rollback to the pre-upgrade checkpoint is permitted only **before** the upgraded Factory acknowledges its first new AUTHORITATIVE mutation.

After the first new authoritative acknowledgement, checkpoint rollback is closed. Recovery is **roll-forward**.

This avoids discarding post-upgrade owner decisions/results/provider facts.

### 25.3 Versioned compatibility

Factory binary, DB schema baseline/epoch, migration frontier, local API, Worker protocol, artifact schemas, and resolved execution manifests are versioned separately.

Incompatible in-flight Workers are interrupted/requeued rather than requiring indefinite backward Worker-protocol support.

---
