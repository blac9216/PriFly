# ADR-0027: Track common triage and versioned product validation

Status: Proposed
Date: 2026-09-16

## Context

PRD Candidate 2.1 §§16, 18 and 20 separates current correction, backlog treatment, product proof and scope closeout. It explicitly rejects a private validation fix-wave scheduler and closing a scope by filing its unfinished obligations elsewhere. This records the owner's selected lifecycle from issue #36.

## Decision Drivers

- Merged work must not be reported as demonstrated product behavior.
- Small findings can wait or batch without becoming invisible.
- Closeout must account for actual outcomes and surviving blockers.

## Considered Options

### Common triage, versioned targets and normal work scheduling

Selected by the PRD. Reuses one governed pipeline while retaining product-proof and scope obligations.

### Private validator repair/fix-wave loop

Can immediately retry failures but duplicates planning/scheduling and can bypass normal authority.

### Treat merged PRs and filed follow-ups as completion

Cheap bookkeeping but does not establish intended use or fulfilled scope.

These alternatives compare the supplied product direction with the prior documented mechanisms; they do not reconstruct an unrecorded owner interrogation.

## Decision

Finding producers propose only CURRENT_CORRECTION, FOLLOW_UP or PLANNING_CHANGE. Current corrections complete the existing candidate loop. Other findings enter common semantic Triage with scope, evidence, history and reconsideration conditions. Holding, batching and planning are nonterminal. Validation uses exact integrated target revisions and representative supported scenarios without improvised workarounds. Product defects enter the normal planning/implementation/review/PR pipeline with explicit precedence. Failed targets return to PENDING_VALIDATION only after all known blocking fixes resolve/integrate; the common scheduler decides the next run. Closeout accounts for every scoped finding and surviving dependency, required validation, release, documentation and risk. Cancellation or authorized scope reduction is distinct from successful completion.

## Consequences

Target, Run, Work Item and Finding states remain separate. Release and closeout require evidence beyond merge. Batch sizes, urgency weights and aging thresholds remain selected policy parameters, not invented constants.

Canonical contracts: [documentation index](../README.md) and [source traceability](../reference/traceability.md). Proposed here for independent review; no implementation certification is implied.
