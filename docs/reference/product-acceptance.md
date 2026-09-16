# Product quality requirements and acceptance

Kind: reference

## Nonfunctional requirements and product acceptance

### Quality attributes of PriFly itself

PriFly is subject to the same discipline it will apply to managed Projects. Its requirements must be observable and testable, and performance targets must be selected for a declared workload/environment rather than invented after a benchmark.

| ID | Quality requirement | Measurement or acceptance basis |
|---|---|---|
| NFR-01 | Published semantic history survives declared local-host loss. | Destroy local state after acknowledged commands; recovered state contains those results and historical metrics. |
| NFR-02 | Stale attempts and capabilities cannot advance work. | Submit results from cancelled/superseded attempts and revoked workspace writers; admission rejects them. |
| NFR-03 | Evaluation is auditable. | Every consequential verdict resolves to exact subject, criteria/profile versions, evidence, evaluator, and authority. |
| NFR-04 | Repeated client/provider ambiguity is handled safely. | Lost-response tests do not create terminal false rejection, duplicate uncontrolled effects, or missing conflicts. |
| NFR-05 | Operator status is understandable. | An unfamiliar reviewer can trace a displayed blocker to its condition, owner, evidence, and downstream effect. |
| NFR-06 | The control plane retains operational headroom. | Resource-pressure tests stop unsafe new admission while preserving state publication and cancellation/repair paths. |
| NFR-07 | Execution is economical without weakening quality. | Evidence and workspace reuse are observable; no unconditional duplicate suite or correction-environment rebuild is in the normal path. |
| NFR-08 | Interfaces are compatible and versioned. | Unsupported schema/protocol combinations fail clearly; historical records remain interpretable. |
| NFR-09 | Setup and recovery are reproducible. | A clean declared host can start or restore using packaged artifacts and independent recovery material. |
| NFR-10 | Project data is minimized in uncontrolled output. | Secret/log fixtures prove privileged credentials are not included in standard packets, logs, or diagnostic exports. |
| NFR-11 | Documentation represents the delivered product. | Supported setup, validation, and recovery instructions are exercised against the release under test. |
| NFR-12 | Growth does not silently compromise correctness. | Declared workload/load tests measure query, publication, scheduling, and retention behavior; overload degrades explicitly rather than losing obligations. |

Numeric query-latency, publication-throughput, maximum-scale, storage-cost, and recovery-time targets require a representative workload and owner-approved baseline. The invariant is not that they remain unspecified forever; it is that dependent implementation/release evaluation cannot quietly choose favorable values after observing results. [Section 31](deployment-parameters.md#unselected-parameters-and-admission-dependencies) assigns those parameter decisions.

### Acceptance scenarios

These scenarios define observable product behaviors. They are not claims that tests already exist. An implementation plan must map each applicable scenario to executable evidence and the requirement IDs in its owning section.

| ID | Scenario | Required result |
|---|---|---|
| AT-01 | Start a replacement Pilot while several jobs and owner questions are active. | It reconstructs goals, jobs, pending discussions, and blockers from Factory without the prior chat. |
| AT-02 | Owner uses an exploratory example during a design discussion. | No Constitution or consequential decision is silently adopted; relevant tentative meaning is explicitly represented. |
| AT-03 | Pilot tries to confirm an owner-only action. | Capability denied; the human confirmation surface can confirm only the exact current package. |
| AT-04 | Owner confirms an action after its referenced decision changed. | Stale confirmation rejected and a new package is required. |
| AT-05 | A Requirement contains no objective way to establish completion. | Requirement/verification evaluation fails or remains criterion-unknown; affected delivery is not released. |
| AT-06 | An applicable quality measure lacks its project threshold. | Planning records the gap; Reviewer cannot invent a threshold during acceptance. |
| AT-07 | Official source detail is unavailable and material ambiguity remains. | The criterion is unknown with a source-access reason; no fabricated standard clause or pass. |
| AT-08 | A Work Item is not traced to a baseline obligation. | Delivery Readiness identifies the orphan rather than releasing unrelated work. |
| AT-09 | A mandatory concern is marked not applicable without required evidence/authority. | Effective applicability does not clear the gate. |
| AT-10 | Several ready Work Items are independent but one shared interface is contested. | Unaffected work can run; conflicting work observes explicit dependency/collision controls. |
| AT-11 | Capacity telemetry does not expose subscription remaining usage. | Status reports unknown/estimated as appropriate, not a fabricated numeric allowance. |
| AT-12 | A runtime launch times out after possibly creating a session. | Factory reconciles attempt/session identity rather than blindly launching a duplicate prompt. |
| AT-13 | Implementer provides sufficient attributable evidence for candidate C. | Reviewer can accept the evidence without automatically repeating the checks. |
| AT-14 | Reviewer elects to run a targeted test. | The same Reviewer continues and returns its verdict; no review-of-the-test recursion. |
| AT-15 | Reviewer identifies a legitimate current correction. | A fresh Implementer in current-correction mode receives the original Work Item/PR and retained workspace; no unrelated new Work Item is created. |
| AT-16 | Old Implementer still has a writing process when Implementer is ready. | Workspace handoff waits or quarantines; two writers are not admitted. |
| AT-17 | Implementer changes the candidate from C1 to C2. | C1 approval does not authorize C2; a fresh review assesses C2 with prior findings visible. |
| AT-18 | Reviewer reports an unrelated small improvement. | It enters common triage as follow-up and does not automatically block the current PR. |
| AT-19 | Several related held findings collectively form a coherent change. | Triage can batch them with preserved member IDs and required outcomes. |
| AT-20 | A serious finding exists below the normal batch-size threshold. | Its criticality/blocking treatment can release it promptly; batching does not suppress urgency. |
| AT-21 | A planning-change finding reveals current baseline invalidity. | Relevant work is blocked/revalidated through the change path; no automatic Implementer redesign. |
| AT-22 | A PR's base moves without a conflict. | Factory follows the admitted update/check policy; it does not invoke an AI Rebaser by default. |
| AT-23 | A real Git conflict occurs. | Rebaser resolves within scope, returns new candidate/evidence, and cannot approve or merge it itself. |
| AT-24 | A Worker or integration helper attempts a direct target-branch push. | That is not an admitted integration path; only the qualified GitHub PR route can complete work. |
| AT-25 | PR head changes after Factory's final review observation. | The expected-head/provider protection path prevents accepting a different head silently. |
| AT-26 | Base/check state changes concurrently with PR merge. | The admitted repository profile demonstrates its promised reject/recheck behavior; no unsupported expected-base guarantee is claimed. |
| AT-27 | GitHub merges but the receipt is lost. | Provider obligation remains possibly sent/unknown until reconciled; Factory does not request an unsafe duplicate effect. |
| AT-28 | Merged work requires intended-use validation. | It is integrated and its target is pending; the UI does not call it product-validated. |
| AT-29 | Validator needs an undocumented manual repair to finish a story. | The scenario does not pass; observations and findings preserve the repair and original failure. |
| AT-30 | Validator cannot start because an authorized test credential is unavailable. | The run is blocked/incomplete; targets stay unproven rather than automatically product-failed. |
| AT-31 | Validator demonstrates a product bug. | Finding enters common triage with target/blocking provenance and explicit scheduling weight. |
| AT-32 | One of three blocking validation defects is fixed. | Target remains failed while two known blockers remain. |
| AT-33 | All known blocking validation fixes integrate. | Target returns to pending and contributes to normal scheduling metrics; the normal scheduler decides the next validation run. |
| AT-34 | An old passing run reports after the target changed. | It is historical evidence only and cannot clear the newer target revision. |
| AT-35 | Closeout is requested with held, batched-only, or planned-only findings. | Scope remains blocked until obligations are actually completed or legitimately resolved. |
| AT-36 | A duplicate finding points to another still-open blocking defect. | Closing duplicate bookkeeping does not clear the surviving dependency. |
| AT-37 | An accepted planning change affects only one lane with proven bounded impact. | Affected/impact-unknown subjects revalidate; proven-unaffected work continues. |
| AT-38 | Publication succeeds but client acknowledgement is lost. | Same command resolves to its original released result; no false terminal rejection. |
| AT-39 | Explicit takeover races with publication of the next transaction. | CAS ordering preserves acknowledged history; losing old generation cannot publish a new authoritative result. |
| AT-40 | A supported frontier ages through replica compaction/retention. | Exact supported state remains recoverable, not merely the latest state. |
| AT-41 | Required evidence upload fails before acceptance. | Acceptance is not released. |
| AT-42 | Cleanup runs while an old recovery root remains supported. | It cannot delete the last required code/evidence/key dependency. |
| AT-43 | Canonical database is lost with the host. | Recovery restores published state, metrics, obligations, required evidence, and code checkpoints under the declared assumptions. |
| AT-44 | Upgrade fails after new authoritative publication but before response delivery. | Pre-upgrade rollback stays closed; repair proceeds forward. |
| AT-45 | A lower timestamp migration arrives after a later canonical migration. | It fails admission as-is; pre-merge regeneration and ordered-lineage testing are required. |
| AT-46 | A pre-v1 baseline consolidation is applied to the current development database. | Data and historical metrics remain intact; fresh and promoted schemas match the declared frontier. |
| AT-47 | Attempt cancellation leaves restartable Docker resources or old UID ownership. | Conflicting reuse is blocked until cleanup, safe isolation, or environment reset establishes safety. |
| AT-48 | A cheaper Route requires more rescues and later product fixes. | Experiment accounting includes them; accepted-only token savings cannot claim overall superiority. |
| AT-49 | A maintenance update changes the harness used in an experiment. | Execution identities and comparison limits reflect the update; security maintenance is not delayed for obsolete performance. |
| AT-50 | A release publishes one repository/artifact but another publication is unresolved. | Release state records partial publication and retains the unknown obligation; no atomic-success fiction. |
| AT-51 | Owner mentions an unformed feature idea during conversation. | Pilot records draft Intake and asks requirements questions; no project Worker, Epic, milestone, issue, or board entry is created automatically. |
| AT-52 | Owner confirms an exact requirements-to-architecture package. | Only its architecture/supporting-investigation scope becomes eligible; implementation and delivery-planning dispatch remain unauthorized. |
| AT-53 | Design Completeness passes but the owner has not approved design/released delivery planning. | Factory waits at the owner release, despite the passing engineering gate. |
| AT-54 | Owner marks up a package and later confirms the old package digest. | Annotations retain their locations/dispositions; the revised package is inspectable and the stale confirmation cannot approve it. |
| AT-55 | A new-project architecture phase produces a design package. | The package includes its PRD, manifest-governed design set, C4/glossary/domain/contracts/ADRs as applicable, source/rendered views, and review evidence. |
| AT-56 | Owner requests a feature in an existing product. | The package references the existing baseline and supplies a focused design/doc patch with necessary ADRs and impact analysis, not an unrelated replacement product design. |
| AT-57 | Two design assignments propose conflicting shared interfaces. | Synthesis records and resolves or escalates the conflict; Factory cannot silently concatenate or last-write the result into an approved package. |
| AT-58 | Estimator receives a request to invent missing scope or split work. | It reports the missing/incorrect input to Planner rather than performing decomposition; execution estimates consume defined scope and predicted footprint. |
| AT-59 | A Work Item has little history or unavailable token telemetry. | Its estimate states provisional/default basis, sample limits and time uncertainty; token usage is explicitly unknown rather than fabricated. |
| AT-60 | A Worker requests missing information without a recognized job kind. | Factory returns a routing/contract question instead of guessing Scout versus Researcher or dispatching an unrestricted agent. |
| AT-61 | Owner runs the Pilot entry path while a Worker pane is focused. | Pilot attaches to the owner session and does not send input, interrupts, or focus changes to the Worker. |
| AT-62 | Owner types or sends control keys while watching a Worker. | The default observation view cannot deliver input or takeover authority to that Worker. |
| AT-63 | HerdR restarts with previously saved Worker agent sessions. | Automatic managed-agent resume is disabled; Factory reconciles attempt validity before resuming or redispatching. |
| AT-64 | A clean host starts with the private bootstrap repository and independent access/key material. | It fetches the selected revision, validates manifest/secrets, provisions the declared stack, and distinguishes new initialization from recovery. |
| AT-65 | Bootstrap decryption fails, identity mismatches, or remote state is inaccessible. | Startup reports the specific error and does not initialize an empty replacement Factory or expose plaintext secrets. |
| AT-66 | Bootstrap secrets rotate while an old recovery root remains supported. | Independent recovery still works with retained compatible decryption material or a verified rewrap path. |
| AT-67 | Implementer submits a candidate without required PR Draft fields. | Submission is incomplete; Factory does not fabricate the missing explanation or dispatch review against an incomplete PR. |
| AT-68 | A valid candidate is submitted for review. | Factory confirms the exact remote head, creates or updates its PR with the admitted draft, records the mapping, and then dispatches Reviewer. |
| AT-69 | C1 receives changes requested, a fresh Implementer submits C2, and C2 is approved. | Canonical records and configured PR/issue views preserve the ordered verdict, per-finding correction response, new review, and eventual observed merge. |
| AT-70 | A repository requires a native approval and Factory opened the PR with its author identity. | A comment cannot satisfy the requirement; the profile needs an eligible distinct reviewing identity and valid native review before merge. |
| AT-71 | A multi-repository Initiative is projected to GitHub. | Its enabled milestones are mapped by Initiative and repository; Epics do not become milestones and provider completion does not bypass Initiative closeout. |
| AT-72 | Owner disables boards but retains issues and review summaries. | Authorized planning/execution continues with canonical dependencies and the remaining projections intact; no board is required implicitly. |
| AT-73 | Delivery planning publishes issues before execution release, or someone moves a card to Ready. | Canonical work stays PROPOSED until Delivery Readiness and exact-package owner execution release establish eligibility. |
| AT-74 | A projection is disabled and later re-enabled. | Existing provider objects are not implicitly deleted and recorded mappings are reconciled before any recreation or historical backfill. |
| AT-75 | An optional board update lags while a required native review/check is missing. | Lag is visible; the optional view does not unnecessarily block work, but the missing merge prerequisite still blocks integration. |
| AT-76 | A dispatch names an unsupported job kind or unversioned prompt/output contract. | Admission fails; every enabled variant resolves to pinned role/job instructions, schema, tools, and stopping conditions. |
| AT-77 | Reviewer skips a mandatory attack probe or reports a style preference as a hard defect. | The skip remains an unmet obligation, and Findings require an applicable criterion/requirement or demonstrated defect rather than preference alone. |
| AT-78 | The PRD/design package is rendered for owner review. | Every Mermaid block parses and renders in the qualified renderer, and routing/sequence labels remain readable rather than overlapping or failing. |
| AT-79 | Owner registers a repository without authorizing inventory or architecture. | Registration records identity and configuration only; project Worker dispatch still waits for bounded investigation or phase release. |
| AT-80 | A provider comment requests changed scope or an external issue is closed. | The interaction remains attributed input and follows admission/authority checks; neither text nor closure silently changes requirements, releases a phase, or satisfies canonical closeout. |

### Testing layers for PriFly

Unit/domain tests establish deterministic state and policy behavior. Contract tests establish schemas, actor boundaries, result finality, and provider/runtime adapter semantics. Integration tests exercise the actual selected SQLite, Litestream, R2, GitHub, HerdR, and Docker combinations. Fault injection establishes crash/lost-response/retention behavior. End-to-end product validation exercises real owner journeys using synthetic projects and controlled environments.

Semantic quality evaluation also needs calibration fixtures: strong and deficient requirements, incomplete plans, ambiguous findings, misleading test evidence, and actual product defects. Those fixtures test whether the chosen Worker profiles and rubrics produce useful judgments. They do not prove perfect semantic completeness.

The standard for “done” is the scenario's observable result against a known configuration, not merely adding a test file named after the requirement. Every claim of conformance must identify the executed evidence and its exact product/runtime tuple.

### Initial measurement dashboard

The initial dashboard/briefing should expose delivery state counts, pending/failed validation targets and age, open/held triage counts and age, correction rounds, evidence reuse/rerun rates, workspace setup/reuse, per-Route observed usage, provider lag/ambiguity, and recovery health. These are useful operating measures before experiments have enough observations for confident conclusions.

No product-wide quality score is required. A single score would conceal critical failures behind easy passes. The owner sees criterion-level blockers and meaningful outcome measures.
