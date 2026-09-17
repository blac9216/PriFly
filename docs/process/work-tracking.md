# Work tracking — PriFly

PriFly adopts the `github-workflow` four-layer shape for milestone 2 (Execution handover:
PriFly builds PriFly): Project board → milestone → domain epic → issue. `docs/process/`
records what differs by repository; the skill's own rules are not restated here.

| Layer | Here |
|---|---|
| Project board | [PriFly #8](https://github.com/users/blac9216/projects/8), owner `blac9216`. |
| Milestone | [Milestone 2 — Execution handover: PriFly builds PriFly](https://github.com/blac9216/PriFly/milestone/2) holds every released DP4 Work Item and tracking epic. |
| Epics | `epic`-labelled issues #42–51, one per domain area named in the DP4 delivery index; children link through native GitHub sub-issues. |
| Issues | Every issue carries a canonical type label, a `priority:*` label, and at least one `area:*` lock from [labels.md](labels.md), and every released DP4 Work Item and domain epic also carries a `size:*` label; Work Items additionally carry the section shape of [`.github/ISSUE_TEMPLATE/work-item.md`](../../.github/ISSUE_TEMPLATE/work-item.md), copied from the released DP4 Work Items (see "Readiness shape" below). |

Canonical delivery authority (Delivery Baseline, owner phase release, Work Item
contracts, envelopes) lives in the design set indexed by
[`docs/doc-manifest.md`](../doc-manifest.md), not in this file or in board state. A
Project card's column, label, or milestone membership is a projection of that authority,
never a substitute for it — see [validation.md](validation.md) and
[ADR-0022](../adr/0022-require-exact-owner-phase-releases.md) (Proposed).

## Board and identity

Project: [PriFly #8](https://github.com/users/blac9216/projects/8) — owner `blac9216`.
Every bootstrap role acts as the owner account `blac9216` (repository role `admin`).
The automation account `machine-blac9216` holds repository role `read`, and that is
intentional ([#125](https://github.com/blac9216/PriFly/issues/125)): no bootstrap role
acts as it, so no bootstrap role needs write access through it, and it is not escalated
to match a generic skill fixture. Both roles per
`gh api repos/blac9216/PriFly/collaborators/<login>/permission`, read live 2026-09-16.
No distinct reviewer account is provisioned, so implementer, reviewer, and merge-verifier
sessions all act through the same active `gh` identity. See "Known identity limitation"
below. Which accounts a given machine has signed in belongs in `*.local.md` guidance.

IDs below were read live from `gh project field-list 8 --owner blac9216 --format json`
and `gh api repos/blac9216/PriFly/rulesets` on 2026-09-16. Each row carries one exact
label and one backtick-quoted value; refresh the whole table after recreating a field or
replacing its options.

| Label | Id | Meaning |
|---|---|---|
| Project | `PVT_kwHOBk6Ni84Bjc-6` | Project node ID |
| Project number | `8` | Project number for `gh project`; owner `blac9216` |
| Status | `PVTSSF_lAHOBk6Ni84Bjc-6zhiRONw` | Status field |
| Status: Triage | `83bf602b` | Newly filed and not sequenced |
| Status: Backlog | `3ce27093` | Planned but not owner-released |
| Status: Ready | `bdddd6f0` | Released and ready to dispatch |
| Status: In progress | `244400ea` | Active implementation or fix work |
| Status: In review | `b877e52d` | Pull request under independent review |
| Status: Done | `c26b90e6` | Closed work |
| Verified | `PVTSSF_lAHOBk6Ni84Bjc-6zhiRSBo` | Live-verification field |
| Verified: n/a | `79443695` | No proof beyond merge checks needed |
| Verified: pending-live | `10f682f6` | Required live proof outstanding |
| Verified: live-verified | `24ed2ee5` | Live proof passed |
| Verified: live-failed | `2438f7dc` | Live proof failed and a bug was filed |
| Claimed by | `PVTF_lAHOBk6Ni84Bjc-6zhiRSBs` | Claim lock or dispatch stamp |

Refresh recipe:

```sh
gh project field-list 8 --owner blac9216 --format json
gh api repos/blac9216/PriFly/rulesets --jq '.[] | {name,id}'
gh api repos/blac9216/PriFly/rulesets/23306001 --jq '{enforcement,bypass_actors,rules:[.rules[].type]}'
gh api graphql -f query='{user(login:"blac9216"){projectV2(number:8){workflows(first:20){nodes{name enabled}}}}}'
```

## Board administration

The nine live views (`gh api graphql` `projectV2.views`, 2026-09-16) are: All issues,
Board, Triage, Ready queue, In flight, Verification ledger, Epics, Milestone-less,
Roadmap. Board columns use Status; Roadmap groups by Milestone.

The Project's seven built-in workflows (`gh api graphql` `projectV2.workflows`, read live
2026-09-16):

| Workflow | Enabled |
|---|---|
| Auto-add to project | yes |
| Auto-add sub-issues to project | yes |
| Item added to project | yes |
| Item closed | yes |
| Auto-close issue | no |
| Pull request linked to issue | no |
| Pull request merged | no |

No workflow moves a reopened item back to Triage. The live list above has seven entries
and none is named "Item reopened". Introspecting the GraphQL schema
(`gh api graphql -f query='{__schema{mutationType{fields{name}}}}' --jq '.data.__schema.mutationType.fields[].name' | grep -i workflow`,
run 2026-09-16) returns only `deleteProjectV2Workflow`: there is no mutation to create,
update, or enable a Project workflow. Whether the Project's Workflows settings UI offers
a reopen workflow is UNKNOWN; it has not been checked. A reopened issue still showing
Done is returned to Triage by the `github-workflow` skill's maintenance pass
(`references/maintenance.md` § 5, "State audit"). See
[#125](https://github.com/blac9216/PriFly/issues/125). The API also does not expose a
workflow's target Status or auto-add filter. Before relying on "item added → Triage" or
"item closed → Done", confirm the target in the Project's Workflows settings; the
refresh recipe above shows only names and enabled state.

The `workflow-main` branch ruleset (`gh api repos/blac9216/PriFly/rulesets/23306001`,
read live 2026-09-16) is `active` on the default branch with: required status check
`design-docs` (strict/up-to-date), linear history, no deletion, no non-fast-forward
pushes, and a pull-request rule with `required_approving_review_count: 0`. Its
`bypass_actors` list is `RepositoryRole` id 5 (Admin) with `bypass_mode: always`, so an
admin account can bypass every one of those rules. See "Known identity limitation" below
for what these values mean in practice.

## Roles and authority

- **Bootstrap Implementer** owns one issue's delivery in its own worktree and never
  reviews or merges its own PR.
- **Bootstrap Reviewer** (`github-pr-review`) is a fresh-context, producer-independent
  role: it reviews in its own review worktree ([worktrees.md](worktrees.md)) and, on
  acceptance, merges the bootstrap PR. It never authors the candidate it reviews.
- **Factory's eventual product Provider Broker** is a distinct future authority that
  alone merges *product* candidates once Factory exists; this document grants it
  nothing — it is named here only so a bootstrap merge is never mistaken for that later
  authority.
- **Owner** holds every exact phase release (architecture → delivery planning →
  execution) and consequential no-action/risk-acceptance decision; a bootstrap
  Reviewer's acceptance is never itself an owner release.

These are separate authorities that must not collapse into "whoever is available
merges." See "Known identity limitation" below for the one place GitHub's own
enforcement currently falls short of this separation.

## Known identity limitation

`author ≠ merger` is a PriFly workflow rule (an Implementer never reviews or merges its
own PR — [DP4 operating contract](https://github.com/blac9216/PriFly/issues/38#issuecomment-5702104540):
"they never self-review or author-merge"; [ADR-0009](../adr/0009-require-independent-adversarial-review.md)),
but GitHub does **not** enforce it by identity. Two live facts show the gap:

- the `workflow-main` ruleset requires zero approving reviews, and every bootstrap
  role acts as the same account, `blac9216`;
- the ruleset's bypass actor is the Admin repository role with `bypass_mode: always`, and
  the owner account `blac9216` is an admin. That account can merge or push past the
  required `design-docs` check, linear history, and non-fast-forward rules, whoever
  authored the change.

Separation is enforced today only by **workflow role separation and the recorded
review/merge history**: distinct dispatch prompts, a fresh-context Reviewer round, and
the PR/issue comment trail this process produces. It is not a GitHub-verified distinct
approver identity, and a passing required check is not proof of independent review.
This is a known limitation, not a guarantee. Provisioning a distinct reviewer identity is
tracked in [#123](https://github.com/blac9216/PriFly/issues/123), which needs an
owner-provisioned second GitHub identity.

## Readiness shape

`github-workflow`'s readiness gate requires template-shaped bodies, provable acceptance
criteria, and type plus `area:*` labels. In this repository that shape is checked
against the committed templates, so the headings live in one place:

- a Work Item body carries every `## ` heading of
  [`.github/ISSUE_TEMPLATE/work-item.md`](../../.github/ISSUE_TEMPLATE/work-item.md)
  verbatim, and at least one acceptance-criteria checkbox (`- [ ]` or `- [x]`);
- the issue carries one type label from the Type row of [labels.md](labels.md) and at
  least one label from its `area:*` table;
- a PR body carries every `## ` heading of
  [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md) and either
  a `Closes #<N>` line or the partial-delivery form below.

A PR that deliberately delivers only part of an issue uses the partial-delivery form
instead of `Closes #<N>`. The form is fixed by the
[planning ruling on #157](https://github.com/blac9216/PriFly/issues/157#issuecomment-5705920335):
the body carries a `Refs #<N>` line,
directly after it a `Remainder: <text>` line and then a `Closing issue: #<M>` line,
where `<text>` is non-empty and names what this PR does not deliver, and `#<M>` (M ≠ N)
names the issue whose PR will close #<N>. For example (illustrative numbers):

```text
Refs #12
Remainder: the retry path and its tests
Closing issue: #34
```

No closing keyword comes directly before an issue reference in those two lines.
Each of the two lines starts with its label exactly as written above — `Remainder:` or
`Closing issue:`, in that capitalisation, then a space — and the `Closing issue` line
holds only `#<M>` after it, so `Remainder:x`, `remainder: x` and
`Closing issue: #34 and more` are not the form.
Nothing else about their wording or position is part of the form. The
body then carries no closing keyword anywhere — not on its own line and not inside
prose, since GitHub treats a phrase like "closes #N" in prose as a closing reference
the same as a dedicated line — for the referenced issue #<N>. The gate accepts this
form in place of `Closes #<N>`, per the `github-workflow` skill's own convention
(`references/templates/implementer.md`: "`Closes #<N>` on its own line in the PR
**body** (or `Refs` + exact remainder)"). [PR #134](https://github.com/blac9216/PriFly/pull/134)'s
merged body predates this form and is historical; it is not rewritten (same ruling).

Each missing element is reported by name, and the gate stops and asks. Nothing missing is
passed silently. The shape is necessary, not sufficient: owner release, dependency
conditions, and live predicates still gate dispatch ([validation.md](validation.md)).

[`scripts/process/check-readiness.sh`](../../scripts/process/check-readiness.sh) is a
retained, deterministic checker for the Work Item **issue-body** part of this shape
([#126](https://github.com/blac9216/PriFly/issues/126)): every `## ` heading of
`work-item.md`, read from the committed template rather than hard-coded; an
acceptance-criteria checkbox inside the body's Acceptance Criteria section; and one type
plus one `area:*` label, read from `labels.md`. It exits 2 on a usage error or a missing,
unreadable or non-UTF-8 body. It exits 3 if a doc or template file it reads is missing,
unreadable or not UTF-8, if the template has no `## ` headings, or if the rule text above
or the `labels.md` rows it relies on have been reworded. Run
`bash scripts/process/check-readiness.sh --root . --body <file|-> --labels a,b,c`, and
`bash scripts/process/test-check-readiness.sh` to prove the checker still detects those
regressions. With `--mode pr --repo blac9216/PriFly` instead of `--labels` (passing both
is a usage error, and so is `--repo` without `--mode pr`) it checks a **PR body**: every
`## ` heading of `PULL_REQUEST_TEMPLATE.md`, a `Closes #<N>` or `Refs #<N>` line, for
each `Refs #<N>` no closing keyword for #<N> in the raw body, and the `Remainder:` and
`Closing issue:` lines of the form above, each part reported by name. A part that
depends on a failed line is skipped, and the failed line's message says so: the
Remainder text and the Closing issue line after a missing `Remainder:` line, and
M ≠ N after a missing `Closing issue:` line. It tests the lines' form only — labels,
adjacency, non-empty text, M ≠ N and no keyword — not whether the Remainder text
really names what the PR does not deliver, or whether `#<M>`'s PR really closes `#<N>`.
The keywords, their colon and uppercase forms, and the `#<N>` and
`<owner>/<repository>#<N>` references are the ones GitHub's
[Linking a pull request to an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue)
lists. That page does not say whether code or HTML comments are parsed, or whether a
colon with no following space (`fixes:#57`) links; keywords in all of those are flagged
too, as unverified limits. The self-test `test-check-readiness.sh` runs `check-readiness.sh`,
and it runs in CI as the "Readiness-shape checker regression tests" step of the required
`design-docs` job in [`docs-checks.yml`](../../.github/workflows/docs-checks.yml). This
paragraph names a checker, not a new rule.

## Optional configuration

Session-log archive: blac9216/workflow-logs

Local deviations from the canonical `github-workflow` shape: none recorded.
