# ADR-0003: Implement PriFly as a Go modular monolith

Status: Accepted
Date: 2026-09-13

## Context

PriFly is being designed from scratch and needs a product foundation rather than a scripting prototype. The architecture favors simple local deployment and strong process/concurrency support.

## Decision Drivers

- PriFly is a long-lived local control plane with concurrency and process supervision.
- Distribution should be simple and the local stack disposable.
- v1 does not need independently deployed microservices.

## Considered Options

### Go modular monolith

Compiled single-binary core with internal package boundaries and strong concurrency/process primitives.

### Python service

Fast to prototype and familiar scripting ecosystem, but weaker single-binary packaging and long-lived process ergonomics.

### Rust service

Strong safety/performance but higher implementation complexity for this project.

### Microservices

Independent deployment boundaries, but unnecessary operational/distributed-system complexity for a personal local Factory.

## Decision

Implement the core product in Go as a modular monolith, packaged primarily as a disposable containerized Factory stack.

## Consequences

Internal boundaries must be explicit even though deployment is monolithic. The product can embed future UI assets and local API surfaces without creating network-distributed services. New process boundaries require a later architectural reason.
