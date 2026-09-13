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

Major persistence, coordination, artifact-retention, or recovery changes require a recovery simulation that exercises the published-frontier protocol and an empty-host restore.

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

### 25.1 Health checks

Before the upgraded Factory accepts new authoritative mutations it verifies, at minimum:

- SQLite integrity;
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

Factory binary, DB schema, local API, Worker protocol, artifact schemas, and resolved execution manifests are versioned separately.

Incompatible in-flight Workers are interrupted/requeued rather than requiring indefinite backward Worker-protocol support.

---
