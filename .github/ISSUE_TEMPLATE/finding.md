---
name: Bug / Finding
about: A found defect, deferred concern, or documentation gap
title: ""
labels: ""
---

<!--
For a Finding spawned by other work in progress, keep the "Spawned by" and "Unit" lines
— they are how a deferred item stays attributable and locatable. See
docs/process/labels.md for the closed severity/concern label sets and the area:* set.
-->

## What happened / what is missing
Describe the defect or gap. Include the exact failing scenario, not just a symptom.

## Expected vs actual
What should be true, and what is observed instead.

## Evidence
Exact subject (commit/PR/file/line), command(s) run, and result. Link a permalink for
any claim about another issue or PR's outcome.

## Severity / disposition
`severity:critical` | `severity:major` | `severity:minor`, and whether this is a
current-correction item or a deferred follow-up (`deferred` + `concern:*` or
`documentation`).

<!-- For a deferred item filed by an agent during other work: -->
Spawned by #<issue-or-pr>
Unit: <repo-relative file path, dir path ending `/`, or `area:*` label>
