# ADR-0017: Use controlled experiments and reviewed recommendations for policy learning

Status: Proposed
Date: 2026-09-13

## Context

Routing and planning were explicitly designed to improve empirically instead of preserving static model assumptions.

## Decision Drivers

- The owner wants to know whether smaller/stronger models, different harnesses, context tools, and codecs actually improve end-to-end outcomes.
- Naive accepted-only metrics can reward lenient reviewers or rescue-heavy routes.
- Factory policy must not silently rewrite itself from correlations.

## Considered Options

### First-class experiments + deterministic measurement + reviewed recommendation

Replay/shadow/live challenger stages with all-assigned accounting, guardrails, rescue cost, and owner-controlled policy changes.

### Automatic online optimizer

Potentially fast adaptation but can create self-reinforcing bad routing from noisy data.

### Manual intuition only

Simple but throws away the Factory's ability to learn from its own history.

### Vendor benchmarks

Easy comparison but may not represent the user workload, repositories, harnesses, or acceptance process.

## Decision

PriFly records end-to-end outcome metrics and supports bounded experiments with explicit populations, assignment, guardrails, stop conditions, missing-data rules, and Reviewer calibration. AI may interpret signals and propose recommendations; governing policy changes remain reviewed/owner-controlled.

## Consequences

Historical metrics become authoritative durable state. Experiment infrastructure adds complexity, so broad optimization can remain inactive until enough quality data exists. Harness maintenance/security upgrades remain operational updates rather than performance experiments.
