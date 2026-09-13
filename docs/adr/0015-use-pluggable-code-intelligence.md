# ADR-0015: Use pluggable code intelligence with exact provenance

Status: Proposed
Date: 2026-09-13

## Context

The architecture initially considered Graft and Serena as fixed sides of the context system, but current tool/language differences argued for a provider boundary.

## Decision Drivers

- Repositories/languages vary and no single analysis tool covers every stack.
- Planning needs stable baseline intelligence while Workers need mutable worktree intelligence.
- Code-intelligence output must never silently become canonical project knowledge.

## Considered Options

### Git substrate + Code Intelligence Provider abstraction

Git facts always work; optional Graft/Serena-like providers add richer analysis with provenance and uncertainty.

### Hardwire Graft as Factory context engine

Strong structural mapping where supported, but language coverage and future tool choice would shape the architecture.

### Hardwire Serena everywhere

Strong semantic Worker navigation, but broad planning/project mapping and tool lifecycle differ from Worker needs.

### Give Workers the whole repository without compilation

Simple but repeats discovery and burns context while discarding planning knowledge.

## Decision

Git is the universal code-intelligence substrate. Richer tools sit behind replaceable providers. Shared Factory analysis is commit-addressed; Worker analysis is worktree/attempt-scoped. Important results carry exact provenance, coverage, uncertainty, and freshness.

## Consequences

PriFly can experiment with context tools rather than canonizing them. Missing impact edges cannot prove non-impact, and derived indexes remain disposable caches. Workers receive bounded context and discover detail progressively.
