# Canonical schema contracts

Kind: reference

PriFly's durable semantic boundaries are versioned structured JSON. JSON Schema validates structure; Go domain validation enforces invariants that require state, authority, graph, repository, or cross-object knowledge.

This document defines the **minimum canonical semantic shape** that implementation schemas must preserve. It is intentionally not a database schema, Go type specification, or promise about how aggregates are normalized in SQLite.

## Schema design rules

### Identity and naming

Canonical schema identity uses:

```text
<family>/vN
```

Examples:

- `work-item/v1`
- `owner-action/v1`
- `provider-obligation/v1`
- `acceptance-certificate/v1`

Command and Event logical types are independently versioned, for example `work.pause/v1` and `work.paused/v1`, while their common envelope schemas remain `command/v1` and `event/v1`.

### Closed authoritative objects

Authoritative boundary schemas are **closed by default**: unknown semantic fields are rejected unless a schema explicitly declares an extension map. This prevents a producer from smuggling unvalidated meaning into canonical state.

Adding a semantic field to a closed authoritative object requires a new schema version unless the existing schema explicitly reserved that extension point.

### Immutable subject versus mutable lifecycle

When PriFly says a certificate, manifest, baseline, Route version, or other subject is **immutable**, fields that define the semantic subject are never edited in place to represent later lifecycle progress.

Mutable lifecycle facts live in a separate revisioned status/admission/projection object or in later immutable records that reference the earlier subject. Examples:

- an `acceptance-certificate/v1` never gains a different integration commit or a later `STALE` flag; `acceptance-status/v1` records current validity and `integration-certificate/v1` binds an exact later integration subject;
- a `recovery-root-manifest/v1` never changes from supported to retired; `recovery-root-status/v1` records current support/retirement state;
- a `route/v1` version never mutates from admitted to disabled; `route-admission/v1` records current policy/admission state for that immutable Route version.

This separation keeps historical evidence byte/semantic identity stable while still allowing Factory lifecycle state to evolve.

### IDs

IDs are opaque stable strings. Consumers must not infer:

- creation time;
- object type;
- sort order;
- database key layout;
- host/generation identity;

from the encoding of an ID.

### Revisions

Mutable canonical objects carry a positive integer `revision`.

- revision starts at 1;
- every semantic mutation to that object produces a strictly greater revision;
- equality is suitable for stale-state preconditions;
- revisions across different objects are not comparable;
- derived caches/ephemeral telemetry do not cause canonical revision increments.

Immutable records may omit revision or fix it at 1 depending on their family; their content identity is their stable object ID/digest relationship.

### Time

Timestamps are RFC 3339 UTC strings. Time is descriptive/provenance data, **not workflow ordering**. Ordering is established by revisions, dependency edges, Ledger positions, Factory Generation, or Published Frontier as appropriate.

### Optional versus null

An absent optional field means the fact/value is not present in this schema instance. `null` is permitted only where the schema gives it a specific semantic meaning. Producers must not interchange absent and null casually.

### Enumerations

Enums are closed. Unknown enum values are rejected rather than silently treated as a default. A new value that changes consumer behavior requires an appropriate schema/contract version change.

### References

Object references use:

```json
{
  "kind": "work-item",
  "id": "opaque-id",
  "revision": 7
}
```

`revision` is required when the reference claims an exact semantic version and optional when it names a logical object independent of revision.

### Content hashes

Immutable byte identity is represented as:

```json
{
  "algorithm": "sha256",
  "value": "hex-or-other-schema-defined-encoding"
}
```

The executable schema fixes accepted algorithms/encoding. A bare hash string is not sufficient when algorithm ambiguity matters.

### Cross-object validation

JSON Schema does not decide:

- whether an actor is authorized;
- whether a referenced object/revision exists;
- whether dependency graphs are acyclic;
- whether a Planning concern may become `NOT_APPLICABLE`;
- whether an Acceptance Certificate is currently valid/fresh;
- whether provider conflict scope is available;
- whether Git commits/recovery artifacts are actually reconstructible;
- whether a Route satisfies capability/risk policy or is currently admitted.

Those are Go/domain-policy validations over structurally valid objects.

## Foundational embedded types

These are reusable shapes rather than independently mutable domain objects.

### `object-ref/v1`

| Field | Required | Meaning |
|---|---:|---|
| `kind` | yes | Canonical object family/kind. |
| `id` | yes | Opaque object ID. |
| `revision` | no | Exact revision when required by the relationship. |

### `actor-ref/v1`

| Field | Required | Meaning |
|---|---:|---|
| `kind` | yes | `owner_control`, `pilot`, `bridge`, `worker_attempt`, `factory`, `provider_observer`, or `recovery_operator`. |
| `principal_id` | yes | Authenticated opaque principal identity. |
| `delegation_id` | no | Applicable standing delegation. |
| `worker_attempt_id` | when kind is `worker_attempt` | Exact Worker Attempt identity. |
| `subsystem` | when kind is `factory` | Deterministic Factory subsystem identity. |

The transport/runtime stamps this object from authenticated capability state; it is not trusted merely because a caller serialized it.

### `content-hash/v1`

| Field | Required | Meaning |
|---|---:|---|
| `algorithm` | yes | Admitted cryptographic hash algorithm. |
| `value` | yes | Digest in the encoding defined by the schema. |

### `artifact-ref/v1`

| Field | Required | Meaning |
|---|---:|---|
| `artifact_id` | yes | Opaque artifact identity. |
| `kind` | yes | Semantic artifact kind. |
| `content_hash` | yes when bytes are immutable/required | Content identity. |
| `uri` | when externally stored | Storage locator understood by the artifact provider. |
| `size_bytes` | no | Observed byte size. |
| `retention_class` | yes for retained external artifacts | Policy class, not raw TTL implementation. |
| `created_at` | yes | Creation/ingest timestamp. |

### `ledger-position/v1`

| Field | Required | Meaning |
|---|---:|---|
| `application_sequence` | yes | Published authoritative transaction sequence. |
| `event_index` | yes | Stable zero/one-based index chosen by executable schema within that transaction. |

The exact wire cursor may be opaque; this structure is the semantic order.

### `published-frontier/v1`

| Field | Required | Meaning |
|---|---:|---|
| `generation` | yes | Factory Generation owning the published state. |
| `application_sequence` | yes | Highest authoritative released application sequence represented. |

Storage-private remote restore position may be exposed only in recovery/admin schemas; ordinary clients do not require it.

## API envelope schemas

The normative behavior of these schemas is defined in [API contract](api-contract.md).

### `command/v1`

Required fields:

- `schema` = `command/v1`;
- `command_id`;
- versioned logical `type`;
- authenticated `actor`;
- `issued_at`;
- `correlation_id`;
- optional `causation_id`;
- operation-specific `target`;
- operation-specific `expected_revision`;
- object `payload`.

Command-specific payloads are closed schemas identified by command `type`.

### `command-result/v1`

A definitive terminal disposition. Required fields:

- `schema`;
- `command_id`;
- command `type`;
- `status: RELEASED | REJECTED`;
- `published_frontier` on release;
- optional result/resulting object/event refs;
- structured terminal `error` on rejection.

`REJECTED` is permitted only when Factory can prove that the command will not later appear as a released authoritative mutation under that terminal disposition. Provisional durability/publication uncertainty is not a command result.

### `command-status/v1`

Explicitly non-authoritative command-resolution status used when no definitive terminal disposition is known.

Minimum fields:

- `schema` = `command-status/v1`;
- `command_id`;
- command `type`;
- `status: OUTCOME_UNRESOLVED`;
- typed `reason`, including `DURABILITY_UNAVAILABLE` or `PUBLICATION_OUTCOME_UNRESOLVED`;
- `retry: SAME_COMMAND`;
- `observed_at`.

This object is never consumed as authoritative success or rejection and is not cached as the command's terminal idempotent result.

### `query/v1`

Required fields:

- `schema`;
- `query_id`;
- versioned query `type`;
- authenticated `actor`;
- `issued_at`;
- `consistency`;
- query `parameters`.

Canonical v1 client queries use `consistency: AUTHORITATIVE`.

### `query-result/v1`

Required fields:

- `schema`;
- `query_id`;
- query `type`;
- `snapshot_frontier`;
- query-specific `data`;
- optional opaque cursor metadata for queries that define collection pagination.

### `event/v1`

Required fields:

- `schema`;
- `event_id`;
- versioned event `type`;
- `position`;
- `occurred_at`;
- `actor`;
- exact/relevant `subject` ref;
- `correlation_id`;
- optional `causation_id`;
- event-specific immutable `payload`.

## Project and planning schemas

### `project/v1`

Minimum fields:

| Field | Required | Meaning |
|---|---:|---|
| `schema`, `project_id`, `revision` | yes | Identity/version. |
| `name` | yes | Owner-facing Project name. |
| `status` | yes | Project lifecycle state defined by the executable schema. |
| `repository_refs` | yes | Zero or more configured repository identities. |
| `constitution_ref` | no | Active Constitution object. |
| `planning_policy_ref` | yes | Active Planning Policy/version. |
| `created_at`, `updated_at` | yes | Provenance timestamps. |

A Project is not identical to one repository.

### `constitution/v1`

The Constitution is owner-authorized immutable normative content with versioned replacement/supersession.

Minimum fields:

- `schema`;
- `constitution_id`;
- `version`;
- `project_id`;
- `statements[]` of stable statement IDs + normative text;
- authorizing `owner_action_ref`;
- `effective_at`;
- optional `supersedes`.

Only explicit owner authority may create/amend/supersede constitutional statements.

### `planning-policy/v1`

Minimum fields:

- `schema`, `planning_policy_id`, `version`;
- `project_id` or Factory-default scope;
- mandatory concern families;
- applicability authority rules;
- protected trigger definitions/provenance requirements;
- delegation rules;
- minimum Decision authority rules;
- gate definitions;
- effective/supersession metadata.

Absence of a required rule produces `UNKNOWN`; it does not imply permission.

### `planning-record/v1`

A Planning Record is the durable root for one capability/change planning graph.

Minimum fields:

| Field | Required | Meaning |
|---|---:|---|
| `schema`, `planning_record_id`, `revision` | yes | Identity/version. |
| `project_id` | yes | Owning Project. |
| `goal_refs` | yes | One or more root Goals. |
| `object_refs` | yes | Planning objects in the graph. |
| `trace_edge_refs` | yes | Semantic traceability edges. |
| `concern_refs` | yes | Mandatory concern instances. |
| `current_design_baseline_ref` | no | Latest released Design Baseline. |
| `current_delivery_baseline_ref` | no | Latest Delivery Readiness baseline if separate. |
| `open_change_request_refs` | yes | Post-baseline semantic changes. |
| `status` | yes | Current Planning Record lifecycle status. |
| `created_at`, `updated_at` | yes | Provenance. |

The schema does not require the SQLite implementation to store the graph as one JSON blob.

### `planning-object/v1`

One typed graph node with:

- `planning_object_id`;
- `planning_record_id`;
- `revision`;
- `kind`: `GOAL | REQUIREMENT | CONSTRAINT | ASSUMPTION | QUESTION | OPTION | DECISION_REF | DESIGN | RISK | DEPENDENCY | IMPACT | WORK_PROPOSAL`;
- `title`/short semantic label;
- `body` or kind-specific structured details;
- `status` where relevant;
- provenance/author;
- `created_at`, `updated_at`.

Kinds with richer durable contracts (for example Decision and Research Claim) reference their dedicated schema objects rather than hiding those semantics in free text.

### `trace-edge/v1`

Minimum fields:

- `trace_edge_id`;
- exact/logical `from_ref`;
- exact/logical `to_ref`;
- `relationship` enum, such as `DERIVES`, `SATISFIES`, `EVIDENCES`, `DECIDES`, `DESIGNS`, `IMPLEMENTS`, `VERIFIES`, `DEPENDS_ON`, `IMPACTS`;
- `created_at`;
- provenance/creating command.

Executable policy determines which relationships are legal between which node kinds.

### `planning-concern/v1`

Minimum fields:

| Field | Required | Meaning |
|---|---:|---|
| `concern_id`, `planning_record_id`, `revision` | yes | Identity/scope. |
| `family` | yes | Mandatory concern family from active Planning Policy. |
| `proposed_applicability` | yes | `APPLICABLE | NOT_APPLICABLE | UNKNOWN`. |
| `effective_applicability` | yes | Same enum, established only through policy. |
| `proposal_evidence_refs` | yes | Evidence/assertions supporting proposal. |
| `review_ref` | when policy requires | Independent semantic review. |
| `authority_rule_id` | when effective value is established | Exact Planning Policy rule granting the transition. |
| `protected_trigger_results` | yes | Trigger outcomes with provenance and coverage state. |
| `blocking` | yes | Derived/validated gate effect. |

A producer cannot create effective authority merely by writing `NOT_APPLICABLE`.

### `research-claim/v1`

Minimum fields:

- `research_claim_id`, `planning_record_id`, `revision`;
- normalized `claim` statement;
- `confidence` represented by admitted policy scale, not free-form certainty language;
- `support_type`/evidence classification;
- `source_refs[]` with locator/provenance where available;
- `evidence_refs[]`;
- `valid_as_of`;
- optional `recheck_condition`;
- `conflict_refs[]` for contradictory claims;
- `status` (`ACTIVE`, `STALE`, `SUPERSEDED`, or other schema-defined states);
- producer + review provenance where required.

A source URL/title alone is not evidence provenance when a stable locator/hash can be captured.

### `decision/v1`

Minimum fields:

| Field | Required | Meaning |
|---|---:|---|
| `decision_id`, `planning_record_id`, `revision` | yes | Identity/scope. |
| `question` | yes | Choice being decided. |
| `authority_class` | yes | `LOCAL | PROJECT | STRATEGIC | CONSTITUTIONAL`. |
| `options` | yes | Stable option IDs + descriptions. |
| `selected_option_id` | when decided | Chosen option. |
| `status` | yes | Proposed/decided/superseded lifecycle. |
| `rationale` | when decided | Concise durable reason. |
| `evidence_refs` | no | Supporting evidence. |
| `authority_rule_id` | when policy-authorized | Policy/delegation route. |
| `owner_action_ref` | when owner-gated | Exact human-authorized Owner Action. |
| `supersedes` | no | Prior Decision object where replacement is semantic. |

### `planning-baseline/v1`

Immutable baseline fields:

- `planning_baseline_id`;
- `planning_record_id`;
- `kind: DESIGN | DELIVERY`;
- immutable `sequence`/label;
- exact refs/revisions of included planning objects/Decisions/concerns;
- `published_at`;
- publishing command/gate result refs;
- `supersedes` baseline ref if applicable.

Downstream objects reference the exact baseline from which they were derived.

### `change-request/v1`

Minimum fields:

- `change_request_id`, `revision`;
- `planning_record_id`;
- source baseline ref;
- requested semantic change summary + changed object refs;
- requester/cause;
- impact classification set (`AFFECTED`, `PROVEN_UNAFFECTED`, `UNKNOWN`) with evidence refs;
- affected downstream refs;
- authority class/required approvals;
- independent challenge/review ref when policy requires;
- lifecycle status/disposition;
- replacement baseline ref when accepted.

`UNKNOWN` impact never means unaffected.

### `delegation-grant/v1`

Minimum fields:

- `delegation_id`, `revision`;
- grantor/authorizing Owner Action or policy ref;
- grantee actor class/principal scope;
- Project/Planning Record/Work Item scope;
- allowed command/Decision classes;
- protected surfaces that invalidate the grant;
- evidence/review requirements;
- `effective_at`, optional `expires_at`;
- lifecycle status.

A grant does not survive scope/protected-surface changes that violate its own bounds.

## Delivery and Worker schemas

### `work-item/v1`

A Work Item is the executable delivery contract.

Minimum fields:

| Field | Required | Meaning |
|---|---:|---|
| `work_item_id`, `revision` | yes | Identity/version. |
| `project_id`, `planning_record_id` | yes | Planning ownership. |
| `planning_baseline_ref` | yes while released for delivery | Exact baseline authorizing the work. |
| `parent_ref` | yes | Owning Epic/Initiative hierarchy ref. |
| `kind` | yes | `SLICE` or exceptional `ENABLER`; enabler requires consumer refs. |
| `goal` | yes | Why this work exists. |
| `required_outcomes[]` | yes | Observable semantic outcomes. |
| `constraints[]` | yes | Non-violation boundaries. |
| `verification[]` | yes | Falsifiable verification requirements, not merely shell commands. |
| `dependency_refs[]` | yes | Blocked-by semantics. |
| `lane_ref` | yes when scheduled | Scheduling/collision Lane. |
| `repository_refs[]` | yes | Repositories expected to be touched. |
| `status` | yes | Delivery lifecycle state. |
| `execution_envelope_ref` | yes before autonomous execution | Cumulative Work Item envelope. |
| `created_at`, `updated_at` | yes | Provenance. |

Representative shape:

```json
{
  "schema": "work-item/v1",
  "work_item_id": "opaque-work-id",
  "revision": 4,
  "project_id": "opaque-project-id",
  "planning_record_id": "opaque-planning-id",
  "planning_baseline_ref": {"kind": "planning-baseline", "id": "opaque-baseline", "revision": 1},
  "parent_ref": {"kind": "epic", "id": "opaque-epic"},
  "kind": "SLICE",
  "goal": "restore canonical Factory state on a replacement host",
  "required_outcomes": [
    {"outcome_id": "O1", "text": "a fresh host restores the published authoritative frontier"}
  ],
  "constraints": [
    {"constraint_id": "C1", "text": "unpublished replica tails are never treated as authoritative"}
  ],
  "verification": [
    {"verification_id": "V1", "text": "fault-injected restore proves acknowledged commands survive and unpublished tails do not"}
  ],
  "dependency_refs": [],
  "repository_refs": [{"kind": "repository", "id": "opaque-repository-id"}],
  "status": "READY",
  "execution_envelope_ref": {"kind": "execution-envelope", "id": "opaque-envelope-id", "revision": 1},
  "created_at": "2026-09-13T18:00:00Z",
  "updated_at": "2026-09-13T18:00:00Z"
}
```

### `implementation-envelope/v1`

Attempt/work authorization boundary containing:

- `implementation_envelope_id`, `revision`;
- Work Item + exact baseline/design refs;
- allowed repository/worktree refs;
- authorized areas/path scopes when available;
- predicted files/surfaces as advisory data;
- protected surfaces;
- dependency/Lane assumptions;
- explicitly granted capabilities;
- scope-expansion policy.

Predicted files do not create permission beyond authorized scope.

### `execution-envelope/v1`

Cumulative autonomous resource boundary:

- `execution_envelope_id`, `revision`;
- Work Item ref;
- finite bounds/limits enabled for attempts, elapsed time, route/service classes, measured usage, storage, or repeated severe failures;
- consumed totals;
- reserve/control headroom rules where applicable;
- exhaustion status/reason;
- owner/policy override refs.

Child jobs/Fixers/Reviews do not reset this envelope.

### `worker-job/v1`

Logical job fields:

- `worker_job_id`, `revision`;
- Work Item/Planning Record subject refs;
- Worker role;
- required capability profile;
- job contract/context packet refs;
- execution/implementation envelope refs;
- lifecycle state;
- current/terminal attempt refs;
- created/updated timestamps.

### `worker-attempt/v1`

Concrete execution attempt fields:

- `worker_attempt_id`, `revision`;
- `worker_job_id`;
- attempt number/sequence;
- exact Route ref/version;
- resolved execution manifest ref;
- exact worktree/repository base identity;
- runtime/SandboxProvider identity;
- capability identity;
- lifecycle: `ADMITTED | RUNNING | DRAINING | TERMINATED`;
- start/end timestamps;
- terminal reason;
- result ref when submitted/accepted for processing.

A late result from a non-current/cancelled attempt cannot revive acceptance authority.

### `worker-result/v1`

Minimum fields:

- `worker_result_id`;
- exact Worker Attempt ref;
- result kind/role;
- structured semantic `output` governed by role/result schema;
- produced artifact refs;
- produced Git commit refs when applicable;
- Finding refs/requests raised;
- submission timestamp.

Worker confidence/self-reported success is advisory; Factory/review decides promotion.

### `finding/v1`

Minimum fields:

| Field | Required | Meaning |
|---|---:|---|
| `finding_id`, `revision` | yes | Identity/version. |
| `subject_refs` | yes | Exact objects/code/evidence concerned. |
| `category` | yes | Planning/research/implementation/review/validation/provider/etc. taxonomy. |
| `severity` | yes | Versioned severity enum. |
| `claim` | yes | Concise falsifiable problem statement. |
| `evidence_refs` | yes | Evidence supporting the Finding. |
| `source` | yes | Worker/reviewer/validator/factory origin. |
| `status` | yes | Open/disposition/closed lifecycle. |
| `disposition` | when triaged | Current-work correction, Candidate, planning amendment, new Planning Record, duplicate, no-action, etc. |
| `disposition_reason` | when triaged | Durable rationale. |

A Finding is not automatically a Work Item.

### `review-result/v1`

Minimum fields:

- `review_result_id`;
- exact immutable subject refs/digests;
- Reviewer Worker Attempt/Route ref;
- review contract/policy version;
- verdict enum;
- structured Finding refs;
- evidence refs considered;
- independence metadata required by policy;
- completed timestamp.

Reviewer output cannot mutate the subject it reviews.

### `verification-result/v1`

Machine-observed evidence fields:

- `verification_result_id`;
- exact candidate/base/integration subject refs;
- verification-plan revision/ref;
- Verification Runner execution manifest;
- checks actually run;
- checks skipped and reasons;
- per-check command/tool identity as evidence mechanism;
- exit/result observations;
- produced required/optional artifact refs;
- started/completed timestamps.

A producer-authored test log alone is not this schema unless independently observed by the Verification Runner.

## Acceptance and recovery schemas

### `acceptance-evidence-manifest/v1`

Immutable fields:

- `acceptance_evidence_manifest_id`;
- exact subject/candidate refs;
- `required_evidence[]` artifact/content refs;
- `optional_diagnostics[]` artifact refs;
- `code_recovery_roots[]` exact Git repository/commit/ref dependencies;
- evidence object verification timestamps/results;
- retention policy/root requirements fixed at acceptance time;
- manifest content digest.

Required evidence must be durably uploaded and verified before authoritative acceptance release.

### `acceptance-certificate/v1`

An immutable acceptance binding for the exact verified/reviewed **candidate subject**. Minimum fields:

| Field | Required | Meaning |
|---|---:|---|
| `acceptance_certificate_id` | yes | Stable certificate identity. |
| `planning_baseline_ref` | yes | Exact governing baseline. |
| `work_item_ref` | yes | Exact Work Item revision. |
| `worker_attempt_ref` | yes | Exact implementation attempt. |
| `candidate` | yes | Repository + exact candidate Git commit. |
| `target_base` | yes | Exact repository target/base SHA/revision used for candidate acceptance context. |
| `verification_plan_ref` | yes | Exact verification contract revision. |
| `evidence_manifest_ref` | yes | Required evidence closure. |
| `review_result_ref` | yes | Independent Reviewer verdict. |
| `policy_version` | yes | Governing acceptance policy. |
| `issued_at` | yes | Certificate construction timestamp. |

The certificate is never edited to add a later integration commit or mutable validity state. Any relevant input change makes this immutable certificate no longer current under `acceptance-status/v1`; it does not rewrite the certificate.

Representative fragment:

```json
{
  "schema": "acceptance-certificate/v1",
  "acceptance_certificate_id": "opaque-certificate-id",
  "planning_baseline_ref": {"kind": "planning-baseline", "id": "B17", "revision": 1},
  "work_item_ref": {"kind": "work-item", "id": "W31", "revision": 4},
  "worker_attempt_ref": {"kind": "worker-attempt", "id": "J812-a2", "revision": 1},
  "candidate": {"repository_id": "repo", "commit_sha": "abc123"},
  "target_base": {"repository_id": "repo", "commit_sha": "def456"},
  "verification_plan_ref": {"kind": "verification-plan", "id": "V92", "revision": 3},
  "evidence_manifest_ref": {"kind": "acceptance-evidence-manifest", "id": "E201"},
  "review_result_ref": {"kind": "review-result", "id": "RV55"},
  "policy_version": "delivery-policy/v1",
  "issued_at": "2026-09-13T18:00:00Z"
}
```

### `acceptance-status/v1`

Mutable/derived lifecycle for one immutable Acceptance Certificate:

- `acceptance_status_id`, `revision`;
- exact `acceptance_certificate_ref`;
- `status: CURRENT | STALE | CONSUMED | SUPERSEDED`;
- typed reason/cause refs for stale/superseded/consumed transitions;
- `updated_at`.

Current validity is re-evaluated from authoritative state. Changing status never changes the certificate subject/evidence.

### `integration-certificate/v1`

Immutable merge-eligibility binding created **after** PriFly constructs and independently verifies an exact integration subject against the then-current target.

Minimum fields:

- `integration_certificate_id`;
- exact `acceptance_certificate_ref` for the candidate;
- repository/target ref identity;
- exact expected target/base commit `B`;
- exact constructed integration commit/result `M`;
- independent integration verification result/evidence refs;
- admitted provider integration profile/version;
- governing policy version;
- `issued_at`.

Factory does not mutate a candidate-stage Acceptance Certificate to add `M`. If target/base changes, the existing integration certificate is no longer usable and a newly constructed/reverified integration subject requires a new immutable integration certificate. The exact remote B→M compare-and-update consumes this binding.

### `recovery-root-manifest/v1`

Immutable dependency closure for one supported recovery/rollback root:

- `recovery_root_manifest_id`;
- Factory Generation/application sequence/frontier identity;
- database recovery source identity/restore position;
- required acceptance/evidence manifest refs;
- required Git recovery roots;
- required key/secret generation refs (references only, never raw secrets);
- creation/verification timestamp;
- manifest content digest.

The manifest itself does not mutate from supported to retired.

### `recovery-root-status/v1`

Mutable lifecycle for an immutable Recovery Root Manifest:

- `recovery_root_status_id`, `revision`;
- exact `recovery_root_manifest_ref`;
- `status: SUPPORTED | RETIRING | RETIRED`;
- replacement/superseding root ref when applicable;
- authorizing command/policy refs;
- `updated_at`.

Retirement must become authoritative before cleanup may remove the final dependency protected by the manifest.

## Owner interaction schemas

### `attention-item/v1`

Minimum fields:

- `attention_item_id`, `revision`;
- category: Decision/Approval/Blocker/Risk/Conflict/Incident/Recommendation/Briefing;
- urgency: `BLOCKING | ACTION_REQUIRED | REVIEW_WHEN_CONVENIENT | INFORMATIONAL`;
- subject refs;
- concise reason/context refs;
- state-dependent `allowed_actions[]` descriptors mapping to logical command types;
- deduplication key/group where applicable;
- status;
- created/updated timestamps.

Silence is never represented as an implicit action.

### `owner-action/v1`

Consequential immutable package + mutable confirmation lifecycle:

| Field | Required | Meaning |
|---|---:|---|
| `owner_action_id` | yes | Stable action identity. |
| `revision` | yes | Lifecycle revision; semantic package content itself is immutable once presented. |
| `action_type` | yes | Consequential logical action. |
| `target_refs` | yes | Exact target revisions. |
| `scope` | yes | Exact scope of authority. |
| `consequences` | yes | Material consequences owner is confirming. |
| `package_digest` | yes | Digest binding the presented immutable package. |
| `presented_at` | yes before confirmation | Time package became eligible for owner confirmation. |
| `expires_at` | no | Expiry when policy defines one. |
| `status` | yes | `DRAFT | AWAITING_CONFIRMATION | CONFIRMED | STALE | EXPIRED | CANCELLED | CONSUMED` or schema-defined closed equivalent. |
| `confirmation_command_ref` | when confirmed | Exact `owner-action.confirm/v1` Command. |
| `owner_principal_id` | when confirmed | Human owner-control principal. |

Pilot cannot mint the confirmation fields because it lacks the owner-control capability.

Representative fragment:

```json
{
  "schema": "owner-action/v1",
  "owner_action_id": "OA19",
  "revision": 2,
  "action_type": "decision.select/v1",
  "target_refs": [{"kind": "decision", "id": "D19", "revision": 4}],
  "scope": {"project_id": "P1", "planning_record_id": "PR7"},
  "consequences": ["select option B as the Strategic project decision"],
  "package_digest": {"algorithm": "sha256", "value": "..."},
  "presented_at": "2026-09-13T18:00:00Z",
  "status": "AWAITING_CONFIRMATION"
}
```

## Routing, capacity, and experiment schemas

### `route/v1`

Immutable versioned execution configuration:

- `route_id`, `version`;
- harness identity/version range/profile;
- model identity;
- effort/reasoning setting;
- auth/account mode reference (no raw secret);
- capability profile;
- Capacity Pool ref;
- SandboxProvider/runtime mode;
- declared Worker roles/task classes/capability claims;
- maintenance/security compatibility metadata.

Role answers *what job*; Route answers *how/where it executes*. The Route version itself does not mutate to represent current admission state.

### `route-admission/v1`

Mutable Factory policy/admission state for one immutable Route version:

- `route_admission_id`, `revision`;
- exact `route_ref` including version;
- `status: CANDIDATE | ADMITTED | DISABLED` (or versioned closed equivalent);
- governing Routing Policy/capability evidence refs;
- disable/admit reason and authority refs;
- `effective_at`, `updated_at`.

Dispatch requires a currently ADMITTED route-admission object in addition to the immutable Route configuration.

### `capacity-pool/v1`

Minimum fields:

- `capacity_pool_id`, `revision`;
- pool kind: subscription/metered API/local compute/harness concurrency/etc.;
- observable quota/capacity metadata where known;
- pressure: `HEALTHY | ELEVATED | PRESSURE | CRITICAL | EXHAUSTED`;
- service-class reservation/policy refs;
- measurement timestamp/source.

Unknown quota remains unknown; it is not serialized as invented numeric capacity.

### `experiment/v1`

Minimum fields:

- `experiment_id`, `revision`;
- hypothesis/question;
- experiment type;
- eligible population definition;
- deterministic assignment/stratification rule;
- compared Route/context/tool/prompt variants;
- analysis unit;
- all-assigned denominator rule;
- failure/abandonment/rescue handling;
- observation window;
- metrics/outcome definitions;
- quality/safety guardrails;
- stop conditions;
- status;
- reviewed recommendation/result refs.

Experiment result cannot directly mutate governing routing/Constitution policy without the normal review/authority path.

### `metric-observation/v1`

Historical metric fact fields:

- `metric_observation_id`;
- subject/job/attempt/Work Item/Route refs as applicable;
- metric name/version;
- value + unit or structured outcome;
- observation timestamp;
- provenance/source;
- experiment assignment ref if applicable;
- quality/censoring metadata where applicable.

Metrics intended for long-term learning are authoritative semantic state; heartbeats/stdout tails are not this schema.

## Provider and Factory schemas

### `provider-obligation/v1`

Mutable external-effect state with exact immutable intent:

| Field | Required | Meaning |
|---|---:|---|
| `provider_obligation_id`, `revision` | yes | Identity/version. |
| `profile_type`, `profile_version` | yes | Admitted provider operation profile. |
| `provider` | yes | Provider/account/repository context ref. |
| `operation` | yes | Immutable operation intent/request subject. |
| `conflict_scope` | yes | Resource scope reserved while operation may execute. |
| `preconditions` | yes | Exact provider/ref expectations. |
| `correlation` | yes | Stable correlation strategy/marker data. |
| `state` | yes | `PREPARED | SEND_ARMED | SUCCEEDED | FAILED | UNKNOWN`. |
| `terminal_evidence_refs` | on terminal state | Proof required by operation profile. |
| `provider_object_refs` | no | Resolved external object IDs/SHAs/handles. |
| `prepared_at`, `armed_at`, `terminal_at` | state-dependent | Lifecycle timestamps. |
| `last_observation_ref` | no | Latest admitted observation. |

The transition to `SEND_ARMED` must itself be authoritatively published before the first network mutation byte may be sent.

Representative fragment:

```json
{
  "schema": "provider-obligation/v1",
  "provider_obligation_id": "PO42",
  "revision": 2,
  "profile_type": "git.integrate_target_ref",
  "profile_version": 1,
  "provider": {"kind": "repository", "id": "repo"},
  "operation": {"ref": "refs/heads/main", "new_sha": "M"},
  "conflict_scope": {"kind": "git-ref", "value": "repo:refs/heads/main"},
  "preconditions": {"expected_old_sha": "B"},
  "correlation": {"command_id": "C77"},
  "state": "SEND_ARMED",
  "prepared_at": "2026-09-13T18:00:00Z",
  "armed_at": "2026-09-13T18:00:02Z"
}
```

### `provider-observation/v1`

Immutable external fact:

- `provider_observation_id`;
- provider/account/repository context;
- observation request/sequence identity;
- observed object identity/version/SHA where available;
- observed fields/fact payload;
- source obligation/correlation ref where available;
- `observed_at`;
- admission/ordering metadata used by the operation profile.

Observation of an external merge/close does not synthesize PriFly approval.

### `factory-status/v1`

Owner/client health snapshot:

- `schema`;
- Factory instance identity;
- Factory Generation;
- state such as `INITIALIZING | ACTIVE | QUIESCING | RECOVERY | DEGRADED` as executable lifecycle defines;
- current Published Frontier;
- durability/replication health summary;
- Worker runtime/Worker Docker health summary;
- outstanding blocking provider ambiguity count/refs as policy allows;
- capacity pressure summary;
- recovery/upgrade mode metadata;
- observed timestamp.

This is a Query/read model, not the ownership authority record itself.

### `coordination-record/v1`

The CAS-protected remote ownership/recovery publication object contains exactly the semantics required to linearize authoritative release and takeover:

| Field | Required | Meaning |
|---|---:|---|
| `schema` | yes | `coordination-record/v1`. |
| `factory_id` | yes | Factory installation identity. |
| `generation` | yes | Current ownership generation. |
| `state` | yes | `INITIALIZING | ACTIVE | QUIESCED` or admitted coordination state. |
| `factory_instance` | yes | Instance owning/initializing this generation. |
| `published_sequence` | yes | Highest authoritative application sequence published. |
| `published_remote_position` | yes | Concrete restorable position in named replica lineage. |
| `recoverable_replica` | yes | Replica namespace/source identity. |
| `predecessor_frontier` | during INITIALIZING when required | Exact inherited generation/sequence/remote position. |
| `updated_at` | yes | Diagnostic timestamp only; CAS object version establishes ordering. |

The provider's object version/ETag is part of the CAS operation but need not be serialized inside the record.

Uploaded database bytes outside the published frontier are not authoritative merely because they exist.

## Schema family registry

The initial canonical registry therefore includes:

| Family | Purpose |
|---|---|
| `command/v1` | Requested authoritative mutation envelope. |
| `command-result/v1` | Released/rejected definitive authoritative command disposition. |
| `command-status/v1` | Explicitly nonfinal command-resolution status. |
| `query/v1` / `query-result/v1` | Non-mutating canonical read contract. |
| `event/v1` | Immutable Ledger fact envelope. |
| `project/v1` | Project boundary/configuration. |
| `constitution/v1` | Explicit owner-approved Project invariants. |
| `planning-policy/v1` | Planning authority/gate policy. |
| `planning-record/v1` | Planning graph root/lifecycle. |
| `planning-object/v1` | Generic typed planning graph node. |
| `trace-edge/v1` | Planning/delivery traceability relationship. |
| `planning-concern/v1` | Proposed/effective concern applicability. |
| `research-claim/v1` | Claim provenance/freshness/conflict. |
| `decision/v1` | Scoped choice and authority record. |
| `planning-baseline/v1` | Immutable released planning snapshot. |
| `change-request/v1` | Typed post-baseline semantic change. |
| `delegation-grant/v1` | Bounded standing authority. |
| `work-item/v1` | Executable delivery contract. |
| `implementation-envelope/v1` | Attempt/work scope authorization. |
| `execution-envelope/v1` | Cumulative autonomous resource boundary. |
| `worker-job/v1` | Logical bounded Worker job. |
| `worker-attempt/v1` | Exact Route/runtime attempt. |
| `worker-result/v1` | Structured Worker output. |
| `finding/v1` | Triageable structured observation/problem. |
| `review-result/v1` | Independent review verdict/findings. |
| `verification-result/v1` | Machine-observed verification evidence. |
| `acceptance-evidence-manifest/v1` | Required/optional evidence and code roots. |
| `acceptance-certificate/v1` | Immutable exact candidate acceptance binding. |
| `acceptance-status/v1` | Current lifecycle/validity of an immutable acceptance certificate. |
| `integration-certificate/v1` | Immutable exact integration/merge-eligibility binding. |
| `recovery-root-manifest/v1` | Immutable supported-checkpoint dependency closure. |
| `recovery-root-status/v1` | Current support/retirement lifecycle of a recovery root. |
| `attention-item/v1` | Durable owner attention/action choices. |
| `owner-action/v1` | Consequential immutable owner action package with explicit lifecycle. |
| `route/v1` | Immutable versioned execution configuration. |
| `route-admission/v1` | Current policy/admission state for a Route version. |
| `capacity-pool/v1` | Shared scarce execution resource state. |
| `experiment/v1` | Controlled routing/context/tool experiment. |
| `metric-observation/v1` | Authoritative historical learning metric. |
| `provider-obligation/v1` | External operation intent/ambiguity/conflict lifecycle. |
| `provider-observation/v1` | Immutable admitted external fact. |
| `factory-status/v1` | Client-facing Factory health/status snapshot. |
| `coordination-record/v1` | Remote ownership + published recovery frontier authority. |

Additional role-specific Worker result schemas and command/query/event payload schemas are added as those operations are implemented; they must compose with these boundary contracts rather than inventing parallel semantics.

## Versioning and migration rules

1. Schema version is part of type identity.
2. Historical Ledger Events are never rewritten merely to adopt a newer schema.
3. Immutable historical certificates/baselines/manifests/Route versions remain interpretable under their original version; mutable lifecycle is recorded separately.
4. Current mutable projections may be deterministically migrated during Factory upgrade.
5. Breaking semantic change requires a new schema version.
6. Closed authoritative schemas do not accept unknown meaning by default.
7. Migration code must preserve IDs, authority provenance, and historical traceability unless an explicit architecture decision says otherwise.
8. Database migration filename format, ordering, immutability, consolidation, and ordered-prefix semantics are governed by [ADR-0020](../adr/0020-use-timestamped-forward-only-migrations.md) and [Recovery and upgrades](../explanation/recovery-and-upgrades.md).
9. API, DB schema, Worker protocol, canonical object schemas, and execution manifests version independently.
10. Unsupported schema combinations fail admission rather than silently dropping fields.
11. Schema migration does not imply permission to roll back authoritative post-upgrade history; upgrade rollback rules remain governed by recovery architecture.

## Validation layers

```text
JSON bytes
→ parse
→ JSON Schema structural validation
→ canonical object construction
→ Go semantic/domain validation
→ authority/policy/state validation
→ authoritative transaction or rejection
```

Examples of Go/domain validation:

- `work-item/v1` enabler has at least one named consumer;
- dependency graph remains acyclic;
- `planning-concern/v1` effective N/A names a valid authority rule and has no conflicting UNKNOWN trigger;
- `owner-action/v1` confirmation proof matches the immutable package digest and target revisions;
- `acceptance-status/v1` may be CURRENT only while all referenced acceptance inputs remain authoritative/current;
- `integration-certificate/v1` binds the exact current target B, integration subject M, verification evidence, and candidate Acceptance Certificate;
- `recovery-root-status/v1` retirement is authoritative before cleanup releases the root's final dependencies;
- `route-admission/v1` may admit only an immutable Route version satisfying current capability/risk policy;
- `provider-obligation/v1` may enter SEND_ARMED only after conflict ownership/preconditions/policy pass;
- `coordination-record/v1` transition obeys the CAS generation/publication state machine.

## Executable JSON Schema placement

The actual machine-readable JSON Schema files are implementation artifacts and should be committed when the first producer/consumer for a family is implemented. They become the executable source for structural validation and must conform to this reference contract.

This document remains the human-readable semantic reference; it should link to executable schemas once their repository layout exists.

## Prompt serialization

Prompt codecs are projections over canonical objects. Compact JSON, Markdown, XML-tagged formats, TOON, or future codecs may be benchmarked experimentally without changing the underlying canonical schema.

A prompt serialization is never canonical simply because a Worker emitted it.

## Deliberately not fixed here

This schema contract does not choose:

- SQLite tables/indexes/normalization;
- Go package/struct names;
- JSON Schema repository directory names;
- ID encoding (UUID/ULID/etc.);
- content-canonicalization library for digests;
- concrete Go migration library, migration source-tree directory, transaction wrapper, or schema-fingerprint implementation (the migration filename format and ordering policy are already fixed by ADR-0020);
- transport endpoint paths;
- UI view models derived from canonical objects;
- every role-specific Worker payload before the role is implemented.

Those details may evolve as implementation proceeds, provided they preserve the semantic contracts above.
