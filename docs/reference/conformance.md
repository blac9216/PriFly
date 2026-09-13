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

## Exact integration target

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Verified code is integrated only against the exact verified target | Construct and independently verify integration commit M against target/base B. Move the remote target before the actual update. | Exact B→M compare-and-update fails; the stale Acceptance Certificate/integration eligibility cannot integrate and work returns to revalidation. Ordinary PR merge semantics cannot bypass the check. |

Canonical rules: [Execution](../explanation/execution.md), [Acceptance contract](acceptance-contract.md), [Provider operation profiles](provider-operation-profiles.md), ADR-0012, ADR-0013.

## Acceptance evidence and recovery-root closure

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Required evidence exists before acceptance release | Delay/fail upload or content verification for one required evidence object. | Acceptance Certificate is not released while required evidence is pending/unverified. |
| Supported historical roots protect all required dependencies | Accept work, create a Recovery Root Manifest, then run cleanup while that root remains supported. Exercise evidence/Git/key-generation retention races. | Cleanup cannot remove the final dependency required by any supported root. Uncertain reachability leaks storage rather than deleting possibly required evidence. |
| Retiring a recovery root is authoritative before cleanup | Attempt cleanup concurrently with root retirement. | Last dependencies become deletable only after authoritative retirement is published. |

Canonical rules: [Review and validation](../explanation/review-and-validation.md), [Acceptance contract](acceptance-contract.md), ADR-0013, ADR-0016.

## Owner and planning authority

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Pilot/Worker cannot mint consequential owner consent | Attempt `owner-action.confirm/v1` through Pilot and Worker credentials/capabilities. | Authentication/authorization denies the call. Only the separately protected owner-control capability can confirm the exact immutable Owner Action package. |
| AI proposal cannot waive its own mandatory planning gate | Remove the applicable policy rule/detector coverage or return UNKNOWN for a protected trigger while a producer proposes `NOT_APPLICABLE`. | Effective applicability remains UNKNOWN/blocking. A reviewed assertion alone cannot establish N/A. |

Canonical rules: [Pilot](../explanation/pilot.md), [Planning policy](planning-policy.md), [API contract](api-contract.md), ADR-0008, ADR-0010.

## Worker runtime and identity cleanup

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Cancelled attempt cannot continue as valid work | Cancel an attempt while descendants/services exist; exercise harness/runtime restart or auto-resume behavior. | Capability is revoked, managed descendants are terminated/reconciled, and late results cannot regain acceptance authority. Uncontrollable resume modes are not admitted Routes. |
| Residual Docker resources fail closed | Interrupt Docker cleanup and leave attempt-owned resources whose removal cannot be proven. | Shared Worker Docker becomes DIRTY; new Docker work is blocked/requeued until reconciliation or disposable-daemon reset establishes cleanliness. |
| UID reuse cannot leak old resources | Interrupt cleanup with surviving resources owned by the old attempt identity, restart Factory, and attempt to admit another Worker. | The old identity remains retired/quarantined; the new attempt cannot inherit access through UID reuse. Reuse occurs only after resource removal/safe isolation or disposable-environment reset. |

Canonical rules: [Execution](../explanation/execution.md), [Security](../explanation/security.md), ADR-0014, ADR-0019.

## Database migration lineage

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Supported applied history is an ordered prefix of the canonical migration lineage | Apply migration with timestamp 20, then introduce an unmerged migration with timestamp 10. | Integration/admission rejects the lower-ID migration as-is. It is regenerated above the canonical frontier and revalidated; Factory never silently applies `20 → 10` or skips 10 because of a high-water mark. |
| Fresh and sequential upgrade paths converge | Build one database fresh from the current baseline + migrations and another through each declared supported release upgrade path. | Resulting schema/domain state is semantically equivalent under the same declared migration lineage. |
| Pre-v1 consolidation preserves current development data | Bring the development DB to the exact consolidation frontier, checkpoint, generate/verify a baseline, and promote the live DB to the baseline marker. | Existing authoritative data/metrics remain intact; fresh baseline creation reproduces equivalent schema state. |

Canonical rules: [Recovery and upgrades](../explanation/recovery-and-upgrades.md), ADR-0020.

## Empty-host recovery and upgrade cutoff

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| Fresh host can recover the supported Factory state | Destroy local Factory state and recover using only the supported release/container images, Recovery Kit/root material, configured Git remotes, R2, and declared external dependencies. | Recovery restores the exact published authoritative frontier, required historical metrics and recovery-root dependencies, inherited SEND_ARMED/UNKNOWN obligations, and reaches ACTIVE only after validation/reconciliation. |
| Successful new-version publication closes rollback even if reply is lost | Create durable pre-upgrade checkpoint, start upgraded Factory, successfully publish its first new authoritative mutation, then lose the publication/client reply and simulate failure. | Pre-upgrade checkpoint rollback remains closed because publication—not receipt of acknowledgement—is the cutoff. Recovery is roll-forward and same-command resolution discovers the published result. |

Canonical rules: [Recovery and upgrades](../explanation/recovery-and-upgrades.md), [Persistence and durability](../explanation/persistence-and-durability.md), ADR-0016.

## Git reconstruction

| Guarantee | Failure injection / boundary | Required result |
|---|---|---|
| A durable Worker code checkpoint is reconstructible outside the Worker checkout | From a clean client/environment, fetch the exact checkpoint commit and all admitted external Git dependencies such as LFS/submodules. Exercise missing/unsupported dependency configurations. | PriFly labels the code durably recoverable only if the supported repository state can be reconstructed exactly. Unsupported dependency mechanisms fail admission or durability labeling rather than silently producing an incomplete checkout. |

Canonical rules: [Execution](../explanation/execution.md), ADR-0012.

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
