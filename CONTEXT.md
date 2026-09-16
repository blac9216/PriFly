# CONTEXT.md — glossary

Canonical vocabulary. Relationships belong in [the domain model](docs/explanation/domain-model.md); lifecycle states belong in [the state reference](docs/reference/state-machines.md).

## Terms

**PriFly** — The personal, local-first autonomous software factory. not: coding bot.

**Owner** — Human responsible for product direction and consequential authority. not: Worker.

**Pilot** — Disposable conversational client that explains Factory state and translates owner intent into Factory requests. It does not perform project work. not: orchestrator.

**Factory** — Deterministic authority for workflow state, policies, scheduling, records, durability, and external effects. not: Pilot.

**CLI** — Command-line interface to Factory; permissions depend on the caller's capability. not: authority principal.

**Bridge** — Future graphical interface consuming the same records and action semantics. not: separate workflow engine.

**HerdR** — Selected initial session/runtime substrate behind PriFly's runtime adapter. Its runtime facts do not determine workflow completion. not: Factory scheduler.

**Harness** — Program hosting a model-backed coding/agent session. not: Model.

**Model** — Inference service or local model used by a harness. not: Harness.

**Worker** — A bounded AI execution doing a Factory-assigned cognitive job. not: Pilot.

**Worker Role** — Contract describing the cognitive purpose, inputs, outputs, and limits of a Worker, such as Reviewer or Triage. not: Worker Job.

**Worker Job** — Logical Factory request for a bounded role task. not: Worker Attempt.

**Worker Attempt** — One concrete execution of a Job with a distinct identity, Route, runtime, scope, and result. not: Implementation Workspace.

**Route** — Versioned harness/model/effort/account/tool/capacity execution configuration. not: model name.

**Capacity Pool** — Shared scarce capacity consumed by one or more Routes, such as a subscription, API budget, or local compute. not: Route.

**Capability Tier** — Evidence-based relative suitability of Routes for a particular role/task/risk context; not a universal model ranking. not: universal model ranking.

**Worker Runtime Manager** — Factory boundary that provisions and supervises attempts through HerdR and lifecycle adapters. not: semantic Reviewer.

**SandboxProvider** — Replaceable execution isolation/provisioning boundary; its name is not a guarantee of hostile-code containment. not: hostile-code security guarantee.

**Implementation Workspace** — Reusable worktree/environment associated with a Work Item/PR, including permitted caches and workspace services. not: Worker Attempt.

**Workspace Lease** — Exclusive permission for one modifying attempt to use a workspace; not a Factory leader lease. not: Factory ownership lease.

**Review Workspace** — Isolated view/environment for the exact candidate under review. not: mutable Implementation Workspace.

**Worker Docker** — Dedicated disposable Docker execution universe, separate from the daemon hosting Factory. not: Factory host Docker.

**Execution Manifest** — Exact recorded material runtime, harness, model, tooling, and configuration identity for an attempt. not: prompt transcript.

**Context Packet** — Bounded, source-tagged input for an assigned Worker; deeper detail is retrieved progressively. not: entire Factory history.

**Project** — Product/system boundary that may span several repositories. not: Repository.

**Initiative** — Significant outcome within a Project, potentially spanning Epics, repositories, and releases; represented by GitHub milestone(s) when that projection is enabled. not: Epic.

**Epic** — Cohesive workstream/deliverable within an Initiative. not: Initiative.

**GitHub milestone** — Optional repository-scoped provider representation of a PriFly Initiative; not a separate canonical work tier. not: canonical work tier.

**Repository** — Version-controlled code/documentation boundary, not necessarily a complete Project. not: Project.

**Lane** — Scheduling grouping used to reason about dependency progression and safe concurrency. not: org chart.

**Planning Record** — Persistent requirements/design/planning graph for a foundation, capability, or change, with exact phase releases and shared-baseline references; not a delivery-hierarchy tier. not: delivery hierarchy tier.

**Intake** — Pilot-led requirements elicitation and recording before project Worker dispatch is authorized. not: architecture release.

**Phase Release** — Exact-package owner authorization for architecture, delivery planning, or execution within a named scope and budget. not: passing quality gate.

**Requirements Brief** — Inspectable Intake output describing owner needs, goals, behavior, constraints, exclusions, priorities, success, and unresolved questions. not: implementation plan.

**Review Package** — Versioned artifact manifest and source/rendered/diff views, review results, annotations/dispositions, and baseline references submitted at an owner gate. not: unversioned document collection.

**Design Outline** — Architect proposal defining concern coverage, bounded assignments, shared interfaces, dependencies, and synthesis outputs. not: Delivery Baseline.

**Design Assignment** — Bounded Architect job with exact inputs, owned outputs, concerns, dependencies, and scope. not: Work Item.

**Synthesis** — Architect reconciliation of contributions into a coherent design package, including cross-subsystem behavior and unresolved conflicts. not: concatenation.

**Package Annotation** — Owner feedback tied to an exact package revision and relevant content location, with a traced disposition. not: unattributed feedback.

**Goal** — Purpose or desired outcome that justifies work. not: implementation task.

**Requirement** — A behavior or condition the product must satisfy. not: design preference.

**Required Outcome** — Observable condition a Work Item must make true. not: suggested implementation step.

**Constraint** — Non-violation boundary restricting acceptable solutions. not: optional advice.

**Assumption** — A condition believed for planning purposes that has evidence, uncertainty, and recheck treatment. not: proven fact.

**Question** — An unresolved information or decision need with a responsible path. not: Decision.

**Research Claim** — Source-backed factual statement with provenance, freshness, uncertainty, and conflicts. not: model memory.

**Option** — A possible approach considered for a Decision. not: Decision.

**Decision** — Authorized selection among options with rationale, evidence, and scope. not: unapproved suggestion.

**Constitution** — Explicit owner-approved Project invariants; conversational examples do not create it. not: conversation example.

**Design** — Technical/product solution and relationships satisfying requirements within constraints. not: delivery schedule.

**Risk** — Uncertain condition/event with consequences, likelihood/uncertainty, treatment, ownership, and monitoring. not: confirmed defect.

**Planning Concern** — Required area of consideration, such as persistence, security, compatibility, or operation. not: Finding.

**Planning Gap** — A required planning condition not yet sufficiently resolved. not: Work Item.

**Gap Register** — Derived view of the current Planning Gaps and their responsible paths; not a second authoritative database. not: ignored backlog.

**Design Baseline** — Immutable design snapshot passing Design Completeness and approved by the owner with delivery-planning release. not: Delivery Baseline.

**Delivery Baseline** — Immutable plan/decomposition passing Delivery Readiness and owner execution release, including Work Items, estimates, dependencies, and verification relationships. not: Design Baseline.

**Work Proposal** — Potential planned delivery unit not yet released for execution. not: Candidate.

**Work Item** — Executable unit with Goal, Required Outcomes, Constraints, Verification, dependencies, and baseline traceability. not: Worker Job.

**SLICE** — Work Item delivering coherent, evaluable product progress through the relevant layers. not: component-only task.

**ENABLER** — Exceptional enabling Work Item that names its consuming slices rather than pretending to deliver standalone user value. not: unjustified infrastructure work.

**Implementation Envelope** — Authorized scope, paths/areas, protected surfaces, design references, and permitted capabilities for implementation. not: Execution Envelope.

**Execution Envelope** — Cumulative attempts/time/usage/storage/escalation bounds for a scope, including corrections and descendant jobs. not: Implementation Envelope.

**Dependency** — Relationship defining what predecessor condition must be established before a successor action. not: informal ordering hint.

**Blocking Chain** — Traversable sequence explaining why an action waits and what conditions clear its blockers. not: flat priority list.

**Change Request** — Typed proposal to change released planning meaning, with impact analysis and required authority. not: silent baseline edit.

**Candidate** — Exact artifact/code result proposed for acceptance, usually identified by repository and commit. Not a synonym for potential future work. not: Work Proposal.

**Verification** — Method/evidence for establishing a specified Requirement or Outcome; not a mandatory Worker role. not: Worker role.

**Verification Evidence** — Attributable observation of checks/measurements against exact subjects and material conditions. not: unsupported test assertion.

**Review** — Independent evaluation of engineering quality, project conformance, and evidence sufficiency. not: self-approval.

**Review Round** — Factory-assigned exact-candidate review unit linked to attempts/results and any predecessor correction history. not: test invocation.

**Review Conversation Entry** — Canonical ordered verdict, correction, approval, or integration entry rendered to configured issue/PR destinations. not: provider comment as authority.

**Correction Submission** — Before/after candidates and the correcting Implementer's per-finding responses, evidence, unresolved points, and updated PR Draft. not: unstructured fix claim.

**PR Draft** — Implementer-authored structured PR explanation that Factory validates and renders with authoritative metadata. not: native pull request.

**Attack Profile** — Versioned adversarial review techniques/probes supplementing quality rubrics and project conformance; probe outcomes remain explicit. not: unbounded critique.

**Reviewer** — Worker performing a Review; may gather evidence in the same review without triggering another Reviewer. not: merger.

**Implementer** — Worker producing a candidate in new-work or current-correction mode; each current correction is a fresh attempt using the existing Work Item/PR and workspace. not: Fixer.

**Rebaser** — Worker resolving semantic Git conflicts that a mechanical branch update cannot resolve. not: Reviewer.

**Finding** — Evidence-backed observation that may require action; not automatically a Work Item or confirmed bug. not: Work Item.

**Finding Producer** — Authorized originator of a Finding; this is a relationship, not a Worker role. not: disposition authority.

**Proposed Disposition** — Producer's bounded route choice: current correction, follow-up, or planning change. not: effective disposition.

**Current Correction** — Finding identifying an existing acceptance obligation the current candidate fails; uses the tight correction path. not: new follow-up Work Item.

**Follow-up** — Finding not required for acceptance of the current candidate; enters common triage. not: current candidate correction.

**Planning Change** — Finding suggesting governing requirements/design/planning meaning needs revision; no automatic authority to change it. not: local implementation decision.

**Triage** — Semantic assessment of finding relevance, impact, duplicates, grouping, and treatment. Also the name of the Worker role doing that assessment. not: deterministic semantic classification.

**Triage Backlog** — Tracked collection of non-correction Findings undergoing assessment, hold, grouping, planning, work, or final disposition. not: implementation state.

**Hold** — Nonterminal treatment retaining a finding for an explicit reconsideration condition. not: resolution.

**Batch** — Coherent grouping of related Findings into a planning unit; never itself resolution. not: closure.

**Acceptance Certificate** — Immutable binding of exact candidate, baseline, review, rubric evaluations, and evidence for a named acceptance scope. not: self-approval.

**Acceptance Evidence Manifest** — Immutable reference set of required evidence, optional diagnostics, and code roots supporting acceptance. not: raw logs.

**Validation** — Exercise of integrated behavior against intended use in representative conditions. not: candidate review.

**Validator** — Worker executing a bounded Validation Run; reports observations/findings but does not implement fixes. not: Reviewer.

**Validation Target** — Versioned integrated capability/scenario scope requiring intended-use proof. not: Validation Run.

**Validation Run** — A single bounded execution against one or more target revisions. not: Validation Target.

**Pending validation** — Current integrated target lacks required product proof; includes failed targets whose known blocking fixes have now landed and require reevaluation. not: Validated.

**Validation failed** — A required intended-use failure has been demonstrated for the target revision. not: environment interruption.

**Validated** — Required product behavior passed for the recorded target/version/environment; not an eternal status for all future changes. not: Integrated.

**Zero-workaround** — Passing through the supported approved product/operator path, without retrospectively blessing improvised repairs. not: patched demo pass.

**Standards Source** — Pinned official source identity, version, locator, access scope, and status used for criterion derivation. not: unofficial summary.

**Rubric Profile** — Versioned set of general engineering quality criteria for an artifact/work-product type. not: project conformance.

**Rubric Criterion** — Individually addressable question with source mapping, applicability, evidence requirements, and evaluation method. not: workflow rule.

**Rubric Evaluation** — Criterion-level evidence and results for an exact subject/profile version. not: certification.

**Project Conformance** — Adherence to this Project's accepted requirements/design/constraints, evaluated separately from general quality. not: industry quality.

**Workflow Eligibility** — Whether state, authority, independence, evidence, and policy permit the requested lifecycle transition. not: quality rubric.

**Applicability UNKNOWN** — Insufficient basis to decide whether a concern/criterion applies; relevant gates stay blocked. not: criterion failure.

**Criterion UNKNOWN** — Insufficient evidence or unresolved source interpretation to judge a required quality criterion. not: PASS.

**Impact UNKNOWN** — Insufficient coverage to establish safe non-impact; downstream work is conservatively revalidated. not: proven unaffected.

**Provider outcome UNKNOWN** — An external operation may have happened but its terminal result is unproven. not: not sent.

**Attention Item** — Durable information/action/blocker for the owner, independent of notification delivery. not: Owner Action.

**Owner Action** — Immutable consequential package confirmed through owner-control authority, bound to exact scope and revisions. not: Pilot consent.

**Delegation** — Explicit bounded authority for routine decisions/actions without repeated owner confirmation. not: blanket autonomy.

**Provider Broker** — Privileged Factory subsystem performing admitted external operations and reconciliation. not: Worker tool with provider credentials.

**Provider Projection** — External representation of Factory state for visibility; not the canonical workflow record. not: canonical state.

**Provider Projection Profile** — Versioned mapping and enablement of provider objects, fields, relationships, conversation destinations, and synchronization/retirement behavior. not: canonical workflow policy.

**Projection Mapping** — Recorded canonical-to-provider identity and synchronization state for a representation slot and repository/scope. not: canonical subject identity.

**Provider Obligation** — Durable exact intent and lifecycle for an external effect. not: provider response alone.

**SEND_ARMED** — Authoritatively published possible-send state; the request may already be in flight. not: proven sent.

**PR Head** — Current candidate commit on the branch proposed by a GitHub pull request. not: actual merge SHA.

**Base Branch** — Target branch into which the PR is proposed, usually `main`. not: PR Head.

**Integrated** — GitHub has actually merged the PR and Factory has recorded the observed result. not: Validated.

**Release Manifest** — Named scope and exact version/artifact set with required acceptance/publication evidence. not: branch name.

**Closeout** — Accounting for all obligations in a named scope, including findings, validation, information, risks, and publication. not: ticket count.

**Ledger Event** — Immutable semantic fact recorded transactionally with state changes. not: diagnostic log.

**Published Frontier** — Remote recoverable state that the coordination record has made authoritative. not: latest remote bytes.

**Factory Generation** — Ownership epoch used to fence new publication/authorization; distinct from software version. not: time-based leader lease.

**Recovery Root Manifest** — Immutable dependency closure needed to honor a supported checkpoint. not: latest snapshot only.

**Recovery Kit** — Independently retained bootstrap repository locator/revision, initial repository access, age decryption material, and recovery authority needed on a clean host. not: lost-host credential store.

**Migration Baseline/Epoch** — Schema lineage anchor for fresh installs, migration ordering, and supported upgrades. not: license to drop live data.

**Replayability** — Availability of the inputs/prerequisites to reattempt an execution; not a guarantee of identical model output. not: deterministic model regeneration.

**Auditor** — Worker examining cross-cutting/retrospective evidence and recommending investigation or improvement. not: policy adoption authority.

**Curator** — Worker organizing eligible reviewed knowledge into useful durable artifacts. not: automatic memory promotion.

**Arbiter** — Worker giving a bounded recommendation on a semantic dispute; it does not grant owner authority. not: owner authority.
