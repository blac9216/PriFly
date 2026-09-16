# Unselected parameters and admission dependencies

Kind: reference

### Fixed direction versus unselected parameters

This design defines mechanisms and boundaries in detail. Some choices still require a concrete implementation experiment, a deployment profile, or owner preference. They are collected here so an implementation agent does not invent them while working on an unrelated feature.

A parameter is not permission to postpone an acceptance requirement indefinitely. It must be set before work depending on it is released or before a profile claiming it is admitted.

Owner supplies consequential preference/risk authority; Architect owns design sufficiency and
qualified contracts; Planner and Estimator own dependent delivery scope/estimates; Reviewer
independently evaluates evidence; Factory enforces the effective release/admission rules.
These are responsibility roles, not claims that qualification has already been completed.

| Parameter group | Required evidence and latest safe boundary |
|---|---|
| RP-01–05, RP-11, RP-16 | Architect must establish credible feasibility for the chosen boundary before design release; exact host/runtime/storage/bootstrap/code-tool/provider tuples and adversarial conformance evidence are required before their admission or a dependent guarantee is claimed. A disqualifying result reopens design. |
| RP-06–10, RP-12–13 | Planning fixes project thresholds, workload, budgets and scheduling/retention controls before dependent Work Item execution release; estimates use those inputs. Acceptance never selects them after results are known. |
| RP-14–15 | Source/criterion mapping, applicability and overlay targets must suffice before a blocking evaluation uses them; unresolved official-source ambiguity blocks that gate. |
| RP-17–18, RP-21–23 | Architect defines semantic boundaries before decomposition; exact interface/schema/prompt/projection/rendering contracts, authority and positive/adverse fixtures precede producer/consumer admission. Owner approves material package/authority choices. |
| RP-19–20 | Closure delegation and release destination semantics are fixed before affected disposition/publication; unresolved authority or provider ambiguity blocks closeout rather than disappearing. |

The table is a deadline for resolution, not permission to defer a value already needed by an
earlier quality gate. Record each selection's version, scope, evidence, decision authority and
recheck trigger in its governing package/profile.

| ID | Decision or parameter | What is fixed | What still needs selection or evidence |
|---|---|---|---|
| RP-01 | Initial supported host/deployment matrix | Containerized Factory with dedicated Worker Docker; no host-installed Factory requirement. | Supported OS/architecture/container-runtime versions and resource floor. |
| RP-02 | HerdR deployment topology | Named owner/Worker sessions, explicit Pilot entry, read-only observation, no focus stealing, Factory-controlled resume. | Qualified version, identity/socket/process permissions, viewer implementation, headless operation, and resource ownership. |
| RP-03 | Initial harness/model matrix | Multi-harness and local/hosted models are supported architectural dimensions from day one. | Exact admitted harnesses/models/accounts and which required controls each demonstrates. |
| RP-04 | SQLite/Litestream integration | Transaction-bound remote durability, published frontier, exact supported restore lifetime. | Driver/PRAGMAs, replica version/configuration, synchronization mapping, retention mechanism, and proof under load/faults. |
| RP-05 | GitHub merge profile | PR merge only; no direct target push; head and base semantics represented honestly. | Merge method, required checks, branch freshness/protection rules, and any optional queue profile. |
| RP-06 | Triage batching | Semantic coherence, urgent release, bounded hold, closeout sweep. | Target/minimum/maximum batch sizing, aging/reconsideration cadence, priority contribution scales. |
| RP-07 | Validation scheduling | Target-based pending accounting and normal scheduler; normal target scheduling. | Pending threshold, age trigger, environment capacity, grouping limits, operator-request urgency. |
| RP-08 | Evidence independence | Implementer evidence may be accepted; Reviewer can gather evidence in the same review. | Project/risk profiles requiring selected independent checks and how they are justified. |
| RP-09 | Execution envelopes | All descendant/correction/review costs are cumulative at the owning scope. | Attempt/time/usage/storage bounds, reserves, severe-failure escalation thresholds. |
| RP-10 | Checkpoint frequency | Exact remote code checkpoints bound avoidable host-loss waste. | Maximum uncheckpointed interval/work and progress-checkpoint policy for each job type. |
| RP-11 | Recovery Kit | Private Git `bootstrap.json` plus `secrets.json.age`; independently retained repository access and age key; explicit initialization versus recovery. | Qualified age/release versions, protected key-input/storage mechanism, custody/rotation UX, and tested clean-host acquisition path. |
| RP-12 | Retention/cost | Historical metrics retained; required evidence/roots pinned; optional diagnostics bounded. | Artifact-class retention periods, storage/request budget alerts, protected checkpoint cadence. |
| RP-13 | Product performance | Measured query/publication/scheduler/recovery behavior under a declared workload. | Dataset size, concurrent project/attempt counts, latency/throughput targets, recovery-time target. |
| RP-14 | Standards source access | Pinned official sources; no invented clauses or false certification. | Licensed full text where necessary, source-locator completeness, reviewed normalization and mapping coverage. |
| RP-15 | Conditional standards | WCAG/ASVS/SLSA activate only for relevant scope and chosen targets. | Exact level/track/requirement selection per managed Project; no universal assumed level. |
| RP-16 | v1 code intelligence | Exact Git facts plus Serena semantic navigation/editing through a replaceable capability boundary. | Admitted Serena/backend versions, language coverage, licensing/telemetry settings, measured benefit, runtime setup. |
| RP-17 | Owner interface details | Pilot disposable; separate consequential confirmation; durable attention. | CLI command spelling, trusted confirmation transport, default briefing formatting, Bridge timing. |
| RP-18 | Artifact/record representations | Versioned JSON semantics and immutable/mutable separation. | Executable schema layout, ID encoding, Go types/packages, SQL normalization, pagination encoding. |
| RP-19 | Finding closure governance | No held or planned-only obligations hidden at closeout. | Exact owner delegation for no-action/risk/scope-change decisions and application to imported legacy findings. |
| RP-20 | Release providers | Named version sets and admitted publication profiles with partial-outcome handling. | Initial artifact registry/distribution destinations and their native idempotency/retention behavior. |
| RP-21 | Phase releases and review packages | Three exact-package owner releases; independent engineering gates; foundation versus feature packages; annotation provenance. | Project-specific budgets, package rendering/annotation controls, and material-change policies within those boundaries. |
| RP-22 | Provider projection profile | GitHub milestone maps to Initiative; optional planning representations; structured review history; separate mandatory PR controls. | Enabled views/fields/labels per Project, issue summary versus mirror settings, native review identities, drift/backfill and inspection-readiness policies. |
| RP-23 | Initial prompt and attack profiles | [Appendix F](worker-prompts.md#initial-role-and-job-prompt-library) defines role/job seed wording and [Section 15](../explanation/review.md#independent-review-and-the-current-correction-path) defines attack techniques; every admitted dispatch pins its contract. | Executable schema IDs, reviewed prompt revisions, role/job fixtures, and risk-specific mandatory probe selections before admission. |

## Proposed initial execution-handover profile

The following concrete profile is proposed for independent review and exact owner design approval. It does not admit any runtime tuple or release implementation. The preceding RP definitions remain the governing selection/qualification boundaries; this table selects the bounded initial scope and numerical targets before implementation observations. Runtime values still requiring actual identity/compatibility evidence are stated explicitly. Subsequent profile changes preserve prior evidence and require impact/requalification.

| ID / RP mapping | Proposed selection | Evidence and enforcement / recheck trigger |
|---|---|---|
| P14 / RP-14 | Use baseline normalized `/v1` rubric criterion inventory and pinned sources; criterion descriptors must carry source/locator, method, applicability, blocking effect, evidence and independence before execution. | Missing precise source interpretation stays UNKNOWN. Catalog access is not full-text access. No full ISO/IEEE certification claim. Exact descriptor/source mapping is independently reviewed before making any imported criterion blocking. |
| P18 / RP-18 | Versioned JSON artifact bytes + relational identity/state indexes; random typed IDs, monotonic revisions, SHA-256, source/rendered identity; ordered 20-digit UTC migrations. | Schemas/round-trip/unknown-version fixtures and historical read compatibility precede admission. Exact schema IDs allocated in implementation under these contracts. |
| P21 / RP-21 | Feature package over PRD v2.1; three exact releases and independent gates. External review identity trust is separately owner-bound; deterministic rendered Markdown package + source hashes + explicit annotation locations. | No conversational “yes” interpreted against a newer unseen package. Planning preparation already authorized; these are product import/phase contracts, not invented retrospective Factory events for this session. |
