# Documentation manifest — as adopted here

This repository follows the `design-docs` skill standard, with the explicit owner-authorized
accepted-PRD exception below. This file records the adopted shape; other framework rules live
in the skill and are not restated here.

## Design set

- docs/reference/product-requirements.md
- docs/explanation/product.md
- docs/explanation/product-lifecycle.md
- docs/explanation/architecture.md
- docs/explanation/domain-model.md
- docs/explanation/pilot.md
- docs/explanation/planning.md
- docs/explanation/engineering-quality.md
- docs/explanation/delivery-planning.md
- docs/explanation/routing-and-capacity.md
- docs/explanation/context-and-code-intelligence.md
- docs/explanation/execution-runtime.md
- docs/explanation/execution.md
- docs/explanation/review.md
- docs/explanation/findings-and-triage.md
- docs/explanation/git-integration.md
- docs/explanation/validation.md
- docs/explanation/change-control.md
- docs/explanation/release-and-closeout.md
- docs/explanation/providers.md
- docs/explanation/persistence-and-durability.md
- docs/explanation/recovery.md
- docs/explanation/upgrades.md
- docs/explanation/experiments-and-metrics.md
- docs/explanation/security.md
- docs/explanation/operator-experience.md
- docs/explanation/risks-and-assumptions.md
- docs/explanation/roadmap.md
- docs/reference/traceability.md
- docs/reference/worker-roles.md
- docs/reference/worker-prompts.md
- docs/reference/state-machines.md
- docs/reference/schemas.md
- docs/reference/api-contract.md
- docs/reference/planning-policy.md
- docs/reference/quality-rubrics.md
- docs/reference/standards-registry.md
- docs/reference/source-register.md
- docs/reference/attack-profiles.md
- docs/reference/acceptance-contract.md
- docs/reference/provider-operation-profiles.md
- docs/reference/product-acceptance.md
- docs/reference/conformance.md
- docs/reference/deployment-parameters.md
- docs/reference/design-governance.md
- docs/adr/
- docs/rationale/
- CONTEXT.md

## Diátaxis directories

tutorials: docs/tutorials/ · how-to: docs/how-to/ · reference: docs/reference/ · explanation: docs/explanation/
Index: docs/README.md

Tutorials and operational recipes are intentionally empty until executable product behavior exists.
The design specifies their future obligations without publishing fictional runbooks.

## ADRs

Directory: docs/adr/ · Range in use: 0001–0030 · Normalisation ADR: none — all ADRs created post-adoption
Index markers: `<!-- adr-index:start -->` / `<!-- adr-index:end -->` in docs/adr/README.md

## Rationale areas

<!-- No rationale areas are declared before code exists. Add an area and its file before introducing any # why: pointer. -->

## Glossary

CONTEXT.md at repo root · domain model: docs/explanation/domain-model.md

## CI

`check-pointers.sh`, `adr-index.sh --check`, the mechanical design-doc audit, and
repository-relative Markdown link/fragment validation run in:
.github/workflows/docs-checks.yml (always-report)
Scripts source: scripts/docs/

Mechanical checks do not establish semantic quality, product qualification or owner authority.
Applicable pinned quality profiles, exact source traceability and independent scenario review
are separate evidence obligations.

## Design path

Durable decisions follow owner direction/interrogation, canonical design recording, and independent
repository review; delivery planning then materializes only released scope. Architectural changes
require new ADRs and all affected canonical documents in the same change. Accepted decision bodies
are immutable. Transient specs, plans, interrogation records, research/audit reports and duplicate
PRD copies are not committed.

The owner's explicit acceptance and placement instruction establishes
`docs/reference/product-requirements.md` as the single canonical product requirements baseline,
an intentional exception to the framework's prohibition on committing specs. It is an accepted
outcome, not deliberation. Focused docs decompose it without independently changing its meaning.
The owner maintains product acceptance authority; a product-requirement change updates the PRD,
affected decomposition and traceability together through owner approval and independent review.
See `docs/reference/design-governance.md` for conflicts and phase-release limits.

The product summary lives in `docs/explanation/product.md`; choreography in
`docs/explanation/product-lifecycle.md`; source and obligation navigation in
`docs/reference/traceability.md`; external engineering sources/rubrics in the standards registry
and quality inventory; implementation guarantee oracles in `docs/reference/conformance.md`.
Each subsystem owns its detailed contract. Adopted under ADR-0001.
