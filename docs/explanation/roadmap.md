# Architecture roadmap

Kind: explanation

This is an architectural roadmap, not a feature backlog or implementation plan. It records the boundary between the approved v1 shape and intentionally deferred capabilities.

## v1 architecture target

The v1 target is a disposable containerized Go Factory with SQLite canonical state, R2/Litestream durability, explicit recovery, Git-based Worker checkpoints, deterministic routing, planning and review gates, a conversational Pilot, and a shared Worker Docker execution environment for container-development workloads.

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

Before claiming the corresponding implementation guarantees, the project still needs implementation ADRs and tests for the pinned Litestream/SQLite tuple, R2 CAS coordination, Worker identity and Docker lifecycle, Branch Publisher behavior, Verification Runner, provider operation profiles, Recovery Kit packaging, supported runtime bill of materials, retention pins, and fault injection. Those tasks implement the approved architecture; changing the reviewed authority/order rules requires a new architecture decision.
