# Documentation manifest — as adopted here

This repository follows the `design-docs` skill standard. This file records the adopted shape; the framework rules live in the skill and are not restated here.

## Design set
- docs/explanation/architecture.md
- docs/explanation/context-and-code-intelligence.md
- docs/explanation/domain-model.md
- docs/explanation/execution.md
- docs/explanation/experiments-and-metrics.md
- docs/explanation/observability-and-retention.md
- docs/explanation/persistence-and-durability.md
- docs/explanation/pilot.md
- docs/explanation/planning.md
- docs/explanation/principles.md
- docs/explanation/providers.md
- docs/explanation/recovery-and-upgrades.md
- docs/explanation/review-and-validation.md
- docs/explanation/roadmap.md
- docs/explanation/routing-and-capacity.md
- docs/explanation/security.md
- docs/explanation/vision.md
- docs/reference/acceptance-contract.md
- docs/reference/api-contract.md
- docs/reference/planning-policy.md
- docs/reference/provider-operation-profiles.md
- docs/reference/schemas.md
- docs/reference/state-machines.md
- docs/adr/
- docs/rationale/
- CONTEXT.md

## Diátaxis directories
tutorials: docs/tutorials/ · how-to: docs/how-to/ · reference: docs/reference/ · explanation: docs/explanation/
Index: docs/README.md

## ADRs
Directory: docs/adr/ · Range in use: 0001–0020 · Normalisation ADR: none — all ADRs created post-adoption
Index markers: `<!-- adr-index:start -->` / `<!-- adr-index:end -->` in docs/adr/README.md

## Rationale areas
<!-- No rationale areas are declared before code exists. Add an area and its file before introducing any # why: pointer. -->

## Glossary
CONTEXT.md at repo root · domain model: docs/explanation/domain-model.md

## CI
`check-pointers.sh` and `adr-index.sh --check` run in: .github/workflows/docs-checks.yml (always-report)
Scripts source: scripts/docs/

## Design path
Decisions are made through owner interrogation, decomposed through planning, recorded with design-docs author mode, and landed through the repository workflow. Specs, plans, interrogation records, and architecture-review transcripts are never committed. Adopted under ADR-0001.
