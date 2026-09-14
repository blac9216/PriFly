# Work tracking — PriFly

PriFly follows the github-workflow shape: Project board → delivery-story milestones →
domain epics → issues. Repository-specific process lives under `docs/process/`.

| Layer | Here |
|---|---|
| Project board | [PriFly #8](https://github.com/users/blac9216/projects/8), owned by `blac9216`; dedicated to `blac9216/PriFly`. |
| Milestones | Delivery stories only; hardening, CI, and tooling may remain milestone-less. |
| Epics | Cohesive multi-issue domains; events live in comments. |
| Issues | Must carry canonical type and priority metadata plus at least one `area:*` conflict lock from [labels.md](labels.md). |

## Board and identity

Project: [PriFly #8](https://github.com/users/blac9216/projects/8) — owner `blac9216`;
automation account `machine-blac9216`.

Board and field IDs are consumed by the workflow scripts. Each ID row has one exact
label and one backtick-quoted value. Refresh the table after recreating a field or
replacing its options:

Refresh these IDs after recreating a field or replacing its options:

```sh
gh project field-list 8 --owner blac9216 --format json
```

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

## Board administration

Keep the standard nine views synchronized with
`.claude/skills/configure-workflow/manifests/project.json`. Board columns use Status;
Roadmap groups by Milestone. Enable Project workflows for auto-add of repository issues
with `is:issue is:open`, auto-add sub-issues, item added → Triage, and item closed → Done.
Leave pull-request status automations and auto-archive disabled. Maintenance returns
reopened issues to Triage.

The `workflow-main` ruleset protects the default branch with pull requests, strict
up-to-date status checks, linear history, and deletion/force-push protection. Its current
required check is `design-docs`.

## Optional configuration

Reviewer identity: none — single account; the review comment plus the merge are the
verdict of record.

Session-log archive: blac9216/workflow-logs

Local deviations from the canonical workflow: none.
