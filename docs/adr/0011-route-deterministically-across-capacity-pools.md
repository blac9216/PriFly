# ADR-0011: Route Workers deterministically across versioned Routes and Capacity Pools

Status: Proposed
Date: 2026-09-13

## Context

PriFly is explicitly multi-harness from day one and must learn whether different routes are actually better for different jobs.

## Decision Drivers

- Harness and model combination materially changes quality, tools, costs, and limits.
- Subscription/API/local capacity must be protected for high-value work.
- Routing decisions need to be explainable and experimentally comparable.

## Considered Options

### Versioned deterministic routing policy

Role/task/risk/capabilities select eligible Routes; policy chooses champions/fallbacks and experiments.

### AI router

Flexible but lets another model silently control quality/cost policy and makes decisions harder to reproduce.

### Single fixed harness/model

Simple but wastes available capacity/diversity and prevents evidence-driven improvement.

### Pure cheapest-route selection

Optimizes cost but can violate minimum quality requirements.

## Decision

PriFly uses immutable versioned Routes, contextual capability tiers, Capacity Pools, deterministic Routing Policies, and controlled champion/challenger experiments. Quality eligibility is evaluated before capacity/cost optimization.

## Consequences

Routing logic and metrics become a significant subsystem. Unknown quota remains unknown, so capacity pressure can be qualitative. Policy evolution requires reviewed recommendation/owner approval rather than automatic mutation.
