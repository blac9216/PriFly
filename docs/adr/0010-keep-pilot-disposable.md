# ADR-0010: Keep Pilot disposable and separate owner confirmation

Status: Proposed
Date: 2026-09-13

## Context

The owner wants natural-language exploration, status, and control while making loss of any chat session harmless.

## Decision Drivers

- Conversational sessions are lossy and replaceable.
- Factory must continue without a Pilot.
- Natural-language interpretation must not silently become owner authority.

## Considered Options

### Disposable Pilot + durable Attention + owner-only consequential confirmation

Pilot explains/drafts/actions but Factory owns state and consequential confirmation uses a separate owner capability.

### LLM Pilot as orchestrator

Makes conversation convenient but reintroduces hidden workflow state and recovery dependence.

### GUI-only control plane

Strong explicit actions but loses the natural-language interface the owner wants.

### Pilot confirmation using same model credential

Revision-bound but still allows the model to mint the human approval event.

## Decision

Pilot is a disposable client of Factory. Owner attention is durable Factory state. Consequential Owner Actions are immutable/revision-bound and require a separate owner-confirmation capability that Pilot and Worker credentials cannot invoke.

## Consequences

A new Pilot can orient from Factory state and continue the conversation without operational loss. Consequential approvals add a small explicit confirmation step; routine reversible commands and standing delegations remain conversational.
