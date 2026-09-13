# State machines

Kind: reference

This reference collects PriFly's normative lifecycle states.

## Authoritative mutation

```text
RECEIVED
→ VALIDATED
→ LOCAL_PENDING
→ REMOTE_DURABLE
→ FRONTIER_PUBLISHED
→ RELEASED
```

Only RELEASED is authoritative success. Uploaded-but-unpublished tails are non-authoritative.

## Provider operation

```text
PREPARED
→ SEND_ARMED
→ SUCCEEDED | FAILED | UNKNOWN
```

PREPARED is known unsent. SEND_ARMED is durably authorized and may have been sent. UNKNOWN retains conflict scope until the operation profile proves a terminal outcome or an authorized ambiguity disposition occurs.

## Factory generation takeover

```text
G / ACTIVE / frontier N,T
        ↓ explicit CAS takeover
G+1 / INITIALIZING / predecessor frontier N,T
        ↓ restore N,T + reconcile obligations + establish replica
G+1 / ACTIVE / published new-generation frontier
```

Takeover CAS and old-generation authoritative publication compete on the same coordination-object version. If takeover wins, old publication cannot be acknowledged; if old publication wins, takeover rereads and inherits it.

## Work Item delivery

```text
READY
→ IMPLEMENTING
→ CANDIDATE
→ VERIFIED
→ REVIEWED
→ INTEGRATION_VERIFIED
→ MERGE_ELIGIBLE
→ DELIVERED
```

Relevant baseline, Work Item, attempt, candidate, target, verification-plan, evidence, review, or policy changes invalidate the corresponding Acceptance Certificate and return work to revalidation.

## Planning concern applicability

```text
proposed: APPLICABLE | NOT_APPLICABLE | UNKNOWN
                     ↓ Factory policy authority
 effective: APPLICABLE | NOT_APPLICABLE | UNKNOWN
```

Missing rules, missing protected-trigger coverage, or unresolved uncertainty remain UNKNOWN and block the relevant gate.

## Worker runtime

```text
ADMITTED
→ RUNNING
→ DRAINING
→ TERMINATED
```

If cleanup is uncertain, Worker Docker becomes DIRTY and Docker work remains blocked until reconciliation or disposable-environment reset establishes cleanliness.

## Factory upgrade

```text
ACTIVE
→ QUIESCING
→ PRE_UPGRADE_CHECKPOINT
→ UPGRADE_VALIDATION
→ ACTIVE
```

Rollback to the pre-upgrade checkpoint is permitted only until the upgraded Factory first publishes new authoritative state; afterward recovery is roll-forward.
