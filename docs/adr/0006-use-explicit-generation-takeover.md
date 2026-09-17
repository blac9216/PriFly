# ADR-0006: Use explicit generation takeover through one coordination record

Status: Accepted
Amended-by: 0031
Date: 2026-09-13

## Context

The product only needs to recover when the local host is gone. Earlier automatic-lease designs created race conditions disproportionate to that requirement.

## Decision Drivers

- v1 needs local-host replacement, not highly available leader election.
- Two active Factories must not both publish authoritative state.
- Takeover must preserve every acknowledged predecessor frontier and SEND_ARMED obligation.

## Considered Options

### Explicit CAS takeover on one coordination record

Owner/recovery workflow advances generation and fences old authoritative publication using the same object that publishes the recovery frontier.

### TTL/clock-based lease expiry

Automatic takeover, but introduces clock/partition races and distributed-systems complexity not needed for v1.

### Separate lease and recovery-pointer objects

Separates concerns conceptually but creates cross-object publication races.

### Manual database surgery

Minimal code, but defeats automated disposable-host recovery.

## Decision

Factory takeover is explicit. One CAS-protected R2 coordination record carries generation, lifecycle state, published application sequence, concrete remote restore position, and recoverable replica. A takeover CAS fences further authoritative publication by the predecessor generation.

## Consequences

PriFly favors safety and inspectability over automatic failover. If the old generation uploaded bytes after losing publication authority, those tails are discarded. Already-published external obligations are inherited and reconciled.
