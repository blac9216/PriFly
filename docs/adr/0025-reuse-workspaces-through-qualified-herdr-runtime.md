# ADR-0025: Reuse workspaces through a qualified HerdR runtime

Status: Proposed
Amended-by: 0030
Amends: 0014, 0015, 0019
Date: 2026-09-16

## Context

ADR-0014 assigned an isolated worktree to every attempt; ADR-0015 left richer code intelligence optional; ADR-0019 described attempt-owned resources without the new retained workspace boundary. [PRD v2.1](../reference/product-requirements.md) §§5, 8, 13 and Appendix F select HerdR and Serena initially and make the Implementation Workspace longer-lived than an attempt. These portions are amended; the non-malicious threat model, replaceable boundaries, safe identity retirement and cumulative budgets remain. Owner direction is issue #36.

## Decision Drivers

- Fresh correction attempts should retain useful dependencies, caches and permitted services.
- Only one modifying attempt may own a workspace at a time.
- Runtime status, restored sessions and tool output cannot become workflow authority.

## Considered Options

### Reusable Work Item workspace with exclusive attempt leases

Selected by the PRD. Reduces repeated setup while requiring explicit resource ownership and controlled handoff.

### Rebuild worktree and environment for every attempt

Simplifies disposal but wastes setup and discards useful state during routine correction.

### Unrestricted shared runtime session and filesystem

Operationally simple but cannot enforce attempt identity, writer ownership or cancellation.

These alternatives compare the supplied product direction with the prior documented mechanisms; they do not reconstruct an unrecorded owner interrogation.

## Decision

An Implementation Workspace belongs to one Work Item/PR lifecycle; each current correction is a fresh Implementer attempt. Handoff revokes old writer authority, stops modifying processes, inventories retained resources, checks candidate/dirty state, then grants one successor lease. Review uses a separate clean candidate view. HerdR is the initial managed runtime behind a qualified adapter; Git plus admitted Serena supplies v1 code intelligence with exact provenance. Owner and Worker sessions are separately addressed, observation defaults to read-only, creation does not steal focus, and managed auto-resume is disabled until Factory reconciliation. Every dispatch pins shared/role/job prompts, resolved context/tools/output/evaluation contracts and manifest identity. Required missing inputs fail admission. Dedicated Worker Docker is separate from the Factory-hosting daemon. Uncertain cleanup quarantines affected resources/identities; fresh attempts do not reset scope budgets.

## Consequences

Runtime/OS/socket/ACL and Docker topology must be qualified before Route admission. Healthy workspace services survive ordinary correction handoff; host loss may rebuild them from durable checkpoints. No selected runtime or tool is claimed already qualified, and shared Docker remains outside hostile-code containment guarantees.

Canonical contracts: [documentation index](../README.md) and [source traceability](../reference/traceability.md). Proposed here for independent review; no implementation certification is implied.
