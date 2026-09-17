# Implementation conformance

Kind: reference

This document preserves the minimum adversarial **pass/fail obligations** an implementation must demonstrate before PriFly claims the corresponding architectural guarantees. It is not an implementation plan, test-suite layout, or copy of the architecture-review history. Implementations may choose different fixtures and tooling, but the failure injections and required semantic results below must remain testable.

A green documentation check does not satisfy these obligations. They become release evidence only when executed against the pinned implementation/runtime/provider configuration that claims the guarantee.

## Authoritative publication and takeover

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Acknowledged history cannot disappear across takeover | Generation G has published frontier N. Race publication of N+1 against explicit takeover to G+1 using the same coordination-object version. Exercise both CAS orderings. | Exactly one ordering wins. If N+1 publishes first, stale takeover fails and rereads/inherits N+1. If takeover wins first, old-generation publication of N+1 cannot become authoritative or be acknowledged. |
| Lost successful publication reply is not rejection | Let publication CAS succeed, lose its response, and temporarily make exact read-back unavailable. | No definitive `REJECTED` result is returned or cached. Resolution/retry uses the same command ID. When published history becomes observable, the command resolves to its original `RELEASED` result. |
| Failed/unknown publication cannot leak authoritative visibility | Commit locally and/or sync remotely without successfully proving coordination publication. | Owner-facing authoritative queries, released events, dependent scheduling, and consequential provider sends cannot consume that state. Uploaded-but-unpublished tails may be discarded. |
| Interrupted successor initialization preserves predecessor authority | Take over to G+1 `INITIALIZING`, then crash before activation; repeat recovery/takeover. | Recovery restarts from the last published predecessor frontier and inherited obligations. Missing local state never initializes an empty Factory. |

Canonical rules: [Persistence and durability](../explanation/persistence-and-durability.md), [API contract](api-contract.md), ADR-0005, ADR-0006.

## Exact restore-frontier lifetime

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Every supported Published Frontier remains exactly reconstructible for its required lifetime | Publish frontier N/T, then exercise the configured replica compaction/retention behavior, time passage, host loss, and empty-host restore while the coordination record or a supported Recovery Root Manifest still depends on N/T. | Factory can still reconstruct exactly the published authoritative state through T and prove it contains N. Immediate post-sync restore success alone is insufficient. |
| Unsupported/unpublished replica tails do not change recovery authority | Leave later remote bytes beyond published T, then perform recovery. | Successor restores the exact published frontier, not merely the latest bytes available in the replica. |

Retention/compaction configuration is therefore part of the pinned durability conformance tuple.

## Provider possible-send boundary

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| PREPARED is known unsent | Crash after PREPARED publication but before SEND_ARMED. | Recovery may prove the operation was not sent because provider mutation code cannot send from PREPARED. |
| SEND_ARMED means possibly sent | Publish SEND_ARMED, allow or delay the network send, then crash before recording terminal outcome. | Recovery treats the obligation as UNKNOWN/possibly sent and retains its conflict scope until the operation profile proves a terminal result or authorized disposition. No blind retry occurs. |
| Negative observation is not proof of non-execution | After ambiguous SEND_ARMED, return missing lookup/access failure/expired handle from reconciliation. | Operation remains UNKNOWN unless the admitted profile defines that observation as authoritative terminal evidence. |

Canonical rules: [Provider integration](../explanation/providers.md), [Provider operation profiles](provider-operation-profiles.md), ADR-0007.

## Qualified PR-only integration

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| A changed PR head cannot reuse old acceptance | Accept head H, replace it with H2 before the native merge request. | Expected-head precondition or preceding eligibility rejects the stale request; H2 requires fresh review. No direct target push occurs. |
| Base-race safety matches the admitted GitHub profile | Race a target/base update with the merge request under the exact configured checks/protection/merge method. | The admitted profile establishes the required current-base/check behavior or admission fails. Expected-head protection is never reported as expected-base CAS. A pre-send read alone is insufficient. |
| An ambiguous merge is reconciled | Let merge succeed, lose the reply and make read-back temporarily unavailable. | The operation remains UNKNOWN with its conflict scope reserved; no duplicate conflicting mutation is sent. Later native evidence records the actual merge SHA, not an assumed candidate SHA. |
| Native review identity is real | Require native approval but offer only the PR author's identity or a comment projection. | Merge eligibility is blocked; a comment is not counted as native approval and no identity is fabricated. |

Canonical rules: [Git integration](../explanation/git-integration.md), [Acceptance contract](acceptance-contract.md), [Provider operation profiles](provider-operation-profiles.md), ADR-0023, ADR-0013 as amended by ADR-0024.

## Acceptance evidence and recovery-root closure

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Required evidence exists before acceptance release | Delay/fail upload or content verification for one required evidence object. | Acceptance Certificate is not released while required evidence is pending/unverified. |
| Supported historical roots protect all required dependencies | Accept work, create a Recovery Root Manifest, then run cleanup while that root remains supported. Exercise evidence/Git/key-generation retention races. | Cleanup cannot remove the final dependency required by any supported root. Uncertain reachability leaks storage rather than deleting possibly required evidence. |
| Retiring a recovery root is authoritative before cleanup | Attempt cleanup concurrently with root retirement. | Last dependencies become deletable only after authoritative retirement is published. |

Canonical rules: [Review](../explanation/review.md), [Acceptance contract](acceptance-contract.md), ADR-0013, ADR-0016 and their indexed amendments.

## Owner and planning authority

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Pilot/Worker cannot mint consequential owner consent | Attempt consequential owner confirmation through Pilot and Worker credentials/capabilities. | Authentication/authorization denies the call. Only the separately protected owner-control capability can confirm the exact immutable Owner Action package. |
| Engineering success cannot mint a phase release | Pass an engineering gate without the matching owner confirmation; then change the package after confirmation. | Neither case permits next-phase work. Release checks exact package identity, scope and envelope. |
| AI proposal cannot waive its own mandatory planning gate | Remove the applicable policy rule/detector coverage or return UNKNOWN for a protected trigger while a producer proposes `NOT_APPLICABLE`. | Effective applicability remains UNKNOWN/blocking. A reviewed assertion alone cannot establish N/A. |

Canonical rules: [Pilot](../explanation/pilot.md), [Planning policy](planning-policy.md), [API contract](api-contract.md), ADR-0008, ADR-0010.

## Worker runtime and identity cleanup

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Cancelled attempt cannot continue as valid work | Cancel an attempt while descendants/services exist; exercise harness/runtime restart or auto-resume behavior. | Capability is revoked, attempt-owned writers/descendants are terminated or reconciled, and late results cannot regain acceptance authority. Explicitly retained workspace services have separate ownership and grants. Uncontrollable resume modes are not admitted Routes. |
| Workspace reuse never overlaps writers | Keep a workspace service, interrupt the current Implementer, and dispatch a fresh correction attempt. | Old write grants and writers are proven stopped before the new lease; retained resources stay inventoried. Reviewer receives an isolated exact candidate view rather than hidden mutable workspace state. |
| Evidence reuse preserves credible independent judgment | Supply exact attributable CI/Implementer results, then stale or incomplete results. | Reviewer may accept sufficient credible evidence; rejects stale/insufficient evidence and can gather missing checks in the same review. A changed candidate requires fresh review, not a review of each test invocation. |
| Residual Docker resources fail closed | Interrupt Docker cleanup and leave attempt-owned resources whose removal cannot be proven. | Shared Worker Docker becomes DIRTY; new Docker work is blocked/requeued until reconciliation or disposable-daemon reset establishes cleanliness. |
| UID reuse cannot leak old resources | Interrupt cleanup with surviving resources owned by the old attempt identity, restart Factory, and attempt to admit another Worker. | The old identity remains retired/quarantined; the new attempt cannot inherit access through UID reuse. Reuse occurs only after resource removal/safe isolation or disposable-environment reset. |

Canonical rules: [Execution](../explanation/execution.md), [Execution runtime](../explanation/execution-runtime.md), [Review](../explanation/review.md), [Security](../explanation/security.md), ADR-0024, ADR-0025.

## Database migration lineage

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Supported applied history is an ordered prefix of the canonical migration lineage | Apply migration with timestamp 20, then introduce an unmerged migration with timestamp 10. | Integration/admission rejects the lower-ID migration as-is. It is regenerated above the canonical frontier and revalidated; Factory never silently applies `20 → 10` or skips 10 because of a high-water mark. |
| Fresh and sequential upgrade paths converge | Build one database fresh from the current baseline + migrations and another through each declared supported release upgrade path. | Resulting schema/domain state is semantically equivalent under the same declared migration lineage. |
| Pre-v1 consolidation preserves current development data | Bring the development DB to the exact consolidation frontier, checkpoint, generate/verify a baseline, and promote the live DB to the baseline marker. | Existing authoritative data/metrics remain intact; fresh baseline creation reproduces equivalent schema state. |

Canonical rules: [Upgrades](../explanation/upgrades.md), ADR-0020.

## Empty-host recovery and upgrade cutoff

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Fresh host can recover the supported Factory state | Destroy local Factory state and recover using only supported release/container images, the pinned private-Git `bootstrap.json` and `secrets.json.age`, independently retained repository access/age key, configured Git remotes, R2 and declared dependencies. | Recovery has no dependency on the lost host's credential store; transient plaintext is protected. It restores the exact published frontier, historical metrics/root dependencies and inherited SEND_ARMED/UNKNOWN obligations; ACTIVE requires validation/reconciliation. A missing DB never silently initializes an empty Factory. |
| Successful new-version publication closes rollback even if reply is lost | Create durable pre-upgrade checkpoint, start upgraded Factory, successfully publish its first new authoritative mutation, then lose the publication/client reply and simulate failure. | Pre-upgrade checkpoint rollback remains closed because publication—not receipt of acknowledgement—is the cutoff. Recovery is roll-forward and same-command resolution discovers the published result. |

Canonical rules: [Recovery](../explanation/recovery.md), [Upgrades](../explanation/upgrades.md), [Persistence and durability](../explanation/persistence-and-durability.md), ADR-0016 as amended by ADR-0026.

## Git reconstruction

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| A durable Worker code checkpoint is reconstructible outside the Worker checkout | From a clean client/environment, fetch the exact checkpoint commit and all admitted external Git dependencies such as LFS/submodules. Exercise missing/unsupported dependency configurations. | PriFly labels the code durably recoverable only if the supported repository state can be reconstructed exactly. Unsupported dependency mechanisms fail admission or durability labeling rather than silently producing an incomplete checkout. |

Canonical rules: [Execution](../explanation/execution.md), ADR-0023.

## Triage, validation and fulfillment

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Backlog treatment does not discharge an obligation | Hold, batch or release a Finding to planning; attempt parent closeout; then duplicate it into a surviving Finding. | Nonterminal treatment still blocks affected scope as policy requires. Duplicate handling preserves surviving blockers; cancellation/scope reduction is not reported as fulfilled delivery. |
| Fixes re-pend the exact target | Fail a versioned Validation Target with multiple blockers, integrate fixes one by one, and change the target revision during a run. | Only resolution of all blockers re-pends the target for normal scheduling. Old-run evidence does not validate the new revision; no private fix-wave bypass exists. |
| Incomplete infrastructure is not product evidence | Lose the environment part-way through a multi-target run; offer an ad hoc workaround. | Affected observations remain incomplete/unknown, not product PASS or confirmed product defect without evidence. A workaround does not establish intended behavior. |

Canonical rules: [Findings and triage](../explanation/findings-and-triage.md), [Validation](../explanation/validation.md), [Release and closeout](../explanation/release-and-closeout.md), ADR-0027. The complete scenario inventory is [Product acceptance](product-acceptance.md).

## Release use

Before a release claims one of these guarantees, its release evidence should identify:

- the exact Factory build/version;
- SQLite driver/configuration and relevant PRAGMAs/concurrency mode;
- Litestream version/configuration and replica retention/compaction behavior;
- R2/coordination adapter version/configuration;
- Git/provider adapter versions and admitted operation profiles;
- Worker runtime/SandboxProvider/Worker-Docker configuration;
- the conformance tests/failure injections executed and their evidence artifacts.

Changing a mechanism in a way that changes the required semantic result is an architecture/design change. Changing how the same oracle is exercised is an implementation/test change.

## Initial handover profile qualification

Required additional profile observations: (1) externally imported stale/forged/incomplete packages never dispatch; (2) real interactive Codex and Claude attempts cannot access controller sockets/other workspaces and all sentinels/Docker writers stop before handoff; (3) every publication's exact remote restore contains the expected sequence/command and no pending successor; (4) retention/compaction/local loss preserves current and older supported roots while unsafe lineage reuse/reset is rejected; (7) old/new controller lost-reply trials enforce the publication rollback cutoff; (8) fixed-load/resource/storage pressure preserves control-plane headroom and never deletes required evidence. These are required future tests, not claimed PASS evidence.

Adversarial lifecycle qualification delays Create/Start across cancellation, retirement, successor lease and takeover. A stopped-only control must fail; retired IDs cannot write. Storage qualification exhausts permits and loses debit/response continuity across incarnation changes: no unsafe reuse/refill, unbounded body or under-counted old sender is permitted.

Quota tests expire the ordinary grant immediately after N commits: its precharged ticket must complete publication, and renewal must precede the next ordinary commit. Missing reservations block before commit; violated bounds halt without recursive renewal. Repeat delayed lifecycle-operation probes through Worker Docker/Compose and verify Git checkpoint size accounting separately from R2.
