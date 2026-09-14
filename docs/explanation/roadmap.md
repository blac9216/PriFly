# Architecture roadmap

Kind: explanation

This is an architectural roadmap, not a feature backlog or implementation plan. It records the boundary between the approved v1 shape and intentionally deferred capabilities.

## v1 architecture target

The v1 target is a disposable containerized Go Factory with SQLite canonical state, R2/Litestream durability, explicit recovery, Git-based Worker checkpoints, deterministic routing, standards-backed engineering-quality evaluation, planning and review gates, a conversational Pilot, and a shared Worker Docker execution environment for container-development workloads.

For consequential artifacts, v1 must preserve the separation between:

- reusable standards-backed general engineering quality;
- Project-specific Requirements/Design/Constraint conformance;
- PriFly lifecycle/authority/workflow permission.

Workers and Reviewers use the pinned profiles in [Quality rubrics](../reference/quality-rubrics.md) and [Standards registry](../reference/standards-registry.md). Project conformance remains a separate evaluation rather than being represented as a fake external standard.

The architecture is intentionally optimized for a personal autonomous software factory rather than enterprise hostile-code containment or high-availability distributed operation.

## Deferred capabilities

Deferred:

- malicious/compromised Worker or harness containment;
- per-Worker microVM isolation;
- multi-cloud recovery;
- survival of permanent R2/Git account loss;
- hostile cloud-credential deletion recovery;
- enterprise DLP/data-classification policy;
- remote/multi-user Bridge security;
- distributed Workers;
- automatic lease-expiry takeover;
- atomic cross-repository merge;
- Redis/PostgreSQL;
- hosted Factory;
- plugin SDK;
- automatic routing-policy mutation;
- broad GitLab implementation;
- advanced prompt-codec optimization.

These deferrals are part of the v1 contract rather than hidden missing mechanisms.

## Implementation-conformance frontier

Architecture approval is not implementation certification. Before PriFly claims the corresponding guarantees, implementation must satisfy the normative pass/fail oracles in [Implementation conformance](../reference/conformance.md).

Those oracles preserve the concrete adversarial demonstrations that matter to the design, including:

- publication/takeover ordering and lost CAS replies;
- exact Published Frontier lifetime across replica retention/compaction and empty-host recovery;
- SEND_ARMED crash/ambiguity handling;
- exact target movement at the actual remote update;
- acceptance-evidence upload/pin/cleanup races and supported historical roots;
- owner-confirmation capability isolation;
- missing-rule/UNKNOWN planning-gate behavior;
- runtime cancellation, stale descendants, Worker-Docker DIRTY reset, and safe OS-identity retirement/UID reuse;
- timestamped migration ordered-prefix behavior and baseline consolidation;
- fresh Git reconstruction for checkpointed code;
- publication-based upgrade rollback cutoff.

The implementation also needs pinned and tested identities/configuration for the SQLite driver/PRAGMAs/concurrency model, Litestream replication/restore/retention behavior, R2 CAS coordination, Worker runtime/Docker lifecycle, Branch Publisher, Verification Runner, provider operation profiles, Recovery Kit packaging, supported runtime bill of materials, retention pins, and the first executable quality-rubric evaluator/schema conforming to ADR-0021/ADR-0018.

Quality-rubric implementation must demonstrate that exact rubric/source versions are pinned, criterion results preserve PASS/FAIL/NOT_APPLICABLE/UNKNOWN semantics, blocking FAIL/UNKNOWN cannot be promoted, official-source ambiguity fails closed, and project-specific thresholds are read from the governing Planning Baseline rather than invented during review.

Those tasks implement the approved architecture. Changing the reviewed authority/order/safety result or the meaning of a standards-backed quality criterion requires a governed design/policy change; changing test fixtures or implementation mechanics while preserving the same oracle/criterion does not.
