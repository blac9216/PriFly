# ADR-0008: Baseline complete planning before decomposition

Status: Proposed
Date: 2026-09-13

## Context

PriFly is intended to operate autonomously for long stretches, making up-front planning quality more important than in an interactive coding-agent loop.

## Decision Drivers

- Planning errors multiply after decomposition and concurrent execution begin.
- The owner wants the greatest trajectory control before work fans out.
- Planning knowledge must be traceable and changeable without restarting everything.

## Considered Options

### Typed Planning Record + strict gates + immutable baselines

Planning objects form a graph, blocking gaps must be zero, and release creates versioned baselines.

### Large Planner document

Easy to read initially but difficult to trace, invalidate selectively, or mechanically gate.

### Decompose early and refine during implementation

Fast start but knowingly lets ambiguity multiply into issues, dependencies, and code.

### Percentage threshold gate

Useful progress signal, but a high aggregate can hide one catastrophic unresolved concern.

## Decision

Factory owns a typed Planning Record and strict Design Completeness and Delivery Readiness gates. Percentages are diagnostic only. Released planning state becomes an immutable baseline; semantic changes use Change Requests and explicit impact/revalidation.

## Consequences

Planning becomes more structured and may take longer before implementation starts. In exchange, PriFly can query missing coverage, trace requirements through verification, revalidate only affected work where impact is proven, and preserve design history.
