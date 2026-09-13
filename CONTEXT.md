# CONTEXT.md — glossary

The canonical vocabulary of PriFly. Definitions are domain language only; implementation details live in the design docs.

## Terms

**PriFly** — The local-first autonomous software factory described by this repository. not: orchestrator agent, coding bot.

**Factory** — The deterministic authority that owns PriFly workflow, canonical state, scheduling, policy enforcement, recovery, and side effects. not: Pilot, Worker.

**Pilot** — A disposable conversational owner interface that queries Factory state and translates owner intent into Factory actions. not: orchestrator, Worker.

**Bridge** — The future graphical owner interface over the same Factory contracts as Pilot. not: control plane.

**Worker** — A bounded AI execution role performing one Factory-assigned cognitive job. not: agent orchestrator.

**Worker Job Attempt** — One concrete execution attempt for a Worker job, with its own identity and runtime envelope. not: Work Item.

**Project** — A product or system boundary managed by PriFly and allowed to span repositories. not: repository.

**Initiative** — A significant outcome inside a Project. not: milestone.

**Epic** — A cohesive workstream or deliverable inside an Initiative. not: Initiative.

**Work Item** — The smallest executable delivery unit with Goal, Required Outcomes, Constraints, and Verification. not: issue.

**Lane** — An execution and scheduling path used to reason about dependencies and safe concurrency. not: branch.

**Planning Record** — The persistent graph of planning objects for a capability or change. not: plan document, spec.

**Planning Baseline** — An immutable released snapshot of planning state from which downstream work is derived. not: branch baseline.

**Change Request** — A typed proposal to semantically change a released Planning Baseline. not: pull request.

**Finding** — A structured observation that may require correction, triage, planning amendment, or no action. not: issue.

**Candidate** — A bounded potential future work item awaiting triage/promotion. not: Work Item.

**Goal** — The purpose a planning or delivery unit exists to achieve. not: task.

**Requirement** — A condition or behavior that must be satisfied. not: implementation step.

**Constraint** — A boundary or non-violation that limits acceptable solutions. not: preference.

**Outcome** — An observable condition a Work Item must make true. not: command.

**Verification** — A falsifiable method for establishing an Outcome. not: acceptance test command.

**Evidence** — Observed material supporting a Research Claim or Verification result. not: model confidence.

**Research Claim** — A planning assertion with claim-level provenance, freshness, and confidence. not: research report.

**Decision** — An approved choice among meaningful alternatives within a defined scope. not: suggestion.

**Constitution** — Owner-approved Project invariants that only the owner can amend or supersede. not: convention.

**Owner Action** — A revision-bound consequential action package requiring owner authority or an applicable standing delegation. not: Pilot suggestion.

**Attention Item** — Durable Factory state representing owner attention that may block, require action, or inform. not: chat notification.

**Acceptance Certificate** — The immutable binding between exact planning, attempt, code, integration target, evidence, review, and policy revisions that authorizes acceptance. not: review comment.

**Acceptance Evidence Manifest** — The immutable list of required evidence and recovery roots supporting an Acceptance Certificate. not: log bundle.

**Recovery Root Manifest** — The required external Git, evidence, and key dependencies needed to honor a supported recovery checkpoint. not: backup catalog.

**Route** — A versioned execution configuration combining harness, model, effort, auth/account mode, capability profile, Capacity Pool, and material execution identity. not: model.

**Capacity Pool** — A shared scarce resource consumed by one or more Routes, such as a subscription allowance, API budget, or local compute. not: Route.

**Capability Tier** — A contextual evidence-backed ranking of Route capability for a role or task class. not: universal model rank.

**Execution Envelope** — The cumulative attempt, time, usage, storage, and escalation boundary for one Work Item. not: single-job timeout.

**Provider Broker** — The privileged Factory component that projects state to external providers and performs admitted provider operations. not: Worker.

**Provider Projection** — An external provider representation of Factory state for visibility or collaboration. not: canonical state.

**Provider Obligation** — A durable record of an external effect PriFly has authorized and may have sent. not: event.

**SEND_ARMED** — The provider-operation state proving an obligation is durably authorized and may have been sent. not: sent confirmation.

**UNKNOWN** — A conservative state meaning PriFly cannot prove a concern or external operation is safely resolved. not: false, unaffected.

**Factory Generation** — A monotonically advancing ownership generation used to fence new authoritative publication and authorization. not: software version.

**Published Frontier** — The CAS-published authoritative application sequence and remote restore position every permitted successor must preserve. not: latest uploaded bytes.

**Recovery Kit** — Independently retained material required to identify and recover the Factory after local-host loss. not: Factory backup.

**SandboxProvider** — The replaceable execution-substrate boundary for Worker job isolation. not: security guarantee.

**Code Intelligence Provider** — A replaceable source of repository structure, symbols, references, impact evidence, or diagnostics. not: canonical project knowledge.

**Ledger Event** — A semantic fact appended transactionally with canonical state to explain how Factory state changed. not: event-sourced database.
