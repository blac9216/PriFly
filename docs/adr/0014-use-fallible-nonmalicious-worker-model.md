# ADR-0014: Use a fallible non-malicious Worker threat model in v1

Status: Proposed
Date: 2026-09-13

## Context

A stronger hostile-code containment model was considered, but v1 deliberately optimizes for operational simplicity and protection against ordinary agent mistakes rather than adversarial isolation.

## Decision Drivers

- The owner wants v1 to stay operationally simple.
- The primary observed risk is agents stepping on branches/worktrees or issuing broad Docker commands, not deliberate lateral attacks.
- Docker-development workloads need a usable Docker environment without making v1 an isolation-appliance project.

## Considered Options

### Ephemeral Linux identities + isolated worktrees + separate shared Worker Docker

Strong accidental-damage guardrails with simple disposable execution environment.

### Per-Worker microVMs / Docker Sandboxes

Stronger malicious containment but significantly more deployment/resource complexity than v1 needs.

### Host Docker socket in Workers

Very simple but lets accidental Worker Docker commands damage the Factory/host container universe.

### Run everything under one Factory identity

Minimal setup but poor accidental worktree/path separation.

## Decision

v1 treats Workers/harnesses as fallible but non-malicious. Every job attempt gets an ephemeral Linux identity and isolated worktree. Docker-capable jobs use a disposable Worker Docker daemon separate from the outer Factory Docker context. Strong hostile-code containment is deferred behind SandboxProvider.

## Consequences

The architecture explicitly does not claim malicious Worker containment. Shared Worker Docker jobs can interfere if a Worker behaves adversarially; ordinary collision naming and whole-daemon DIRTY reset mitigate accidental failures. Future stronger providers can be added without changing Factory semantics.
