# ADR-0016: Scope v1 recovery to local-host loss with a Recovery Kit

Status: Accepted
Amended-by: 0026
Date: 2026-09-13

## Context

The owner primarily wants to avoid losing hours of work/tokens and historical metrics when the local environment disappears, without turning v1 into enterprise DR.

## Decision Drivers

- The Factory host is disposable and should not lose historical state/metrics or large amounts of expensive Worker progress.
- v1 does not need multi-cloud disaster recovery or survival of destroyed provider accounts.
- Factory upgrades must preserve a repair path because PriFly is the tool used to fix PriFly.

## Considered Options

### R2/Litestream + independently retained Recovery Kit + Git checkpoints

Automated fresh-host recovery while external accounts remain available.

### Multi-cloud replicated disaster recovery

Stronger failure coverage but disproportionate operational scope for a personal v1.

### Local-only persistence

Simplest but host loss discards metrics, decisions, and expensive work.

### Git as Factory backup/state store

Durable and familiar, but reintroduces Git as workflow database and complicates state transitions.

## Decision

v1 recovery guarantees replacement of the local PriFly host while R2, configured Git remotes, accounts, and the Recovery Kit remain available. The Recovery Kit independently supplies bootstrap identity/access. Upgrades may roll back only until the upgraded Factory publishes its first new authoritative state; afterward recovery is roll-forward.

## Consequences

The product does not claim survival of permanent R2/Git account loss or malicious deletion of all remote copies. Restore drills and a protected known-good recovery root guard ordinary failures. Worker Git checkpoints reduce token/work loss between Factory restores.
