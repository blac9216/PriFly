# Execution architecture

Kind: explanation

Execution turns released Work Items into exact, recoverable code candidates while preserving branch/worktree isolation, bounded autonomy, and Factory ownership of provider authority.

### Worktrees and job branches

Each Worker attempt operates in a dedicated worktree on a namespaced branch such as:

```text
prifly/jobs/W17/J812-a1
```

Worker A is not given write permissions to Worker B's worktree. Workers do not receive protected-ref provider authority.

### Exact Worker commits are preserved

PriFly does **not** replay Worker edits. A Worker may commit normally. Factory checkpoints the **exact commit objects** through a trusted Branch Publisher to the configured upstream job branch.

States:

1. `LOCAL` — commit exists only locally; may be lost.
2. `DURABLE_PROVISIONAL` — exact commit is verified recoverable from the configured Git remote; still unreviewed.
3. `ACCEPTED_CANDIDATE` — exact durable commit plus valid Acceptance Certificate.

Factory may checkpoint long-running jobs periodically so host loss does not waste large amounts of work/tokens.

### Trusted Branch Publisher

Provider credentials remain with Factory. Factory does not perform a privileged push from the Worker-controlled checkout. The Branch Publisher imports/fetches the exact commit into a trusted Git context using controlled Git configuration with hooks disabled, verifies the expected object/diff/scope, and pushes the exact commit to the namespaced remote branch.

The v1 threat model does not claim resistance to a deliberately malicious crafted Git object, but it avoids ordinary hook/configuration execution from a Worker-owned checkout.

### Git artifact recovery

Code is considered durably checkpointed only after PriFly verifies that a fresh Git client can reconstruct the supported repository state for that exact commit. Adapters must explicitly handle or reject Git LFS, submodules, and other external object dependencies. If PriFly cannot prove complete reconstruction for the configured repository mechanism, it cannot label that code artifact durably recoverable.

### Retention

A job branch remains pinned while it is the recovery root for active/accepted work. After accepted code becomes reachable from another retained project ref, the temporary job branch may be deleted according to retention policy. Rejected/discarded branches may be deleted after their configured diagnostic retention window.

## Work Item contract and Implementation Envelope

Every Work Item has Goal, Required Outcomes, Constraints, and Verification. Every Worker attempt has an Implementation Envelope containing the relevant baseline/design, authorized worktree/branch, authorized areas, predicted files, protected surfaces, scope, and dependency assumptions.

Deviation classes include Detail, Local, Expansion, Design, and Violation. Scope expansion is Factory-mediated. Design-level deviation enters Change Request/change-control flow.

## Runtime resume, Docker resources, and attempt cancellation

Every managed execution belongs to one active Factory job attempt and cumulative Work Item envelope.

### Route admission

A v1 Route is admitted only if Factory can start the managed session/process, identify the attempt, prevent or reconcile automatic session resume after cancellation, account for declared descendants/resources, and terminate or quarantine those resources. A runtime/harness whose uncontrolled resume cannot be disabled or reconciled is not an admitted v1 Route.

### Subagents/descendants

If a harness supports subagents, PriFly either disables them or treats them as descendants of the same attempt, permissions, and cumulative execution envelope. They do not become independent Factory Workers unless Factory creates independent jobs.

### Worker Docker ownership

Docker-capable jobs receive attempt-scoped naming/project conventions. Factory's Worker-Docker adapter tracks Compose project identity, container IDs, networks, volumes, and long-running service identities.

On normal cancellation/completion Factory revokes the job capability, terminates the harness/process tree, disables/removes known restartable Docker workloads, stops/removes attempt-owned containers/services, cleans attempt networks/volumes according to policy, and verifies no known attempt-owned workloads remain.

### Worker identity retirement and safe reuse

Each attempt-scoped OS identity is part of the attempt's runtime ownership boundary. After capability revocation and runtime cleanup, Factory removes or retires that identity before it may be reused.

An identity/UID must **not** be reused in a way that grants a later attempt access to surviving files, sockets, processes, volumes, or other resources owned by an earlier attempt. If cleanup is interrupted or Factory cannot prove that residual UID-owned resources are gone or safely isolated, the identity remains quarantined and unavailable for reuse until reconciliation succeeds or the containing disposable execution environment is reset.

The implementation may use a UID pool, delayed retirement, disposable namespaces, or another conforming mechanism; the safety property is that a new attempt never inherits access merely because an old numeric identity was recycled.

### Dirty shared-daemon fallback

If Factory cannot establish that stale Docker/runtime work is gone, the Worker Docker daemon becomes `DIRTY`. Factory stops admitting new Docker jobs, pauses/requeues other Docker-dependent jobs as needed, destroys/recreates the disposable Worker Docker daemon environment/data root if necessary, and resumes only after the daemon is clean. Loss of Worker Docker image cache is acceptable.

### Recovery

After Factory/Worker-Docker restart, the runtime adapter reconciles surviving resources **and retired/quarantined attempt identities** before admitting new work that could reuse them. No stale result from a cancelled/superseded attempt can regain acceptance authority.
