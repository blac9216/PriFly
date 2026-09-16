---
name: Work Item
about: A DP4-shaped executable Work Item (SLICE or justified ENABLER)
title: ""
labels: ""
---

<!--
Section shape copied from the released DP4 Work Items (for example #56 and #57), under
the DP4 operating contract
(https://github.com/blac9216/PriFly/issues/38#issuecomment-5702104540) and the D3 C1
Work Item fields (https://github.com/blac9216/PriFly/issues/38#issuecomment-5701520946).
Keep every "## " heading exactly as written: the readiness shape in
docs/process/work-tracking.md compares an issue body's headings against this file's.
At filing, apply one type label and at least one area:* label from
docs/process/labels.md, plus a size:* label.
-->

## Summary / Goal
The purpose or desired outcome that justifies this work, in one or two sentences.

## Motivation / Current Behavior
Current state at the named source baseline. Classification: **SLICE** (behavior testable
at its stated boundary) or **ENABLER** (justified shared prerequisite). For an ENABLER,
name its direct consumers and the downstream consuming SLICEs (`#<issue> (<ID>)`).

## Proposed Changes / Required Outcomes
- The observable conditions this Work Item must make true. State outcomes, not
  implementation actions.

## Constraints and governing contracts
The exact governing contract, profile and verification clauses (as permalinks) and the
boundaries this work must not cross.

Implementation envelope: the named outcomes in the listed component areas, adjacent
focused fixtures, and directly affected canonical interface/runbook sections. This field
grants edit scope, and it is separate from the predicted footprint below.

## Affected Files / predicted footprint
- `path/or/dir/`: why it is predicted to change.

Review bound and re-scope trigger. Collision hints: the exclusive collision keys and
shared-file edits that serialize this item against others.

## Acceptance Criteria — merge-time evidence
- [ ] A criterion a reviewer can prove at merge (command, test, observable output).
- [ ] A producer-independent reviewer can reproduce the specified local proof, with
      exact subject/tool/fixture identities and negative controls retained.

## Verification / suggested test steps
The method for each Required Outcome: inputs and fixtures, expected observable result,
and a negative control for each stated denial or uncertainty behavior. PR Suggested Test
Steps map 1:1 to the acceptance boxes above.

## Dependencies / consumes / produces
- `#<issue> (<ID>)`: the exact release condition this edge requires (for example "PR
  integrated with independent acceptance"), never a bare `done` flag.

Live-run/admission predicates (separate from PR authoring): the named live PASS records
a run requires, or "none beyond shared relevant-profile gates".

Consumes: the contracts and accepted artifacts used. Produces: the artifact delivered.
Consumers: `#<issue> (<ID>)`.

## Risks / Considerations
The applicable risk records, and the stop-and-replan triggers.

## Home and responsibility
Part of `#<epic>`; milestone `<milestone>`. Local stable ID `<ID>`. Who owns delivery,
acceptance, external prerequisites and live evidence.

## Estimate
Size (`size:s`/`size:m`/`size:l`), active-hour estimate and range with its basis and
confidence, and the released execution envelope (attempts, hours).

## Verified expectation / validation relationship
`n/a` or `pending-live`, and the live profile or Validation Target that owns any
runtime proof. See docs/process/validation.md.
