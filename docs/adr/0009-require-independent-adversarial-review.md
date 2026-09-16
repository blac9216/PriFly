# ADR-0009: Require independent adversarial review for consequential AI artifacts

Status: Accepted
Amended-by: 0024
Date: 2026-09-13

## Context

Adversarial review was identified as a cornerstone for planning, architecture, implementation, fixes, and delivered behavior.

## Decision Drivers

- AI producers are poor judges of their own omissions.
- Review must challenge semantics, not merely rerun the producer with the same hidden context.
- Quality is more important than saving a model call on consequential transitions.

## Considered Options

### Fresh independent review with risk-scaled diversity

A different Worker identity/context attacks the exact artifact and objective evidence before promotion.

### Producer self-review

Cheap but highly correlated with the original mistakes.

### Human review of every artifact

Strong authority but defeats the autonomous-operation goal.

### Always use a different provider/model

Maximizes diversity but may reduce quality if the alternate reviewer is empirically worse.

## Decision

No consequential AI-produced artifact may promote itself. Review uses fresh context and an immutable review subject; independent evidence is used where factual execution claims matter. Model/harness diversity is preferred as risk rises when data supports it.

## Consequences

PriFly spends additional capacity on review and validation. Reviewer quality itself must be measured. Review findings route back through Factory rather than allowing reviewers to mutate the artifact they judge.
