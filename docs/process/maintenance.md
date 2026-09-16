# Maintenance

| Setting | Value |
|---|---|
| Worktree root | Sibling worktrees outside the main checkout — see [worktrees.md](worktrees.md); exact machine path in `*.local.md`. |
| Agent scratch dir | Machine-local scratch outside the repository tree, under a uniquely-named subdirectory per agent — see [worktrees.md](worktrees.md). |
| Allowed write locations | The current issue's worktree, the acting agent's own scratch subdirectory, and explicitly authorized generated-output paths (e.g. the audit's own `--out` path). |
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
