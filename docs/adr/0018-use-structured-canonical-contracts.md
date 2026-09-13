# ADR-0018: Use structured canonical contracts with deterministic rendering

Status: Proposed
Date: 2026-09-13

## Context

The owner specifically wanted the system to stop relying on agents to reproduce templates correctly; canonical semantics need a machine-valid form.

## Decision Drivers

- Factory must validate Worker outputs mechanically and render the same semantics to Pilot, CLI, Bridge, GitHub, and Markdown.
- Models are unreliable at preserving exact prose templates.
- Prompt-format experimentation should not change canonical state.

## Considered Options

### Versioned JSON canonical objects + deterministic renderers

Structural JSON Schema plus Go semantic validation; UI/text are projections.

### Markdown as canonical state

Human-readable but difficult to validate, migrate, and reuse across surfaces.

### Model-controlled templates

Flexible but reintroduces formatting drift and hidden semantics.

### Database rows only with no versioned external contracts

Efficient internally but weak Worker/API interoperability and migration clarity.

## Decision

PriFly uses explicit versioned structured JSON contracts for Commands, Events, planning objects, Worker results, findings, acceptance artifacts, attention, routing, and experiments. Deterministic renderers produce Markdown/CLI/UI/provider projections.

## Consequences

Schema families and migrations become product concerns. Historical event schemas remain historical. Prompt serialization can change independently and be measured experimentally.
