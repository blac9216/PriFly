# PriFly

PriFly is a local-first autonomous software factory: deterministic software owns workflow,
authoritative state, scheduling, policy enforcement, recovery, and external side effects;
AI Workers perform bounded jobs that benefit from inference, judgment, research, coding, or review.

> **Big orchestration system, small cognitive jobs.**

The project is currently in architecture-to-implementation transition. The canonical design set
lives under [`docs/`](docs/README.md). A fresh reader should start with the
[product definition](docs/explanation/product.md), then the
[end-to-end product lifecycle](docs/explanation/product-lifecycle.md),
[C4 architecture](docs/explanation/architecture.md), and the [ADR index](docs/adr/README.md).
Canonical terminology is defined in [`CONTEXT.md`](CONTEXT.md).

## Architecture status

The architecture is approved for implementation planning. That is **not** a claim that the implementation or recovery mechanisms have already passed conformance testing. Required implementation ADRs and tests are tracked in the canonical docs and future work planning.

## Documentation rules

This repository adopts the `design-docs` documentation framework. Decisions live in ADRs, durable
product/system explanation lives in Diátaxis-organized docs, and committed design specs/planning transcripts
or a duplicate monolithic PRD are intentionally not used. See [`docs/doc-manifest.md`](docs/doc-manifest.md).
