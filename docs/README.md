# Documentation

Kind: reference

This set contains the owner's [Accepted PRD v2.1](reference/product-requirements.md) and its
canonical decomposition. The PRD governs product requirements; the product summary, lifecycle,
architecture, glossary and subsystem docs provide focused views of that same baseline.
[Traceability](reference/traceability.md) maps the source's stable identities to these homes.
The [manifest](doc-manifest.md) records the adopted shape. The [ADR index](adr/README.md)
distinguishes accepted history from proposed amendments; documentation is not implementation proof.

## Tutorials — learning by doing

None yet: executable onboarding tutorials require a working product and verified procedures.

## How-to — task recipes

None yet: [operator experience](explanation/operator-experience.md) defines the required recipes;
it does not pretend that unimplemented commands can be run.

## Reference — facts and contracts

- [Accepted product requirements](reference/product-requirements.md) — complete owner-accepted PRD v2.1 baseline.
- [Requirement and source traceability](reference/traceability.md) — source identity, obligations and diagram catalog.
- [Worker roles](reference/worker-roles.md) — thirteen roles and responsibility routing.
- [Worker prompt contracts](reference/worker-prompts.md) — cold-start contract and thirty-five job modules.
- [States and transitions](reference/state-machines.md) — lifecycle guards and typed uncertainty.
- [Canonical record contracts](reference/schemas.md) — identity, semantic fields and cross-record invariants.
- [Application API](reference/api-contract.md) — Command, Query, Event and finality semantics.
- [Planning policy](reference/planning-policy.md) — owner releases, engineering gates and applicability.
- [Engineering quality rubrics](reference/quality-rubrics.md) — nineteen pinned profiles and criterion inventory.
- [Standards registry](reference/standards-registry.md) — source versions and update/access rules.
- [Product and dependency sources](reference/source-register.md) — provenance and official technical sources.
- [Attack profiles](reference/attack-profiles.md) — adversarial review techniques and code traps.
- [Acceptance contract](reference/acceptance-contract.md) — exact subjects, credible evidence and durable certificates.
- [Provider operation profiles](reference/provider-operation-profiles.md) — possible-send safety and PR-only merge admission.
- [Product acceptance](reference/product-acceptance.md) — nonfunctional requirements and eighty acceptance scenarios.
- [Implementation conformance](reference/conformance.md) — failure-injection oracles, not completed runtime tests.
- [Unselected parameters](reference/deployment-parameters.md) — twenty-three choices/qualifications and release dependencies.
- [Design governance](reference/design-governance.md) — review, authority and durable change rules.

## Explanation — purpose and system behavior

- [Product definition](explanation/product.md) — promise, users, scope and bounding principles.
- [Product lifecycle](explanation/product-lifecycle.md) — stories and end-to-end journey.
- [Architecture](explanation/architecture.md) — C4 Context, Container and Component views.
- [Domain model](explanation/domain-model.md) — canonical identities and relationships.
- [Pilot and owner attention](explanation/pilot.md) — disposable conversation and separate confirmation.
- [Requirements and design](explanation/planning.md) — Intake, packages, architecture and Design Completeness.
- [Engineering quality](explanation/engineering-quality.md) — source-derived criteria and mechanical application.
- [Delivery planning](explanation/delivery-planning.md) — slices, estimates and Delivery Readiness.
- [Routing and capacity](explanation/routing-and-capacity.md) — deterministic scheduling and cumulative budgets.
- [Context and code intelligence](explanation/context-and-code-intelligence.md) — bounded provenance and Serena boundary.
- [Execution runtime](explanation/execution-runtime.md) — HerdR qualification and reusable workspace isolation.
- [Implementation](explanation/execution.md) — candidate, evidence and PR Draft production.
- [Independent review](explanation/review.md) — evidence reuse, correction and structured history.
- [Findings and triage](explanation/findings-and-triage.md) — common intake, holds, batching and obligations.
- [Git integration](explanation/git-integration.md) — branches, PRs, rebasing and qualified merge.
- [Product validation](explanation/validation.md) — versioned targets and normal scheduling.
- [Change control](explanation/change-control.md) — impact, authority and blocked work.
- [Release and closeout](explanation/release-and-closeout.md) — publication and honest fulfillment.
- [Providers and projections](explanation/providers.md) — Broker, reconciliation and optional views.
- [Persistence and durability](explanation/persistence-and-durability.md) — SQLite, published frontier and evidence lifetime.
- [Recovery](explanation/recovery.md) — private-Git bootstrap and empty-host restoration.
- [Upgrades](explanation/upgrades.md) — rollback boundary and forward migration lineage.
- [Experiments and metrics](explanation/experiments-and-metrics.md) — historical outcomes and reviewed learning.
- [Security and resource safety](explanation/security.md) — trust boundaries, secrets and retention.
- [Operator experience](explanation/operator-experience.md) — inspection, onboarding and support documentation.
- [Risks and assumptions](explanation/risks-and-assumptions.md) — treatment and qualification limits.
- [Delivery strategy](explanation/roadmap.md) — product progression, not a scheduled backlog.

## Decisions, rationale and process

- [Architecture Decision Records](adr/README.md) — read the generated status table and relevant amendments first.
- `rationale/` — area files are introduced with code that needs a `# why:` pointer; none are invented before code exists.
- [`process/`](process/work-tracking.md) — the repository-specific `github-workflow` facts (board/label IDs, worktrees, testing commands, live-validation meaning, maintenance, overnight limits, and observed failure modes); it records the workflow's operational setup, not a product delivery plan.
