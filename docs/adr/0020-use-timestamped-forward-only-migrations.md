# ADR-0020: Use timestamped forward-only migrations with pre-v1 consolidation

Status: Accepted
Date: 2026-09-13

## Context

PriFly's canonical state is SQLite, and the implementation model deliberately permits multiple Workers to develop independent slices concurrently. Database schema changes therefore need an ordering scheme that does not force Workers to coordinate for the next integer migration number.

The project also begins before a public v1 compatibility boundary. Keeping every exploratory development migration forever would make the first supported release carry unnecessary schema archaeology. At the same time, the primary development Factory may already contain valuable historical metrics and state, so consolidation must not require discarding a current development database merely to create a clean v1 install path.

Once a release is supported, database migration history becomes part of the upgrade contract and cannot be rewritten casually. PriFly's upgrade architecture already uses a durable pre-upgrade checkpoint and a rollback cutoff rather than relying on reverse migrations.

Timestamp identities remove the common concurrent filename collision but create another ordering question that must be explicit: if a lower timestamped migration arrives after a higher migration is already canonical/applied, PriFly must not silently apply different orders on fresh and upgraded databases or let a migration library skip the late file behind a high-water mark.

## Decision Drivers

- Concurrent Workers should be able to author migrations without frequent filename/sequence collisions.
- Migration application order must remain deterministic and mechanically checkable.
- Fresh creation and supported upgrades must traverse one declared migration lineage rather than library-dependent ordering.
- v1 should start from a clean schema baseline rather than an arbitrarily long pre-release migration chain.
- Consolidation should preserve the current development Factory's authoritative state and historical metrics when practical.
- Shipped upgrade paths must be immutable and auditable.
- Recovery uses a checkpoint-before-migration / roll-forward-after-activation model, so reverse migrations should not become a second rollback system.
- The migration library is an implementation choice and should conform to the policy rather than define it.

## Considered Options

### UTC timestamped forward-only migrations plus ordered-prefix enforcement and pre-v1 baseline consolidation

Workers generate independent timestamp identities, migrations are applied in canonical timestamp order, each supported database history must be an ordered prefix of that lineage, and pre-release history may be collapsed into verified baselines before the v1 compatibility boundary. This minimizes merge collisions while keeping fresh/upgrade order deterministic and supported release history small.

### Sequential integer migrations

Simple and common, but parallel branches regularly select the same next number and require renumbering/rebasing. The sequencing mechanism becomes avoidable coordination between Workers.

### Timestamped migrations with arbitrary out-of-order application

Avoids filename collisions, but an existing database could observe `20 → 10` while a fresh database observes `10 → 20`. Supporting that safely would require explicit dependency/commutativity semantics and substantially more testing than v1 needs.

### Timestamped migrations with no consolidation

Avoids most sequencing collisions but ships all exploratory pre-release schema steps forever, making fresh installs, review, and long-term maintenance noisier than necessary.

### Replaceable schema baseline with no durable migration history

Very clean for fresh installs, but once real user data exists it provides no safe supported upgrade path between releases.

### Dependency-graph migrations

Could model parallel branches explicitly, but adds graph and merge-node complexity that PriFly does not need for a single SQLite schema with serialized application.

## Decision

PriFly uses UTC timestamped, forward-only database migrations with ordered-prefix lineage enforcement and pre-v1 baseline consolidation.

1. Migration IDs use a UTC timestamp prefix with microsecond precision: `YYYYMMDDHHMMSSffffff_<kebab-slug>.sql`. The 20-digit timestamp is the ordering key. CI rejects malformed or duplicate IDs; a collision is regenerated before merge.
2. For each supported schema baseline/epoch, the applied migration ledger must be a valid **ordered prefix** of the canonical migration lineage for that baseline. PriFly does not intentionally support arbitrary out-of-order application in v1.
3. If an unmerged migration has an ID below the canonical applied/integration frontier, it is not admitted as-is. The branch regenerates it with a timestamp after the relevant frontier and revalidates it against the current baseline plus pending lineage. A migration library must not silently skip or late-apply such a file.
4. Migrations are **forward-only**. PriFly does not maintain paired `down` migrations as a recovery mechanism. The pre-upgrade durable checkpoint is the rollback mechanism before the activation cutoff; afterward recovery is roll-forward.
5. A migration becomes immutable when it lands on `main`. Before merge, a branch may replace/regenerate its unshipped migration as needed to resolve a semantic conflict, timestamp-order conflict, or integration problem.
6. The migration ledger records at least migration ID, content checksum, application time, Factory version, and the active schema baseline/epoch. If an already-recorded migration ID is presented with different contents, startup/migration fails closed.
7. Workers may author migration files and exercise them only against disposable/test databases. Only the Factory migration runner applies schema migrations to the canonical Factory database, while normal authoritative work is quiesced or before Factory reaches `ACTIVE`.
8. **Pre-v1 migration history is provisional.** PriFly may consolidate it at deliberate milestones. A consolidation first brings the primary development database to the current migration frontier, creates a durable checkpoint, and validates schema/domain invariants. A new baseline representing that resulting schema is then generated and checksummed.
9. An existing development database at the exact consolidation frontier may be **promoted to the new baseline without losing its data** after the migration runner verifies the expected prior migration frontier and schema invariants, then records the new baseline marker. Fresh databases initialize directly from the new baseline. Older pre-v1 databases that did not reach the consolidation frontier are not a supported upgrade path; they must be brought forward using the older source revision or rebuilt.
10. Before the first supported v1 release, PriFly performs a final consolidation. The v1 release therefore starts from one clean baseline plus any migrations intentionally created after that baseline (normally none at the cut).
11. After v1, any migration required by a supported release-to-release upgrade path remains immutable and available. A later fresh-install baseline may be introduced only when doing so does not remove migrations still required by the declared support window.
12. CI/conformance tests verify filename/ID validity and uniqueness, ordered-prefix validity, rejection/regeneration of late lower-ID migrations, immutable checksums for shipped migrations, fresh creation from the current baseline plus pending migrations, supported release-to-release upgrades, and semantic equivalence of a consolidation baseline to the schema it replaces.

The concrete Go migration library, source-tree directory, transaction wrapper, and schema fingerprint implementation are deferred to implementation ADR/conformance work so long as they preserve these rules.

## Consequences

Parallel implementation avoids the normal `0017`/`0017` migration collision class. Timestamp ordering does not solve semantic conflicts—two Workers can still make incompatible changes to the same tables—so ordinary review and integration checks remain necessary.

A late lower timestamp is intentionally treated as an integration problem rather than an alternative ordering. That may require regenerating an unmerged migration after another branch lands, but it keeps fresh-install and sequential-upgrade behavior identical and prevents the migration library from silently defining product semantics.

PriFly can aggressively clean up pre-release migration archaeology without sacrificing the current development Factory's accumulated metrics, provided that database is brought to and verified at the consolidation frontier before old pre-v1 migrations are removed from the active tree. Git history remains historical provenance; pre-v1 binaries/databases are not promised long-term upgrade compatibility.

After v1, migration files and checksums become compatibility artifacts. This deliberately trades the freedom to rewrite history for predictable upgrades and recoverability.
