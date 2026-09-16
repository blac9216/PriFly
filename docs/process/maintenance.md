# Maintenance

| Setting | Value |
|---|---|
| Worktree root | Exactly [worktrees.md](worktrees.md)'s "Root and naming": one root outside the main checkout, `${TMPDIR:-/tmp}/prifly-worktrees` unless `*.local.md` guidance overrides the exact machine path. |
| Agent scratch dir | Machine-local scratch outside the repository tree, under a uniquely-named subdirectory per agent — see [worktrees.md](worktrees.md). |
| Allowed write locations | Exactly the per-role worktrees [worktrees.md](worktrees.md) assigns — the current issue's `issue-<N>` worktree for implementer/fix/rebase roles, a reviewer's or merge-verifier's own `review-pr<P>` worktree for their commits under the reviewer-applied/revert gates — plus the acting agent's own scratch subdirectory and explicitly authorized generated-output paths (e.g. the audit's own `--out` path). |
| Test resource prefix | `prifly-<issue-or-attempt>-<run-id>` for any future container, volume, network, namespace, or remote test key. |
| Host thresholds | No repository-wide numeric thresholds are declared yet beyond the DP4 shared-attempt resource reservations recorded in the [DP4 operating contract](https://github.com/blac9216/PriFly/issues/38#issuecomment-5702104540); machine-local guidance may add its own. |
| Shared sequence resources | Timestamped forward-only migration filenames/IDs ([ADR-0020](../adr/0020-use-timestamped-forward-only-migrations.md)); serialize concurrent migration authorship until implementation proves collision-safe allocation. |

Before every parallel wave, compare candidate issues' `area:*` labels
([labels.md](labels.md)). Treat an intersection as a conflict risk unless concrete file
scopes prove the work can proceed safely — see the DP4 collision rules in the
[operating contract](https://github.com/blac9216/PriFly/issues/38#issuecomment-5702104540)
(shared schema, public contract, root wiring, `go.mod`/`go.sum`, and deployment edits are
always serialized regardless of apparent path disjointness).

Cleanup at the end of a run removes only resources the run itself created and named; a
broad Docker prune, remote-namespace sweep, or process-name kill pattern is prohibited —
never assume this host runs only this session's work.

Reopened issues still shown as Done are returned to Triage by the `github-workflow`
skill's maintenance pass (`references/maintenance.md` § 5, "State audit"); this
repository adds no rule of its own.
