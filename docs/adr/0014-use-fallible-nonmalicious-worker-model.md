# ADR-0014: Use a fallible non-malicious Worker threat model in v1

Status: Accepted
Amended-by: 0025
Date: 2026-09-13

## Context

A stronger hostile-code containment model was considered, but v1 deliberately optimizes for operational simplicity and protection against ordinary agent mistakes rather than adversarial isolation.

## Decision Drivers

- The owner wants v1 to stay operationally simple.
- The primary observed risk is agents stepping on branches/worktrees or issuing broad Docker commands, not deliberate lateral attacks.
- Docker-development workloads need a usable Docker environment without making v1 an isolation-appliance project.
- Attempt-scoped OS identity reuse must not accidentally give a later Worker access to surviving resources from an earlier attempt.

## Considered Options

### Ephemeral Linux identities + isolated worktrees + separate shared Worker Docker

Strong accidental-damage guardrails with simple disposable execution environment. Attempt identities are retired/quarantined until their surviving resources are removed or safely isolated.

### Per-Worker microVMs / Docker Sandboxes

Stronger malicious containment but significantly more deployment/resource complexity than v1 needs.

### Host Docker socket in Workers

Very simple but lets accidental Worker Docker commands damage the Factory/host container universe.

### Run everything under one Factory identity

Minimal setup but poor accidental worktree/path separation.

## Decision

v1 treats Workers/harnesses as fallible but non-malicious. Every job attempt gets an ephemeral Linux identity and isolated worktree. After an attempt ends, its OS identity/UID is retired or quarantined until Factory proves surviving attempt-owned resources are removed or safely isolated; unsafe identity reuse is forbidden. Docker-capable jobs use a disposable Worker Docker daemon separate from the outer Factory Docker context. Strong hostile-code containment is deferred behind SandboxProvider.

## Consequences

The architecture explicitly does not claim malicious Worker containment. Shared Worker Docker jobs can interfere if a Worker behaves adversarially; ordinary collision naming, identity retirement/quarantine, and whole-daemon DIRTY reset mitigate accidental failures. Future stronger providers can be added without changing Factory semantics.
