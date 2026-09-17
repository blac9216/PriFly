# ADR-0031: Verify remote state before publication and retain required history

Status: Proposed
Amends: 0005, 0006, 0016
Date: 2026-09-16

## Context

R1 established Litestream TXID is not application sequence, defaults do not retain arbitrary published frontiers indefinitely, and retain-all alone does not prevent overwrite through lineage reuse. R2 supports conditional replacement but constrains writes to a hot key. The initial product has low-rate authoritative transitions and two long-running Workers.

## Decision Drivers

Direct evidence of exact recoverability; no early acknowledgement; simple bounded first adapter; complete supported-root lifetime; credible performance and capacity; later optimization permitted only with equivalent reviewed proof.

## Considered Options

(1) Derive exact WAL/LTX mapping and use a source-proven incremental remote verifier: efficient but expands adapter proof and recovery test burden. (2) Restore remote T for each publication and verify exact N/command/domain state: directly observable, slower and with more remote reads. For retention, root-aware selective immutable chain/snapshot GC was considered versus retaining all required files. Time-based retention alone is invalid for the standing promise.

## Decision

Adopt the initial persistence and deployment-parameter profile: serialized commit/sync/remote-restore/CAS/release; exactly verified N/T, unique never-reused replica prefix, remote retention disabled, no expiry/reset/unsafe second writer, all external evidence/Git/key dependencies retained; pressure holds admission before the reserved recovery/control capacity is threatened; a trusted R2 transport charges bounded byte/object/request grants before send, including background replica uploads and unknown old senders; complete publication and renewal tickets are reserved before local commit to avoid recursive grant renewal. Direct S3 conditional coordination updates carry unique identity and monotonic generation/sequence. Keep published reads separate from local pending state.

## Consequences

Low-volume performance profile is deliberately bounded. Full remote verification and storage growth must pass early real-service qualification. Missing thresholds reopens the choice; it cannot silently remove verification or inflate the workload limits. Required historical data cannot be deleted for budget convenience. A future efficient mapping/GC implementation needs independent proof and the appropriate design amendment/profile qualification.

Refs: [owner scope and ratified research](https://github.com/blac9216/PriFly/issues/38), [architecture](../explanation/architecture.md), [parameters](../reference/deployment-parameters.md), [conformance](../reference/conformance.md), [owner D3 design approval](https://github.com/blac9216/PriFly/issues/38#issuecomment-5701739109). This ADR remains Proposed; owner approval of the D3 design baseline containing this choice is recorded in the linked #38 comment, not in this file.
