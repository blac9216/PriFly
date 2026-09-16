# Architecture risks and assumptions

Kind: explanation

### Main risks and treatment

| Risk | Consequence | Required treatment |
|---|---|---|
| HerdR's actual control surface differs from assumed requirements | Session escape, uncontrollable resume, or inability to enforce workspace ownership. | Qualify the specific topology/version; add bounded adapter controls; do not claim capabilities the dependency does not expose. |
| Exact remote frontier becomes unrestorable after compaction | Acknowledged state can no longer be recovered correctly. | Treat retention/checkpoint behavior as part of the durability conformance tuple and test aging plus crashes. |
| GitHub profile is described as stronger than its API/protection behavior | Stale or unverified combinations may merge under false assumptions. | Test actual head/base race behavior and state the admitted guarantee precisely; never bypass PRs as a fallback. |
| Standards summaries become invented requirements | Agents enforce arbitrary criteria under an authoritative-sounding label. | Preserve source identity, access scope, locator, derivation, and review; unresolved interpretation is criterion-unknown. |
| Too many semantic jobs create overhead | Planning/triage/review spend more than the work itself. | Bounded packets, reuse, batching, event-driven scheduling, and measured value of each worker invocation. |
| “No new work left” can never be reached because reviews generate endless follow-ups | Scope churn and perpetual closeout delay. | Relevance checks, no-action authority, coherent scope, batching, finite envelopes, and explicit owner resolution of scope changes. |
| Reused workspace contains hidden state | Fix appears green locally but fails in fresh review/product validation. | Preserve state for efficiency, but record material configuration and use independent reviewed subjects and representative validation. |
| Validation defects are treated as ordinary low-priority cleanup | Product stays broken while nominal throughput appears high. | Explicit target-blocking links and scheduling contribution, visible failed/pending age, release/closeout gates. |
| General “UNKNOWN” spreads without actionable routing | Workflow stops with no clear next step. | Typed reason, evidence gap, responsible role, permitted action, and attention/timeout policy for every unresolved condition. |
| Reviewer's test execution recursively spawns more reviewers | Unbounded cost and no final verdict. | Same-review evidence gathering; fresh reviewer only for a changed artifact or a separately justified job. |

### Limits of what is known

Architect owns the design assessment for these concerns; the responsible runtime, durability,
provider, quality or planning qualification must supply evidence. Reviewer challenges the
assessment; only the owner or an explicit delegation accepts consequential residual risk.
Likelihood, exposure and numerical tolerances have not been measured here and are not assigned
fictional scores. Each governing package must record the affected goal, assessed likelihood/
uncertainty, impact, chosen treatment, accountable owner, monitoring trigger and residual-risk
authority before its risk gate can pass.

Reassess on dependency/configuration change, a failing conformance scenario, material workload/
cost evidence, a changed trust boundary, or altered release scope. [Unselected parameters](../reference/deployment-parameters.md)
gives release dependencies; [Conformance](../reference/conformance.md) provides adverse probes.

This document selects a product architecture. It does not claim that a particular dependency release has already passed PriFly's conformance tests, that all licensed standards text has been inspected, or that every numerical operating target has been measured. Public official sources establish the cited tool capabilities and standards scope; the remaining implementation qualification is explicit.

A feasibility result that disproves a selected mechanism must return as a specific design decision with alternatives and impact, not silently rewrite an implementation issue's acceptance criteria. The owner should not have to discover such a change only after code has landed.
