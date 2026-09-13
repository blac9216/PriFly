# Product lifecycle

Kind: explanation

This document shows how PriFly's existing canonical subsystems participate in one end-to-end piece of software work. It is a **cross-subsystem choreography**, not a second specification: each box links conceptually to the subsystem document that owns its detailed rules.

The product-level promise and success criteria live in [Product definition](product.md).

## Owner intent to Design Baseline

The first lifecycle converts an owner goal into an explicit, traceable design rather than immediately creating implementation tasks.

```mermaid
flowchart TD
    Intent[Owner intent]
    Pilot[Pilot / owner interface]
    Start[planning.start Command]
    Record[Planning Record]
    Concerns[Mandatory concern inventory]
    Gaps[Gap Register]
    Research[Research Claims + evidence]
    Options[Options + Decisions]
    Design[Design objects + traceability]
    Gate{Design Completeness Gate}
    Baseline[Immutable Design Baseline]
    Attention[Owner Attention / Owner Action]

    Intent --> Pilot --> Start --> Record --> Concerns --> Gaps
    Gaps -->|facts needed| Research --> Gaps
    Gaps -->|material choice| Options --> Attention --> Options
    Options --> Design --> Gate
    Research --> Design
    Gate -->|blocking concern remains| Gaps
    Gate -->|zero unresolved blocking applicable concerns| Baseline
```

Important properties:

- PriFly researches discoverable facts rather than turning every unknown into an owner question.
- AI may propose applicability/classification, but Factory policy establishes effective authority.
- Strategic/Constitutional or otherwise consequential choices use the correct Owner Action path.
- Design Baselines are immutable released snapshots. Later semantic changes create Change Requests rather than editing history in place.

Canonical detail: [Planning architecture](planning.md), [Planning policy](../reference/planning-policy.md), [Pilot and owner interaction](pilot.md).

## Design Baseline to executable delivery plan

After design is complete, PriFly decomposes for early integrated/testable value first and parallelism second.

```mermaid
flowchart TD
    Baseline[Design Baseline]
    Slice[Walking-skeleton / integrated slice]
    Decompose[Work proposals]
    Impact[Impact + dependency analysis]
    Items[Work Items]
    Lanes[Lanes + repository/scope assignments]
    VerifyDesign[Verification design]
    PlanReview[Fresh Plan Review]
    Gate{Delivery Readiness Gate}
    Ready[Released delivery plan]

    Baseline --> Slice --> Decompose --> Impact --> Items --> Lanes
    Items --> VerifyDesign --> PlanReview --> Gate
    Lanes --> Gate
    Gate -->|coverage / dependency / verification problem| Decompose
    Gate -->|ready| Ready
```

Each executable Work Item carries:

```text
Goal
Required Outcomes
Constraints
Verification
```

Tests and commands are evidence mechanisms for Verification; they are not substitutes for semantic Outcomes.

`SLICE` is the default Work Item kind. An `ENABLER` is exceptional and names the consumers that make it necessary.

Canonical detail: [Planning architecture](planning.md), [Schemas](../reference/schemas.md).

## Work Item to delivered code

This is the normal autonomous delivery path for one ready Work Item.

```mermaid
flowchart TD
    Ready[READY Work Item]
    Schedule[Scheduler evaluates dependencies + Lane]
    Route[Deterministic Route selection]
    Attempt[Worker Job Attempt]
    Worktree[Dedicated worktree + Implementation Envelope]
    Commit[Exact Worker commit]
    Checkpoint[Factory publishes namespaced job ref]
    Candidate[Candidate subject]
    Verification[Independent Verification Runner]
    Review[Fresh independent Reviewer]
    Fix{Accepted?}
    Fixer[Fix / bounded reimplementation]
    Evidence[Acceptance Evidence Manifest]
    Certificate[Acceptance Certificate]
    Integrate[Build + verify exact integration subject]
    CAS[Exact target compare-and-update]
    Delivered[DELIVERED]

    Ready --> Schedule --> Route --> Attempt --> Worktree --> Commit --> Checkpoint --> Candidate
    Candidate --> Verification --> Review --> Fix
    Fix -->|no| Fixer --> Candidate
    Fix -->|yes| Evidence --> Certificate --> Integrate --> CAS --> Delivered
```

The important identity chain is exact:

```text
Planning Baseline
→ Work Item revision
→ Worker Attempt
→ candidate commit
→ verification evidence
→ Reviewer verdict
→ Acceptance Certificate
→ exact integration subject
→ exact target update
```

Any material change to the bound subject invalidates the relevant certificate rather than silently carrying approval forward.

Canonical detail: [Execution architecture](execution.md), [Review and validation](review-and-validation.md), [Acceptance contract](../reference/acceptance-contract.md), [Provider integration](providers.md).

## Provider side-effect lifecycle

External effects follow a separate durable obligation lifecycle. This is intentionally distinct from ordinary in-memory request/retry logic.

```mermaid
flowchart TD
    Intent[Admitted provider operation intent]
    Prepared[PREPARED]
    Arm[SEND_ARMED published authoritatively]
    Send[Provider network mutation]
    Result{Outcome provable?}
    Success[SUCCEEDED]
    Failure[FAILED]
    Unknown[UNKNOWN]
    Reconcile[Operation-profile reconciliation]
    Attention[Owner Attention if ambiguity cannot be proved]

    Intent --> Prepared --> Arm --> Send --> Result
    Result -->|yes: success| Success
    Result -->|yes: non-execution/failure| Failure
    Result -->|not provable| Unknown --> Reconcile
    Reconcile -->|terminal proof| Success
    Reconcile -->|terminal non-execution proof| Failure
    Reconcile -->|still ambiguous| Attention
```

`SEND_ARMED` is the crash-safe possible-send boundary. A recovered unresolved SEND_ARMED operation is treated as possibly sent; PriFly does not blind-retry an operation merely because its result was not observed.

Canonical detail: [Provider integration](providers.md), [Provider operation profiles](../reference/provider-operation-profiles.md), [State machines](../reference/state-machines.md).

## Post-baseline change and impact flow

A released baseline is not edited in place when the product/design changes. PriFly opens a Change Request and computes conservative blast radius.

```mermaid
flowchart TD
    Change[New semantic change / Finding / owner request]
    CR[Change Request]
    Impact[Impact analysis]
    Classify{Downstream classification}
    Affected[AFFECTED]
    Unknown[UNKNOWN]
    Unaffected[PROVEN_UNAFFECTED]
    Pause[Pause / invalidate / revalidate]
    Continue[Continue]
    Replan[Planning update + review]
    NewBaseline[New immutable Baseline]

    Change --> CR --> Impact --> Classify
    Classify --> Affected --> Pause
    Classify --> Unknown --> Pause
    Classify --> Unaffected --> Continue
    Pause --> Replan --> NewBaseline
```

`UNKNOWN` is conservative: absence of a discovered impact edge is not proof that downstream work is unaffected.

The replacement baseline becomes the authority for newly released downstream work. Existing accepted evidence remains historical evidence for the exact subject it originally certified.

Canonical detail: [Planning architecture](planning.md), [Context and code intelligence](context-and-code-intelligence.md).

## Owner Attention and consequential authority

PriFly's autonomy is bounded by durable Attention Items rather than by keeping the Owner continuously in the execution loop.

```mermaid
flowchart TD
    Need[Factory detects owner-relevant need]
    Item[Attention Item]
    Urgency{Urgency}
    Info[INFORMATIONAL / REVIEW_WHEN_CONVENIENT]
    Action[ACTION_REQUIRED]
    Blocking[BLOCKING]
    Pilot[Pilot / Bridge explains context + options]
    Routine{Standing delegation sufficient?}
    Command[Normal typed Command]
    OwnerAction[Immutable Owner Action]
    Confirm[Owner-only confirmation capability]
    Factory[Factory validates + applies]

    Need --> Item --> Urgency
    Urgency --> Info --> Pilot
    Urgency --> Action --> Pilot
    Urgency --> Blocking --> Pilot
    Pilot --> Routine
    Routine -->|yes| Command --> Factory
    Routine -->|no / consequential| OwnerAction --> Confirm --> Factory
```

Silence, conversational ambiguity, or Pilot interpretation is never consequential confirmation. Pilot may draft and explain an Owner Action but cannot mint the owner-control proof.

Canonical detail: [Pilot and owner interaction](pilot.md), [API contract](../reference/api-contract.md), [Schemas](../reference/schemas.md).

## Local-host loss and recovery flow

The Factory host is disposable; acknowledged authoritative state is not.

```mermaid
flowchart TD
    Loss[Local PriFly host lost]
    NewHost[Replacement host + PriFly release]
    Kit[Recovery Kit / root material]
    Discover[Discover coordination record]
    Takeover[Explicit generation takeover CAS]
    Restore[Restore exact Published Frontier]
    Validate[SQLite + schema/domain validation]
    Migrate[Apply required forward migrations]
    Reconcile[Reconcile inherited SEND_ARMED / UNKNOWN obligations]
    Replica[Establish successor replica + restorable frontier]
    Activate[CAS publish ACTIVE]
    Resume[Resume normal authoritative work]

    Loss --> NewHost --> Kit --> Discover --> Takeover --> Restore --> Validate --> Migrate --> Reconcile --> Replica --> Activate --> Resume
```

Recovery restores the coordination-selected authoritative frontier, not merely the latest bytes that happen to exist remotely. Uploaded-but-unpublished tails are not promoted into history.

Canonical detail: [Persistence and durability](persistence-and-durability.md), [Recovery and upgrades](recovery-and-upgrades.md), [State machines](../reference/state-machines.md).

## Initiative closure and learning loop

Delivery is not complete merely because all code merged. Initiative closure verifies that the delivered system and its external projections are in a known terminal state.

```mermaid
flowchart TD
    Work[All required Work Items terminal + released]
    Validate[Required initiative/system validation]
    Findings{Blocking Findings / owner decisions?}
    Provider[Provider projections reconciled]
    Risks[Residual risks explicit]
    Close[Close Initiative + freeze delivered baseline/as-built record]
    Metrics[Compute deterministic delivery/planning metrics]
    Lessons[Bounded lessons analysis]
    Review[Fresh review of Lesson Candidates]
    Evidence{Repeated evidence?}
    Recommend[Recommendation]
    Authority[Owner / policy decision]

    Work --> Validate --> Findings
    Findings -->|yes| Work
    Findings -->|no| Provider --> Risks --> Close --> Metrics --> Lessons --> Review --> Evidence
    Evidence -->|not yet| Metrics
    Evidence -->|yes| Recommend --> Authority
```

The learning ladder remains:

```text
Observation
→ Lesson Candidate
→ reviewed Lesson
→ repeated evidence
→ Recommendation
→ owner/policy decision
```

Factory may automate measurement and bounded experimentation; it does not autonomously rewrite Constitution or governing policy.

Canonical detail: [Experiments, metrics, and learning](experiments-and-metrics.md), [Observability, retention, and replayability](observability-and-retention.md), [Planning architecture](planning.md).

## How to read these flows

The diagrams intentionally omit implementation mechanics that belong to lower-level contracts. In particular:

- they do not define SQLite table layout;
- they do not define HTTP paths or transport framing;
- they do not replace the authoritative state machines;
- they do not add new permissions or lifecycle states;
- they do not imply every optional optimization is active in the first executable milestone.

When a diagram and a subsystem/reference contract appear to disagree, the subsystem/reference contract and accepted ADRs are authoritative and this lifecycle document must be corrected.