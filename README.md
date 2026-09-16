# PriFly

PriFly is a local-first autonomous software factory: deterministic software owns workflow,
authoritative state, scheduling, policy enforcement, recovery and external side effects;
AI Workers perform bounded jobs requiring inference, judgment, research, coding or review.

> Big orchestration system, small cognitive jobs.

Start with the [accepted PRD](docs/reference/product-requirements.md),
[documentation index](docs/README.md), [product definition](docs/explanation/product.md),
[end-to-end lifecycle](docs/explanation/product-lifecycle.md), [C4 architecture](docs/explanation/architecture.md)
and [ADR index](docs/adr/README.md). [CONTEXT.md](CONTEXT.md) defines canonical vocabulary.

## Design status

The owner has accepted [PRD v2.1](docs/reference/product-requirements.md) as the canonical
product requirements baseline. The focused explanation/reference docs decompose that baseline.
The new ADRs are Proposed for review; historical accepted decisions retain their original bodies
and explicit amendment/supersession links. This is a design basis, not a claim of implemented,
qualified or certified behavior, and not an execution release.

[Traceability](docs/reference/traceability.md) maps source requirements, scenarios and diagrams
to their canonical homes. [Unselected parameters](docs/reference/deployment-parameters.md)
identify the choices and evidence needed before dependent releases.
Walking-skeleton delivery planning follows owner acceptance of this doc set as a separate activity.

## Documentation rules

This repository follows the `design-docs` framework:
[manifest](docs/doc-manifest.md), Diátaxis-organized canonical documents, immutable decision history
and rationale pointers when code needs durable explanation. The accepted PRD is the single
owner-authorized requirements baseline, governed together with its decomposition; no duplicate
PRD copies, transient design specs, planning/interrogation transcripts or audit reports are committed.
