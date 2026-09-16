# States and uncertainty domains

Kind: reference

### State domains

| Domain | Values or conditions used in this design | Meaning |
|---|---|---|
| Planning phase | `INTAKE`, `ARCHITECTURE`, `DELIVERY_PLANNING`, `EXECUTION_RELEASED`, `CLOSED`, `CANCELLED` | A record advances only through the applicable release. Awaiting-owner and engineering-gate status are recorded separately. |
| Work Item implementation | `PROPOSED`, `READY`, `IMPLEMENTING`, `IN_REVIEW`, `ACCEPTED`, `MERGE_PENDING`, `INTEGRATED`, `CANCELLED` | Where the implementation/PR stands. `PROPOSED` is planned but not execution-released; `READY` is released and otherwise eligible. Blocking reasons are recorded separately rather than erasing the phase. |
| Worker Attempt | `ADMITTED`, `RUNNING`, `DRAINING`, `TERMINATED` | Execution lifecycle; terminal result separately records completed, failed, cancelled, or interrupted. |
| Validation Target | `NOT_REQUIRED`, `PENDING_VALIDATION`, `VALIDATION_FAILED`, `VALIDATED` | Confidence in the target's integrated intended behavior. |
| Validation Run | `QUEUED`, `RUNNING`, `COMPLETED`, `INTERRUPTED` | A particular execution. A completed run may contain different outcomes for different targets. |
| Finding proposal | `CURRENT_CORRECTION`, `FOLLOW_UP`, `PLANNING_CHANGE` | The producer's only three routing proposals. |
| Backlog treatment | awaiting triage, held, grouped, released to planning, work in progress, awaiting authority, resolved | Tracking treatment, not a second implementation workflow. |
| Concern applicability | `APPLICABLE`, `NOT_APPLICABLE`, `UNKNOWN` | Whether a concern applies; Factory establishes the effective value from policy and evidence. |
| Quality criterion result | `PASS`, `FAIL`, `NOT_APPLICABLE`, `UNKNOWN` | What the evidence establishes for one pinned criterion. |
| Change impact | `AFFECTED`, `PROVEN_UNAFFECTED`, `UNKNOWN` | Whether changed upstream meaning affects a downstream subject. |
| Provider obligation | `PREPARED`, `SEND_ARMED`, `SUCCEEDED`, `FAILED`, `UNKNOWN` | The lifecycle of an external operation; uncertainty after send remains first-class. |
| Command disposition | terminal `RELEASED` or definitively `REJECTED`; otherwise `OUTCOME_UNRESOLVED` | A missing reply is not a final rejection. |

`INTEGRATED` is not a claim of product validation or release. A GitHub issue may be closed while its associated target is still pending validation. The UI must make that distinction visible.

## Transition guards and invalidation

Factory alone applies transitions after structural/domain checks and authoritative publication.
Each transition records exact subject/revision, cause, authority, evidence and applicable policy.
Blocking reasons do not erase the underlying lifecycle state; clearing a blocker does not itself
grant missing authority. No unlisted edge is inferred from a diagram's visual shorthand.

| Domain/path | Required guard or effect |
|---|---|
| Intake → architecture → delivery planning → execution released | Each edge needs its exact owner Phase Release and applicable engineering gate. Package revision invalidates mismatched confirmation. See [Planning policy](planning-policy.md). |
| PROPOSED → READY | Execution release covers the exact Work Item/baseline, dependencies and gates permit it, and a valid envelope exists. Merely creating a provider issue does not release work. |
| READY → IMPLEMENTING → IN_REVIEW | Scheduler admission and exclusive writer handoff precede implementation. Exact candidate, structured results/evidence and PR Draft must be admitted; Factory publishes the candidate branch and creates/updates the PR before review dispatch. |
| IN_REVIEW → IMPLEMENTING | A current correction starts a fresh Implementer attempt for the same Work Item/PR and reusable workspace after the prior writer is stopped. The old reviewed subject stays immutable. Planning-artifact corrections return to their producing role. |
| IN_REVIEW → ACCEPTED | Fresh independent review plus required credible evidence, quality/conformance results and finding dispositions; evidence/manifest publication precedes certificate release. |
| ACCEPTED → MERGE_PENDING → INTEGRATED | Current acceptance usability and all admitted PR checks/native review/authority requirements hold. Only observed successful merge establishes INTEGRATED and actual merged SHA. UNKNOWN send retains conflict scope. |
| Candidate/base changes before merge | Recompute eligibility under the qualified profile. Changed candidate receives fresh review; relevant stale acceptance is unusable. Base changes cannot be hidden as expected-base CAS. See [Git integration](../explanation/git-integration.md). |
| Pause/cancel | Pause records a blocker/dispatch hold; cancellation revokes grants, drains/reconciles attempt-owned resources and forbids late-result authority. Retained workspace services have separate lifecycle ownership. Cancellation is not fulfillment. |
| Attempt ADMITTED → RUNNING → DRAINING → TERMINATED | Runtime admission, cancellation/completion and proven cleanup/reconciliation control the path. Pre-run failure/cancellation can terminate through draining. Result disposition is separate; runtime unknown is not success. |
| Target PENDING_VALIDATION → VALIDATED or VALIDATION_FAILED | A completed applicable Run supplies sufficient observations for the exact target revision. Failure requires credible product-failure evidence; missing/infrastructure evidence leaves confidence unresolved/pending. |
| Target VALIDATION_FAILED → PENDING_VALIDATION | All target-blocking Findings are resolved through governed work/disposition; target re-enters the normal scheduler, not a private fix-wave. Revised target scope/versions invalidate incompatible old confidence. |
| Target NOT_REQUIRED | Explicit applicable policy justifies no validation obligation for this revision; it is not an implicit pass or a response to missing resources. |
| Provider PREPARED → SEND_ARMED → terminal/UNKNOWN | Publication precedes possible send. UNKNOWN is reconciled only with admitted terminal evidence or authorized disposition; absence is not non-execution. |
| Scope → CLOSED | Release/closeout accounts for validation, publication and all surviving obligations. Held, batched or planning-only work is nonterminal; reduced/cancelled scope is recorded honestly. |

Detailed transition ownership and adverse paths live in [Review](../explanation/review.md),
[Findings and triage](../explanation/findings-and-triage.md), [Validation](../explanation/validation.md),
[Providers](../explanation/providers.md) and [Release and closeout](../explanation/release-and-closeout.md).
Generation activation and upgrade rollback cutoff are separate state domains governed by
[Persistence](../explanation/persistence-and-durability.md), [Recovery](../explanation/recovery.md)
and [Upgrades](../explanation/upgrades.md), not Work Item transitions.

### What UNKNOWN means

**Applicability UNKNOWN:** the system lacks sufficient policy coverage or evidence to decide whether a concern applies. It blocks the relevant planning gate.

**Criterion UNKNOWN:** a required quality judgment cannot be established from the evidence or permitted source interpretation. It blocks promotion when that criterion is required.

**Impact UNKNOWN:** non-impact has not been established. The affected downstream scope is conservatively held for revalidation.

**Provider outcome UNKNOWN:** an operation may have executed but its terminal outcome is unproven. The conflicting resource scope remains reserved.

**Runtime state unknown:** the runtime cannot classify a session confidently. It is an operational signal, not permission to declare a Worker complete. HerdR itself documents that its `unknown` status does not prove completion [S03](source-register.md#source-s03).

**Quota unknown:** the provider has not exposed reliable remaining capacity. Factory must not turn that into a fabricated token balance or zero usage.

Diagrams and reports must qualify these values with their domain. “UNKNOWN” by itself is not an adequate owner-facing explanation.
