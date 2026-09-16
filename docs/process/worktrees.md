# Worktrees

Use one Git worktree per role, never a shared checkout. The main checkout is reserved for
orchestration and read-only inspection: no implementer, fix, rebase, reviewer, or
merge-verifier session commits or checks out a branch there.

## Root and naming

Worktrees live in one root outside the main checkout, written generically here as
`${TMPDIR:-/tmp}/prifly-worktrees`. The exact path on a given machine, if it differs,
belongs in untracked `*.local.md` guidance and never in this committed file.

| Role | Worktree | Branch |
|---|---|---|
| Implementer | `issue-<N>` (e.g. `issue-56`), created with `git worktree add <root>/issue-<N> -b <N>-<slug>` | `<N>-<slug>` |
| Fix-round and rebase agents | the existing author worktree `issue-<N>`, so the branch continues | the PR's head branch |
| Reviewer (`github-pr-review` Step 2) | its own `review-pr<P>`, created with `git worktree add <root>/review-pr<P> origin/<head branch>` and removed when the review ends | detached at the PR head, never committed except under the reviewer-applied note gate |
| Merge-verifier | its own review worktree, named by its dispatch | detached at the PR head |

A reviewer or merge-verifier never works in, commits to, rebases, or pushes from the
author worktree. That separation of worktrees is part of the Implementer/Reviewer role
separation recorded in [work-tracking.md](work-tracking.md).

Keep the author worktree until the PR merges, because fix rounds need it. After merge,
remove it and delete the local branch once no round or relay still depends on them.

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
