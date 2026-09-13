# ADR-0007: Treat external providers as projections with durable obligations

Status: Proposed
Date: 2026-09-13

## Context

PriFly must push branches, create projections, and integrate code while surviving lost responses and owner/provider edits.

## Decision Drivers

- GitHub must remain useful as a GUI/collaboration surface without becoming workflow authority.
- Provider APIs have different idempotency, retry, and ambiguity semantics.
- A crash after external send can leave outcome unknown.

## Considered Options

### Factory authority with per-operation provider profiles

Persist admitted obligations before send and reconcile UNKNOWN outcomes according to operation-specific rules.

### Let Workers manipulate GitHub directly

Simple but leaks provider authority and makes workflow state dependent on agent behavior.

### Generic exactly-once outbox abstraction

Attractive API, but many provider operations do not expose exactly-once/idempotency primitives.

### Treat GitHub issues/projects as canonical workflow state

Reuses UI but couples Factory correctness to provider rate limits and external edits.

## Decision

Provider systems are projections/external facts. Consequential sends transition through authoritative PREPARED and SEND_ARMED states before the first network byte. Unknown outcomes remain UNKNOWN and retain conflict scope until the admitted operation profile proves a terminal result or authorized disposition.

## Consequences

Provider Broker becomes the privileged choke point. Some ambiguous projection operations may remain blocked rather than blindly retried. External merges/edits are recorded as facts, never retroactive PriFly approval.
