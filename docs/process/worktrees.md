# Worktrees

Use one Git worktree per active implementation branch. The main checkout is reserved for
orchestration and repository inspection.

## Root and naming

Keep worktrees in a sibling directory outside the main checkout. The exact machine path
belongs in local guidance.

- issue implementation: `issue-<number>-<short-slug>`;
- review and fix work use the existing issue worktree unless the canonical workflow
  requires a separate checkout;
- remove the worktree and local branch after merge once no process depends on them.

Before parallel dispatch, compare the issues' `area:*` labels from [labels.md](labels.md).
Serialize intersecting areas unless concrete file scopes establish that the changes
cannot collide.

