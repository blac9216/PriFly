# ADR-0004: Use SQLite as canonical Factory state

Status: Accepted
Date: 2026-09-13

## Context

PriFly needs one authoritative state store for planning, jobs, decisions, attention, routing, provider obligations, metrics, and recovery state.

## Decision Drivers

- The local host is disposable, but the Factory needs transactional current state and semantic history.
- Git/provider systems must not become hidden workflow databases.
- Recovery and queries should not require replaying the entire event history.

## Considered Options

### SQLite canonical state plus semantic Ledger

Transactional local database stores both current projections and semantic history.

### Git ledger as canonical state

Excellent history/distribution but awkward for high-frequency workflow transitions and structured queries.

### Full event sourcing

Strong replay model but adds event-rebuild and migration complexity not required by the product.

### PostgreSQL

Powerful multi-client database but unnecessary external service for v1 single-Factory deployment.

## Decision

SQLite is the canonical Factory state store. Current-state rows and semantic Ledger Events are updated in the same SQLite transaction; PriFly is not fully event-sourced.

## Consequences

Factory gets transactional invariants and direct queryability. Off-host replication becomes necessary because the local host is disposable. Git and GitHub remain code/provider systems rather than workflow-state authorities.
