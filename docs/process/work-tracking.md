# Work tracking — PriFly

PriFly adopts the `github-workflow` four-layer shape for milestone 2 (Execution handover:
PriFly builds PriFly): Project board → milestone → domain epic → issue. `docs/process/`
records what differs by repository; the skill's own rules are not restated here.

| Layer | Here |
|---|---|
| Project board | [PriFly #8](https://github.com/users/blac9216/projects/8), owner `blac9216`. |
| Milestone | [Milestone 2 — Execution handover: PriFly builds PriFly](https://github.com/blac9216/PriFly/milestone/2) holds every released DP4 Work Item and tracking epic. |
| Epics | `epic`-labelled issues #42–51, one per domain area named in the DP4 delivery index; children link through native GitHub sub-issues. |
| Issues | Every issue carries a canonical type/priority/size label plus at least one `area:*` lock from [labels.md](labels.md); Work Items additionally carry the DP4 Goal/Required-Outcomes/Constraints/Verification shape from the governing design (`docs/explanation/delivery-planning.md`). |

Canonical delivery authority (Delivery Baseline, owner phase release, Work Item
contracts, envelopes) lives in the design set indexed by
[`docs/doc-manifest.md`](../doc-manifest.md), not in this file or in board state. A
Project card's column, label, or milestone membership is a projection of that authority,
never a substitute for it — see [validation.md](validation.md) and
[ADR-0022](../adr/0022-require-exact-owner-phase-releases.md) (Proposed).

## Board and identity

Project: [PriFly #8](https://github.com/users/blac9216/projects/8) — owner `blac9216`.
Two GitHub accounts are configured on this host: `blac9216` (owner) and
`machine-blac9216` (automation); both currently carry `project` OAuth scope
(`gh auth status`). No distinct reviewer account/token is provisioned in the secrets
mechanism today, so every bootstrap Worker session — implementer, reviewer, and
merge-verifier alike — acts through the one currently-active `gh` identity. See
"Known identity limitation" below.

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
```

## Board administration

The nine live views (`gh api graphql` `projectV2.views`, 2026-09-16) are: All issues,
Board, Triage, Ready queue, In flight, Verification ledger, Epics, Milestone-less,
Roadmap. Board columns use Status; Roadmap groups by Milestone. Project workflow
automations observed: item added → Triage, item closed → Done; a reopened issue returns
to Triage. Pull-request status automations and auto-archive are disabled.

The `workflow-main` branch ruleset (`gh api repos/blac9216/PriFly/rulesets/23306001`,
read live 2026-09-16) protects `main` with: required status check `design-docs`
(strict/up-to-date), linear history, no deletion, no non-fast-forward pushes, and
`required_approving_review_count: 0` — see "Known identity limitation" below for what
that number means in practice.

## Roles and authority

- **Bootstrap Implementer** owns one issue's delivery in its own worktree and never
  reviews or merges its own PR.
- **Bootstrap Reviewer** (`github-pr-review`) is a fresh-context, producer-independent
  role: it reviews and, on acceptance, merges the bootstrap PR. It never authors the
  candidate it reviews.
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
own PR — [D3 operating contract](https://github.com/blac9216/PriFly/issues/38#issuecomment-5702104540);
[ADR-0009](../adr/0009-require-independent-adversarial-review.md)), but it is **not**
currently enforced by GitHub branch-protection identity: the `workflow-main` ruleset
requires zero approving reviews, and every bootstrap Worker session observed on this
host authenticates as one of the same two accounts. Separation is enforced today by
**workflow role separation and the recorded review/merge history** (distinct dispatch
prompts, a fresh-context Reviewer round, and the PR/issue comment trail this process
produces), not by a GitHub-verified distinct approver identity. This is recorded as a
known limitation, not a guarantee; provisioning a genuinely distinct reviewer account
and token is optional future configuration (`github-workflow`'s
`reviewer-account.md`), not yet exercised in this repository.

## Optional configuration

Session-log archive: `blac9216/workflow-logs`

Local deviations from the canonical `github-workflow` shape: none recorded.
