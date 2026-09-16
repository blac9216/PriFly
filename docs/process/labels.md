# Labels

The closed canonical set for type, severity, priority, concern, regression, backlog,
deferred, parked, help, and question is provisioned by the `configure-workflow` skill
and reused as-is; this file records only what is repository-specific. Read live with
`gh label list --limit 200` (read live 2026-09-16); the table below is that output,
grouped, and is refreshed the same way after any label change.

## Canonical set observed live

| Label | Covers |
|---|---|
| `bug`, `enhancement`, `question`, `chore`, `documentation`, `epic` | Type. |
| `severity:critical`, `severity:major`, `severity:minor` | Found-issue severity. |
| `priority:high`, `priority:medium`, `priority:low` | Sequencing. |
| `size:s`, `size:m`, `size:l` | Bounded-work size; `size:l` marks a large tracking epic that executable issues must split out of. |
| `backlog`, `deferred`, `parked`, `help`, `regression` | Lifecycle/provenance. |
| `concern:lint`, `concern:style`, `concern:refactor`, `concern:tests`, `concern:perf`, `concern:security` | Found-issue dimension, non-blocking unless stated otherwise. |

## Repo-specific `area:*` set

Every issue carries at least one `area:*` label; cross-cutting work carries each area
whose files it may change. Areas are concurrency locks over likely Git diff territory —
issues with intersecting area sets are serialized unless the orchestrator inspects their
concrete scopes and establishes that they cannot collide (see
[maintenance.md](maintenance.md)).

| Label | Covers |
|---|---|
| `area:core` | Factory kernel, domain contracts, command handling, canonical state, and migrations. |
| `area:durability` | Publication lane, SQLite replication, R2 coordination, and durability evidence. |
| `area:providers` | Provider Broker, external projections, obligations, adapters, and reconciliation. |
| `area:recovery` | Takeover, restore, Recovery Kits, supported recovery roots, and upgrades. |
| `area:security` | Trust boundaries, capabilities, owner confirmation, credentials, and isolation. |
| `area:planning` | Planning Records, requirements, gates, change impact, and quality evaluation. |
| `area:workflow` | GitHub workflow, CI, repository automation, process docs, and installed skills. |

This is the complete closed `area:*` set as of 2026-09-16 — no `area:docs`,
`area:testing`, or similar exists. Add or split an area only when repository structure
shows a recurring conflict surface this set cannot describe cleanly, then rerun
`configure-workflow`'s label script with the same area JSON used by its audit.
