<!--
Filled per docs/process/testing.md and the github-workflow skill's pr-body template.
Closing keywords go on their own line, above this comment block is fine, but never
buried inside prose — GitHub only auto-closes from keywords in the PR body.
-->
Closes #<issue>
<!-- Closes #<issue2>   one line per issue for a multi-issue PR -->
<!-- Part of #<epic>    if this PR is part of a tracked epic -->

## Summary
What changed and why.

## Risk
What could regress, what areas are touched indirectly, blast radius. Be honest —
"no risk" is rarely true.

## Rollback
How to revert if this introduces a regression. Usually `git revert <sha>`, but flag any
state migrations, schema changes, or destructive operations that complicate a clean
revert.

## Suggested Test Steps
Concrete, change-specific steps a fresh reviewer can follow to validate this PR, mapped
1:1 to the issue's Acceptance Criteria. Each step states its expected result and is
reproducible against the PR's own content — never against a moving `origin/main` (a
three-dot `git diff origin/main...HEAD` is fine; a two-dot diff or an
`--is-ancestor` check against `origin/main` is not, per the pr-body template's rule).

1. <step> — expected: <result>

## Verified expectation
`n/a` | `pending-live` — see docs/process/validation.md for what each value means here.
Copied from the issue; the reviewer sets the board's `Verified` field from this line at
merge.

<!-- Any claim about another PR's or issue's outcome carries a permalink to the comment
that establishes it — see the pr-body template's "Claims about another PR or issue". -->
