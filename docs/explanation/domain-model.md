# Domain model

Kind: explanation

This document defines the relationships and rules among PriFly's canonical terms. The one-line definitions and rejected synonyms live in the root [`CONTEXT.md`](../../CONTEXT.md).

### Factory

Factory is the deterministic authority for canonical workflow state, Planning Records, initiatives, epics, Work Items, dependencies, lanes, Commands, Queries, Events, scheduling, routing, owner Attention Items and Owner Actions, provider reconciliation, context compilation, durability/recovery, metrics, experiments, and canonical rendering.

### Pilot

Pilot is a disposable conversational owner interface. It may query/explain Factory state, surface Attention Items, discuss evidence, draft Owner Actions, translate explicit owner intent into Factory Commands, and ask Factory to begin workflows. It may not perform project work itself, directly mutate provider state, directly change SQLite, or infer consequential owner consent.

### Bridge

Bridge is a future GUI over the same Factory API, Attention Items, Owner Actions, and event stream. Bridge is not a separate workflow authority.

### Workers

Worker roles include Analyst, Scout, Researcher, Architect, Planner, Estimator, Implementer, Reviewer, Fixer, Rebaser, Validator, Auditor, Arbiter, and Curator. Workers do not orchestrate Factory Workers; they submit typed results, Findings, requests, and proposals.

### Provider Broker

Provider Broker is the privileged internal subsystem responsible for external provider projections and mutations. Workers do not receive normal provider mutation credentials.

## Work hierarchy

```text
Project
  └─ Initiative
      └─ Epic
          └─ Work Item
```

Milestone, Dependency, Lane, Repository, and Kind are orthogonal concepts. A Project may span multiple repositories. Provider issues/projects are projections, not canonical workflow state.

## Planning and delivery relationships

A **Planning Record** contains Goals, Requirements, Constraints, Research Claims, Decisions, Designs, Risks, Dependencies, and Work Proposals. Releasing coherent planning state creates an immutable **Planning Baseline**.

A **Work Item** is derived from a Planning Baseline and carries a Goal, Required Outcomes, Constraints, and Verification. One or more **Worker Job Attempts** may execute it. Exact accepted code and evidence are bound by an **Acceptance Certificate**.

A **Finding** is evidence for triage, not automatically a Work Item. A semantic change to a released baseline is a **Change Request**. A **Project** may contain multiple repositories; repository boundaries never define the Project domain boundary by themselves.
