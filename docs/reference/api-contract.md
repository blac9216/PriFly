# Local application API contract

Kind: reference

This document defines semantic API contracts, not final endpoint paths. The initial transport is local IPC; HTTP/JSON semantics may be used over Unix sockets or equivalent local transports.

## Commands

Every authoritative mutation is a versioned Command containing at least:

| Field | Meaning |
|---|---|
| `command_id` | Idempotency identity. Reuse with materially different actor/payload is rejected. |
| `type` | Versioned command type. |
| `actor` | Owner, Worker job attempt, Factory subsystem, or provider observation principal. |
| `target_revision` | Expected canonical revision when stale-state protection is required. |
| `payload` | Versioned command-specific data. |

Factory validates authority, state/revision, generation, and policy before commit. Authoritative success is not returned until the transaction is released through the Published Frontier.

## Queries

Queries are non-mutating reads of canonical state. Owner-facing canonical queries operate on the latest released/published state. Diagnostic/provisional state, if exposed, must be explicitly labelled and cannot be used as authoritative success.

## Events

Events describe semantic facts that occurred and support notification, audit, and projections. Event delivery is not authority. A reconnecting client queries canonical state rather than assuming it received every event.

## Worker job capability

A Worker attempt capability is scoped to its own job. Typical permitted actions include:

- retrieve approved job context;
- submit structured result;
- submit a Finding;
- request scope/access expansion;
- report execution state.

It does not confer owner confirmation, protected-ref provider authority, or arbitrary job creation.

## Owner confirmation capability

Consequential Owner Actions use a separate owner-control capability unavailable to Pilot and Worker credentials. Confirmation binds Owner Action ID, immutable package digest, target revision, scope, command ID, and owner-control principal.

## Attention actions

Attention Items expose state-dependent allowed actions. UI clients render those actions conversationally or graphically but submit the same typed Factory Commands.

## Compatibility

API versions evolve independently from Factory binary, DB schema, Worker protocol, artifact schemas, and execution manifests. Unsupported combinations fail admission rather than silently weakening guarantees.
