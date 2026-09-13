# ADR-0002: Keep orchestration deterministic and AI work bounded

Status: Accepted
Date: 2026-09-13

## Context

The existing skill-based workflow encoded large amounts of orchestration policy in model-readable prose. PriFly is intended to move repeatable workflow mechanics into deterministic software.

## Decision Drivers

- Long-running workflow must survive loss of conversational context.
- State transitions, authority, recovery, and external side effects must be testable.
- AI is valuable for judgment and coding but unreliable as hidden workflow state.

## Considered Options

### Deterministic Factory with bounded Workers

Software owns orchestration and invokes specialized Workers only for cognitive jobs.

### LLM orchestrator

A central model decides sequencing and state. Simpler to prototype, but workflow correctness and recovery depend on model context.

### Human-driven agent sessions

Keep orchestration manual. Lower engineering cost but fails the autonomy goal.

## Decision

Factory is the sole deterministic workflow authority. Workers perform bounded jobs and return typed results; Workers do not orchestrate Factory Workers.

## Consequences

The architecture needs explicit state machines, typed Commands, durable state, and scheduling logic. AI prompts can be smaller and restartable. Factory complexity grows, but cognitive jobs become easier to reason about and measure.
