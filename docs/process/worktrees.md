# Worktrees

Use one Git worktree per active implementation branch. The main checkout
(`/home/justin.black/git/Personal/PriFly` on this host) is reserved for orchestration
and read-only inspection — no implementer, fix, reviewer, merge-verifier, or rebase
session commits or checks out there.

## Root and naming

Worktrees live in a sibling directory outside the main checkout — `/tmp/prifly-worktrees/`
on this host; the exact machine path belongs in `*.local.md` guidance, never here.

- issue implementation: `issue-<number>` (e.g. `issue-56`), branch `<number>-<slug>`;
- review and fix work reuse the existing issue worktree — the same Implementation
  Workspace, per its exclusive Workspace Lease — rather than a second checkout, unless
  the canonical workflow requires an isolated Review Workspace for a specific check;
- remove the worktree and local branch after merge once no round/relay depends on them.

Before parallel dispatch, compare the candidate issues' `area:*` labels against
[labels.md](labels.md). Serialize intersecting areas unless concrete file scopes
establish that the changes cannot collide (see also [maintenance.md](maintenance.md)).

## Scratch root

Every agent's scratch, evidence, and log files live under the session's own scratch
root (`<scratch>` in dispatch prompts and `agent-rules.md`), never inside a worktree or
`/tmp` directly. Each agent uses a uniquely-named subdirectory of that root, keyed the
way evidence logs already are (`<scratch>/issue<N>-<short-tag>/`,
`<scratch>/evidence/issue<N>/`), so a second agent picking an obvious name cannot
overwrite another agent's working files. The scratch root itself is machine-local and
recorded in `*.local.md` guidance, not in this committed file.
