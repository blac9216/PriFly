# ADR-0028: Project Initiatives through configurable provider views

Status: Proposed
Amends: 0007
Date: 2026-09-16

## Context

ADR-0007 established Factory authority over external projections but did not select the new configurable planning and review-history mappings. PRD Candidate 2.1 §§7, 11, 15 and 22 maps Initiatives to GitHub milestones and makes provider representations independently optional. This extends that projection decision under the owner's issue #36 direction.

## Decision Drivers

- Canonical work must survive optional or lagging provider views.
- An Initiative can span repositories and therefore several repository-scoped milestones.
- Review history must remain structured and inspectable across corrections.

## Considered Options

### Versioned per-Project projection profile with retained mappings

Selected by the PRD. Provides chosen visibility while preserving canonical hierarchy and authority.

### Mandatory old skill hierarchy/board and comment-derived workflow

Reuses an existing UI pattern but makes optional presentation a workflow prerequisite and can lose semantic history.

These alternatives compare the supplied product direction with the prior documented mechanisms; they do not reconstruct an unrecorded owner interrogation.

## Decision

GitHub milestones represent Initiatives, never a separate canonical tier or an Epic. A versioned Provider Projection Profile independently enables/maps project views, Initiative milestones, Epic/Work Item issues, fields/labels, relationships and review destinations. Factory compiles canonical proposed planning within owner-released delivery planning; provider object existence or status never releases execution. Structured review/correction/approval/integration entries are durable and ordered before rendering: full PR exchange and issue summaries by default, with validated alternatives. Current-state summaries may coalesce; historical meaning may not. Disabling a representation retains mappings/history and does not delete external objects absent explicit authority. Required PR/merge controls remain separate from optional views.

## Consequences

Multi-repository mapping is one-to-many and requires repository/representation identity. Publication ambiguity still follows SEND_ARMED profiles. Re-enabling reconciles retained mappings; external comments are attributed input, not approvals or canonical round counts.

Canonical contracts: [documentation index](../README.md) and [source traceability](../reference/traceability.md). Proposed here for independent review; no implementation certification is implied.
