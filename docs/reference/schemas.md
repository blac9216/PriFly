# Canonical record contracts

Kind: reference

## Common identity and reference rules

Every canonical record identifies its kind/schema version, stable scoped ID, provenance and exact
subject. Mutable state carries a monotonic revision used for optimistic concurrency; immutable
content carries an exact version/digest and is never overwritten to express later validity.
References name kind and ID plus revision/version/digest where a decision depends on exact content.
Unqualified “latest” references cannot serve as acceptance or release evidence.

Factory stamps authenticated actor, Worker Attempt, Route, causation and canonical sequence from
admitted capabilities and observations. Producer payloads cannot supply authority or fabricate
provider IDs. Timestamps describe observations; Ledger sequence orders authoritative history.
External artifact references include content identity, size/kind, location, access conditions,
required/optional status and retention/root treatment; a mutable URL alone is insufficient.

Structural validation checks types, required fields, closed enums and declared extension points.
Domain validation separately checks authority, exact references, state transitions, scope,
dependency cycles, evidence credibility and durability, freshness and cross-record consistency.
Both must pass. Unsupported semantic versions/fields fail admission; historical immutable
records retain their original interpretation through schema/migration evolution.

Executable schema locations, ID encodings and SQL/Go layouts remain [RP-18](deployment-parameters.md#fixed-direction-versus-unselected-parameters).
They cannot postpone the semantic contracts here. Real producers/consumers require executable
schemas and positive/adverse fixtures before admission.

### Canonical record families

Records are organized by meaning, not assumed database tables. Mutable objects have revision-controlled lifecycle projections. Immutable objects retain exact content identity and may acquire separate support/validity state.

| Group | Principal records and important relationships |
|---|---|
| Identity and hierarchy | Factory, Project, Repository, Initiative, Epic, Lane, actor/capability, delegation. GitHub milestone identity belongs to the Initiative provider mapping. |
| Planning | Planning Record/phase, requirements brief, Phase Release, Design Outline/assignment/contribution, Review Package/manifest, Package Annotation/disposition, Goal, Requirement, Constraint, Question, Research Claim, Option, Decision, Design, Risk, Planning Concern, trace edge, Design/Delivery Baseline, Change Request. |
| Quality | Standards Source, Rubric Profile, Criterion, profile binding, criterion evaluation, Rubric Evaluation, project-conformance result. |
| Delivery | Work Proposal, Work Item, Implementation Envelope, Execution Envelope, Worker Job/Attempt, Implementation Workspace, workspace lease/resource inventory, Candidate, Verification Evidence, PR Draft, execution Estimate, versioned role/job prompt bindings. |
| Review | Review Round/Result, Attack Profile/probe outcome, Finding, Correction Submission/finding response, Review Conversation Entry, immutable Acceptance Certificate and current usability projection. |
| Triage | Finding assessment, disposition history, hold/reconsideration condition, batch membership, planning/work links, surviving obligations. |
| Validation | Validation Target/revision, Validation Run, scenario observation, per-target result, blocking finding links. |
| Publication | Provider Projection Profile/version, desired projection/object mapping and sync state, Provider Obligation/Observation, PR/review/comment projections, merge receipt, Release Manifest, release state, Closeout Record. |
| Recovery | Published Frontier, coordination record, Recovery Root Manifest, support/retirement projection, secret/key references, migration ledger. |
| Learning | Metric Observation, experiment assignment/result, Observation, Lesson Candidate, reviewed Lesson, Recommendation, adopted policy version. |

A Finding and a Work Item are never the same object merely because GitHub presents both through issues. A target name alone is not a Validation Target revision. A runtime pane is not a Worker Attempt. These identities must remain traceable through projections.

## Minimum semantic field groups

| Record family | Required meaning and invariants |
|---|---|
| Planning graph | Exact Planning Record/phase, owner need and scope, typed Goal/Requirement/Constraint/Question/Claim/Option/Decision/Risk nodes, typed upstream/downstream edges, provenance and applicability. Material unknowns and decisions have responsible paths; baseline membership is exact. |
| Baseline | Immutable manifest of approved planning records/artifacts, source package and Phase Release, policy/profile versions, thresholds, scope/constraints, evidence and predecessor/change relationships. Design and Delivery Baselines are distinct. |
| Work Item | Goal, observable Required Outcomes, Constraints, Verification, kind, baseline trace, dependencies, predicted footprint/Lane, Implementation Envelope, cumulative Execution Envelope and current state/revision. Blockers are separate links/reasons. |
| Execution Envelope | Owning scope, authorized attempt/time/usage/storage bounds, reserves, consumed and committed costs across descendants/corrections/reviews, exhaustion behavior and extension authority. No reset on a fresh attempt. |
| Worker Job/Attempt | Logical job and exact attempt identities, role/job contract versions, inputs/outputs, Route/manifest, grants/scope, workspace/lease, lifecycle and terminal result, usage/evidence, predecessor and cancellation/supersession. Runtime completion alone is not semantic success. |
| Workspace/lease | Work Item/PR/repository identity, worktree/configuration, retained services/resources and ownership, current exclusive writer lease, stopped/revoked writer evidence and cleanup/quarantine status. Review views have exact isolated subject identity. |
| Candidate/evidence | Exact artifact kind/content or repository commit, Work Item/producer/baselines, relevant base/environment/configuration, actual/skipped checks, outcome/limitations and durable evidence references. Candidate is not future-work intent. |
| Quality definition/evaluation | Versioned source identity/access/locator, rubric and criterion descriptors, separate policy binding, exact evaluated artifact/phase, applicability/result/reason/evidence, evaluator/independence, unresolved interpretations and provenance. |
| Finding/triage | Exact subject, producing role/attempt, violated concern/criterion, reproducible failing scenario and evidence, severity/reason, one of three proposed dispositions, effective treatment/history, blocker scope, duplicate survivor, hold/reconsideration or batch/planning/work links and closure authority. |
| Validation Target/Run | Exact target revision/intended behavior/version set, scenarios and target blockers; separate run inputs, environment, reservations, actual observations, per-target conclusions and incomplete/unknown reasons. Old observations do not validate changed targets. |
| Acceptance Certificate | Exact accepted candidate and policy/baseline/evaluation/review/evidence bindings; separate mutable usability projection. Required evidence must be published and protected. See [Acceptance contract](acceptance-contract.md). |
| Attention/Owner Action/delegation | Durable attention subject/urgency/next action and deferral; immutable consequential action package with exact confirmation; scoped grants, limits, expiry/version and protected surfaces. These are not interchangeable authority objects. |
| Route/capacity | Immutable harness/model/effort/account/tool and capability version, admitted controls, contextual fitness evidence and capacity pools; observed quota provenance/freshness/uncertainty, reservations and cumulative usage. Unknown quota is not zero. |
| Provider obligation/observation | Exact operation profile, desired mutation/preconditions, correlation/conflict scope, generation/authority, possible-send state and publication evidence, admitted observations, terminal receipt or unresolved reason. Projection mapping does not replace this safety record. |
| Publication/recovery | Published application frontier with exact replica restore position, coordination object version/generation and predecessor; Recovery Root Manifest dependency closure and separate support/retirement state. Upload alone is not authoritative publication. |
| Release/closeout | Exact repository version set, eligible target/evidence references, provider publication receipts/partial outcomes, scope and surviving obligations, authorized scope/risk dispositions and explicit fulfillment verdict. |
| Metrics/experiments/learning | Attributable observations and denominators, precommitted assignment/treatment and eligibility, all assigned outcomes including rescue/failure/delayed validation, limitations; reviewed lesson/recommendation and separate adopted policy version. No automatic self-modification. |

### Packages, estimates and review history

The new records use versioned JSON with JSON Schemas, closed semantic fields/enums, exact references, and Factory cross-record validation. The field groups below specify required meaning; implementation supplies executable schemas and fixtures before admitting a producer/consumer. These are not instructions to parse Markdown headings or provider comments as primary data.

| Record | Required field groups and relationships |
|---|---|
| Phase Release | Owner Action/confirmation, package ID/revision/digest, Planning Record revision, authorized phase/scope, budget, limitations, baseline dependencies, validity/supersession. |
| Review Package | Package kind, exact inputs and baseline commits, manifest of artifact paths/digests/kinds, rendered/source/diff references, required reviews, annotations/dispositions, unresolved questions, proposed next release. |
| Design Assignment | Outline revision, concern and output ownership, inputs/shared contracts, dependencies, required outputs, allowed scope and envelope, synthesis destination. |
| Estimate | Defined Work Item/batch revision, predicted footprint input, Route/comparables/sample size, time/token ranges and units, method, assumptions, exclusions, confidence/limitations, overhead separation, re-estimate predecessor. |
| PR Draft | Candidate and Work Item references, template version, title, motivation/summary, outcome coverage, test/evidence/limitation fields, validation expectations, documentation and related-record links. |
| Review Result | Round and attempt, exact candidate, governing baselines/profiles, quality/conformance results, accepted/new evidence, verdict, Finding IDs, probe outcomes, prior-finding dispositions, limitations. |
| Correction Submission | Producing attempt, prior Review Result/round, Work Item, before/after candidates, per-Finding response and claimed treatment, commit/location/evidence references, unresolved/disputed points, updated PR Draft. |
| Review Conversation Entry | Stable entry ID, kind, Work Item, review round where applicable, exact subject/transition, semantic author, canonical sequence/causation, payload reference, renderer version, intended destinations. |
| Provider Projection Profile | Provider/capability version, project/repository scope, per-representation enablement/mapping, field ownership, relationships, conversation destinations, required versus optional publication, synchronization/retirement policy. |
| Projection Mapping | Canonical subject and representation slot, profile version, repository/provider identity, desired and observed revisions, operation/correlation IDs, synchronized content digest, lag/drift/unknown state. |

A valid schema is necessary but insufficient. Factory also validates that a correction addresses the named reviewed candidate, findings belong to the appropriate scope, a verdict has complete mandatory evaluations/probes, and the owner's release still matches its package. Conversation sequence comes from the canonical Ledger, not provider timestamps or comment order. Actual provider IDs are populated only from admitted observations; a Worker cannot invent them in its output.
