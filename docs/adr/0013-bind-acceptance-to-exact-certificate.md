# ADR-0013: Bind acceptance to exact certificates and independent evidence

Status: Proposed
Date: 2026-09-13

## Context

Independent review alone is insufficient if the reviewed evidence is producer-controlled or points at a different code/integration state.

## Decision Drivers

- “Tests passed” from the Implementer is not independent evidence.
- Stale attempts, baselines, target bases, and verification plans must not remain merge-eligible.
- Accepted results must remain reconstructible from supported recovery roots.

## Considered Options

### Acceptance Certificate + Evidence Manifest + independent Verification Runner

Bind exact subject/evidence/policy and upload required evidence before acceptance.

### Review status on Work Item

Simple but approval can outlive the exact code or target it was based on.

### Trust producer test reports

Cheap but producer can accidentally or deliberately weaken the evidence oracle.

### Retain every raw prompt/log forever

Maximal replay material but excessive storage/privacy burden and still not equivalent to objective evidence.

## Decision

PriFly accepts exact immutable Acceptance Certificates. Required evidence is independently observed, uploaded and verified before acceptance release, and protected through Acceptance Evidence and Recovery Root Manifests for as long as supported recovery roots require it.

## Consequences

Acceptance invalidates aggressively when relevant inputs change. Storage retention needs dependency pins. Optional diagnostics/raw context may expire and make runs non-replayable without invalidating the compact acceptance record.
