# PriFly

PriFly is a local-first autonomous software factory: deterministic software owns workflow,
authoritative state, scheduling, policy enforcement, recovery and external side effects;
AI Workers perform bounded jobs requiring inference, judgment, research, coding or review.

> Big orchestration system, small cognitive jobs.

Start with the [documentation index](docs/README.md), [product definition](docs/explanation/product.md),
[end-to-end lifecycle](docs/explanation/product-lifecycle.md), [C4 architecture](docs/explanation/architecture.md)
and [ADR index](docs/adr/README.md). [CONTEXT.md](CONTEXT.md) defines canonical vocabulary.

## Design status

The canonical documentation is being reconciled to the owner's PRD Candidate 2.1.
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
and rationale pointers when code needs durable explanation. Duplicate monolithic PRDs,
design specs, planning/interrogation transcripts and audit reports are not committed.
