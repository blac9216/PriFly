# ADR-0001: Adopt the design-docs documentation standard

Status: Accepted
Date: 2026-09-13

## Context

PriFly begins with a large, already-reviewed architecture and no implementation. The documentation framework therefore needs to be established before code so future implementation does not invent a second design record.

## Decision Drivers

- The architecture will be implemented by multiple AI and human contributors.
- Architectural decisions need durable rationale without committing transient planning/spec artifacts.
- Vocabulary and documentation drift must be mechanically detectable.

## Considered Options

### Adopt the design-docs framework

Use MADR ADRs, C4 architecture, root glossary, Diátaxis directories, rationale pointers, manifest-driven audits, and CI checks.

### Use an ad-hoc docs tree

Fewer rules initially, but future agents would have no reliable source for active decisions, document kinds, or vocabulary.

### Commit design specs and plans

Preserves deliberation but creates competing sources of truth and contradicts the desired outcome-focused design record.

## Decision

PriFly adopts the `design-docs` standard and the repository shape in `docs/doc-manifest.md`. Canonical docs record durable design outcomes; plans, specs, interrogation records, research reports, and review transcripts remain outside the repository.

## Consequences

The repository gains a predictable design set, generated ADR index, glossary, Diátaxis organization, rationale-pointer convention, and CI drift checks. Contributors must update canonical docs and ADRs together when architecture changes.
