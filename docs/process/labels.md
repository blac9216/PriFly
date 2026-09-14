# Labels

The configure-workflow skill provisions the closed canonical set for type, severity,
priority, concern, regression, backlog, deferred, parked, help, question, and
documentation labels. This file owns PriFly's repo-specific `area:*` set. Every issue
must carry at least one area; cross-cutting work carries each area whose files it may
change.

Areas are concurrency locks over likely Git diff territory. Issues with intersecting
area sets are serialized unless the orchestrator inspects their concrete scopes and
establishes that they cannot collide.

| Label | Colour | Covers |
|---|---|---|
| `area:core` | `d1e8ff` | Factory kernel, domain contracts, command handling, canonical state, and migrations. |
| `area:durability` | `d1e8ff` | Publication lane, SQLite replication, R2 coordination, and durability evidence. |
| `area:providers` | `d1e8ff` | Provider Broker, external projections, obligations, adapters, and reconciliation. |
| `area:recovery` | `d1e8ff` | Takeover, restore, Recovery Kits, supported recovery roots, and upgrades. |
| `area:security` | `d1e8ff` | Trust boundaries, capabilities, owner confirmation, credentials, and isolation. |
| `area:planning` | `d1e8ff` | Planning Records, requirements, gates, change impact, and quality evaluation. |
| `area:workflow` | `d1e8ff` | GitHub workflow, CI, repository automation, process docs, and installed skills. |

Add or split an area only when repository structure shows a recurring conflict surface
that this set cannot describe cleanly, then rerun configure-workflow's label script with
the same area JSON used by its audit.

