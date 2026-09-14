# Maintenance

| Setting | Value |
|---|---|
| Worktree root | Sibling worktrees outside the main checkout; the exact machine path belongs in local guidance. |
| Agent scratch dir | Machine-local scratch outside the repository tree. |
| Allowed write locations | Issue worktree, configured scratch directory, and explicitly authorized generated-output paths. |
| Test resource prefix | `prifly-<issue-or-attempt>-<run-id>` for containers, volumes, networks, namespaces, and remote test keys. |
| Host thresholds | Use machine-local guidance; no repository-wide numeric thresholds are declared yet. |
| Shared sequence resources | Timestamped migration filenames/IDs and migration-lineage metadata; serialize concurrent migration authorship until the implementation proves collision-safe allocation. |

Before every parallel wave, compare candidate issues' `area:*` labels. Treat an
intersection as a conflict risk unless concrete file scopes prove the work can proceed
safely. Cleanup must name only resources owned by the current run; broad Docker or remote
namespace cleanup is prohibited.

