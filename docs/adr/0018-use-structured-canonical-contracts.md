# ADR-0018: Use structured canonical contracts with deterministic rendering

Status: Accepted
Date: 2026-09-13

## Context

The owner specifically wanted the system to stop relying on agents to reproduce templates correctly; canonical semantics need a machine-valid form. PriFly also has multiple future clients and producers — Pilot, Bridge, CLI, Workers, provider adapters, recovery tooling — that must not each invent their own meaning for work, authority, acceptance, or state transitions.

The architecture is being fixed before the implementation is decomposed. If the semantic API and canonical object boundaries remain vague until individual features are built, different workstreams can independently invent incompatible meanings for identity, revisions, idempotency, authority, errors, evidence, lifecycle state, and provider ambiguity even while all of them nominally “use JSON.”

At the same time, freezing HTTP routes, Go structs, SQLite tables, or every role-specific payload before implementation would turn the architecture record into a speculative implementation spec.

## Decision Drivers

- Factory must validate Worker outputs mechanically and render the same semantics to Pilot, CLI, Bridge, GitHub, and Markdown.
- Multiple independent implementation workstreams need one definition of identity, revision, authority, idempotency, error/retry behavior, and object references before decomposition.
- Models are unreliable at preserving exact prose templates or implicit field conventions.
- Commands, Queries, Events, acceptance artifacts, and provider obligations are architectural safety boundaries, not just serialization choices.
- Prompt-format experimentation should not change canonical state.
- Transport, database normalization, and Go package layout should remain implementation choices where they do not change semantics.

## Considered Options

### Versioned JSON canonical objects + semantic boundary contracts + deterministic renderers

Define common envelopes, canonical object families, field semantics, authority/provenance, versioning, and cross-object invariants before decomposition. Use JSON Schema for structural validation and Go for semantic/domain validation. Leave endpoint paths, DB tables, Go type layout, and unneeded role-specific payload detail open.

This gives independent implementation work a shared contract without pretending the implementation has already been designed.

### Versioned JSON objects, but define fields opportunistically during feature implementation

Keeps early documentation short and allows feature teams to discover needs. However, identity/revision/error/authority semantics would be decided repeatedly in separate workstreams and become expensive to reconcile once persisted data and clients exist.

### Markdown as canonical state

Human-readable but difficult to validate, migrate, compose across clients, or use as a reliable authority boundary.

### Model-controlled templates

Flexible but reintroduces formatting drift, hidden semantics, and producer-controlled interpretation.

### Database rows only with no versioned external contracts

Efficient internally but weak Worker/API interoperability and migration clarity. Persistence representation would accidentally become the product contract.

### Fully specify REST endpoints, Go types, and database schemas before implementation

Provides maximum up-front detail, but prematurely couples architecture to mechanics that should be discovered and tested during implementation.

## Decision

PriFly uses explicit versioned structured JSON contracts for Commands, Events, planning objects, Worker results, findings, acceptance artifacts, attention, routing, and experiments. Deterministic renderers produce Markdown/CLI/UI/provider projections.

The following are part of that decision:

1. **Define semantic boundary contracts before implementation decomposition.** `docs/reference/api-contract.md` owns common Command/Query/Event/result semantics, authority, idempotency, error/retry behavior, consistency, and the logical operation/query catalog.
2. **Define canonical object families before their first implementation.** `docs/reference/schemas.md` owns minimum semantic fields, identity/revision/reference conventions, provenance, versioning, and the boundary between structural and domain validation.
3. **Use closed authoritative schemas by default.** Unknown semantic fields are rejected unless a schema explicitly declares an extension point; breaking semantic changes receive a new version.
4. **Keep authority outside producer-controlled data.** Authenticated adapters stamp actor identity; a serialized actor/classification/result cannot grant itself authority.
5. **Separate structural and semantic validation.** JSON Schema validates structure. Go/domain policy validates authority, state, graphs, freshness, reconstructibility, and other cross-object invariants.
6. **Keep transport and persistence replaceable.** HTTP paths/verbs, IPC path names, cursor encoding, Go structs/packages, SQLite table layout, and schema-file directory layout are not architectural contracts unless a later decision proves that their exact form affects a durable guarantee.
7. **Treat executable JSON Schemas as implementation artifacts conforming to the canonical reference.** They are committed when a family has a real producer/consumer, rather than creating speculative executable-looking schemas with no implementation.
8. **Separate immutable evidence/decision subjects from mutable lifecycle projections.** Immutable certificates, manifests, baselines, and Route versions are never edited to represent later status; revisioned status/admission objects or later immutable bindings reference them instead.
9. **Do not turn publication uncertainty into a terminal command result.** `RELEASED` and provably final `REJECTED` are definitive dispositions; unresolved durability/publication is explicit nonfinal status resolved with the same command identity.

## Consequences

PriFly gains a stable semantic language before feature decomposition and Work Items are created. Pilot, Bridge, Workers, Factory subsystems, verification, recovery, and provider adapters can be implemented independently without redefining core contracts.

Schema families, logical operation versions, and migrations become explicit product concerns. More changes will require deliberate schema/version evolution instead of silently adding fields. Historical Event/certificate/baseline semantics remain interpretable under their original versions.

The references become normative enough that implementation must demonstrate conformance. In exchange, implementation remains free to choose efficient Go/SQLite/IPC representations so long as they preserve those semantics.

Prompt serialization and renderer formats can change independently and be measured experimentally without changing canonical state.
