---
name: Work Item
about: A DP4-shaped executable Work Item (SLICE or ENABLER)
title: ""
labels: ""
---

<!--
Shape per docs/explanation/delivery-planning.md and the DP4 operating contract
(https://github.com/blac9216/PriFly/issues/38#issuecomment-5702104540). Every section
below is required; "Write `x.go`" is an implementation action, not a Required Outcome —
state the observable condition instead.
-->

## Goal
Purpose or desired outcome that justifies this work.

## Required Outcomes
Observable conditions this Work Item must make true.

## Constraints
Non-violation boundaries restricting acceptable solutions — what this must NOT change.

## Verification
Method(s) that establish the Required Outcomes with objective evidence: exact
inputs/fixtures, expected observable result, and the negative/adverse cases exercised.

## Dependencies
Native `blocked-by` plus the exact release condition each named dependency must satisfy
(e.g. "PR integrated at target revision", "Validation Target passed") — see
docs/process/validation.md; never a bare `done` flag.

## Estimate
Size (`size:s`/`size:m`/`size:l`), active-hour range, basis/comparables, and confidence —
see docs/explanation/delivery-planning.md.

## Verified expectation
`n/a` | `pending-live` — see docs/process/validation.md.

## Home
Milestone, parent epic (if any), and `area:*` label(s) — see docs/process/labels.md.
