# ADR-0024: Reuse sufficient evidence within independent review

Status: Proposed
Amends: 0009, 0013
Date: 2026-09-16

## Context

The prior acceptance design required independently executed verification for every factual execution claim. PRD Candidate 2.1 §§14–15 explicitly admits attributable Implementer evidence when the independent Reviewer finds it sufficient, and lets that Reviewer gather further evidence in the same review. This amends the blanket independent-execution interpretation of ADR-0009 and the independent-observation requirement of ADR-0013; their review independence, immutable acceptance and durability requirements remain. Owner direction is issue #36.

## Decision Drivers

- Avoid unconditional duplicate suites and recursive reviewers.
- Preserve exact tested-subject/environment provenance and declared independence requirements.
- A producer must never approve its own consequential artifact.

## Considered Options

### Independent Reviewer assesses supplied evidence and fills justified gaps

Selected by the PRD. Preserves independent judgment and spends test effort on required or uncertain properties.

### Mandatory separate Verification Runner before every acceptance

The former ADR-0013 approach simplifies evidence origin but duplicates adequate checks and can introduce unnecessary jobs.

These alternatives compare the supplied product direction with the prior documented mechanisms; they do not reconstruct an unrecorded owner interrogation.

## Decision

A fresh Reviewer evaluates an exact candidate independently of its producer's private reasoning, using the pinned rubric, conformance contract, evidence and prior finding history. It may accept credible sufficient Implementer/CI evidence or run more checks in the same review. Project/risk-specific independent execution remains mandatory when predeclared. The Reviewer records actual evidence origin, reuse/rerun reasons and limitations and cannot edit then approve the shipped candidate. A changed artifact needs fresh review. Acceptance Certificates bind exact candidate, baselines, evaluations, review, evidence and policy; required external evidence and recovery-root pins are durable before acceptance publication.

## Consequences

A test run does not automatically start a new reviewer. Current corrections use fresh Implementer attempts and return to fresh review with unresolved findings intact. Evidence sufficiency requires semantic judgment and auditable provenance; a green command or producer assertion alone is insufficient.

Canonical contracts: [documentation index](../README.md) and [source traceability](../reference/traceability.md). Proposed here for independent review; no implementation certification is implied.
