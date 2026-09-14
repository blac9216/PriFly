# Standards-backed quality rubrics

Kind: reference

This document defines PriFly's reusable **general engineering quality rubrics**. They answer questions such as “is this requirement well formed?”, “is this architecture description adequate?”, “can this verification actually prove the requirement?”, and “is this work product ready for acceptance?” using pinned industry standards and authoritative engineering guidance.

The source registry is [Engineering standards registry](standards-registry.md). Project-specific Requirements, Design, Constraints, and baseline adherence are evaluated separately as **project conformance**. PriFly lifecycle state, authority, independence, and promotion rules are separately **workflow policy**.

```text
QUALITY
standards-backed rubric
        +
CONFORMANCE
project-specific requirements/design/constraints
        +
WORKFLOW
PriFly lifecycle/authority/independence rules
        ↓
may the artifact advance?
```

A project-specific architecture rule is therefore not turned into an “industry rubric.” A Reviewer checks that rule as conformance while independently evaluating the artifact's general engineering quality with the applicable profiles below.

## Evaluation contract

Each consequential evaluation binds at least:

```text
rubric_profile_id + rubric_version
artifact kind + exact artifact revision/identity
pinned Standards Source IDs/versions
evaluator identity
criterion results
evidence references
started/completed time
aggregate disposition
```

Each criterion resolves to exactly one of:

- `PASS` — adequate evidence establishes that the criterion is satisfied;
- `FAIL` — evidence establishes a material criterion violation;
- `NOT_APPLICABLE` — the declared applicability rule proves the criterion does not apply;
- `UNKNOWN` — the evaluator cannot establish PASS/FAIL/N/A from admitted evidence/source interpretation.

For an applicable blocking profile, `FAIL` blocks promotion and unresolved `UNKNOWN` blocks promotion. `NOT_APPLICABLE` is not a synonym for “not checked.”

Rubric profiles are versioned. A historical evaluation remains bound to the version used at the time. Criteria cannot be retrospectively changed merely because a newer standards edition or rubric version is later adopted.

## Source resolution and ambiguity

An evaluator uses the normalized criteria below first. If interpretation is materially ambiguous:

1. resolve the exact `Source ID` through [standards-registry.md](standards-registry.md);
2. consult the pinned official source/version and available official implementation guidance;
3. prefer specific official guidance over model recollection or third-party summaries;
4. do not silently substitute a draft/newer edition;
5. if the ambiguity still cannot be resolved, return `UNKNOWN` rather than inventing a quality rule.

Where a standard identifies a dimension/measure but leaves acceptable values to the project, the threshold must already exist in the governing Planning Baseline before affected delivery work is released.

---

# Core reusable profiles

## `stakeholder-need-quality/v1`

**Purpose:** determine whether an owner/stakeholder need is good enough to drive requirements work without prematurely becoming an implementation prescription.

**Sources:** `STD-29148-2018`, `STD-25019-2023`.

A need is quality-complete when:

- **SN-01 Purpose/outcome** — the intended stakeholder outcome or problem is explicit enough to distinguish success from unrelated activity.
- **SN-02 Stakeholder** — affected stakeholder/user classes are identified to the extent needed for the decision.
- **SN-03 Context of use** — relevant environment, operating context, user/task context, or usage assumptions are explicit when they affect desired outcomes.
- **SN-04 Boundary** — the system/product/project boundary is sufficiently clear to distinguish in-scope from out-of-scope behavior.
- **SN-05 Constraints** — known external constraints that materially shape acceptable solutions are captured as constraints rather than hidden assumptions.
- **SN-06 Observable success intent** — the need is concrete enough that downstream measurable/verifiable requirements can be derived from it.
- **SN-07 Unknowns** — material uncertainty is represented explicitly rather than being silently guessed away.
- **SN-08 Solution neutrality** — implementation detail is not embedded as a stakeholder need unless the implementation choice is itself externally mandated.

This profile establishes readiness for requirements engineering, not Design Completeness.

## `requirement-quality/v1`

**Purpose:** judge individual Requirements and a requirement set before they may support a Design Baseline.

**Sources:** `STD-29148-2018`, `GUIDE-NASA-SWE050`.

An individual Requirement must satisfy, as applicable:

- **RQ-01 Identity** — stable unique identity exists.
- **RQ-02 Necessity** — the Requirement is needed to satisfy an identified stakeholder need, higher-level Requirement, external obligation, risk treatment, or justified derived need.
- **RQ-03 Correctness** — it accurately expresses the intended required behavior/condition.
- **RQ-04 Clarity** — wording is understandable and does not rely on unexplained ambiguity.
- **RQ-05 Singularity** — the statement is sufficiently atomic to evaluate without hiding unrelated obligations in one Requirement.
- **RQ-06 Consistency** — it does not conflict with other governing Requirements/Constraints.
- **RQ-07 Feasibility** — evidence does not indicate that the Requirement is impossible under known project/technical constraints.
- **RQ-08 Implementation neutrality** — it states the required outcome/condition rather than prescribing design unless design is genuinely mandated.
- **RQ-09 Measurability/boundedness** — measurable values, ranges, tolerances, timing, quantities, or other bounds are supplied when the nature of the Requirement calls for them.
- **RQ-10 Verifiability** — an objective method can establish whether the Requirement is satisfied.
- **RQ-11 Upstream traceability** — source/stakeholder/higher-level derivation is known.
- **RQ-12 Downstream traceability** — the Requirement can be traced into Design, delivery Outcomes, and Verification as those artifacts exist.
- **RQ-13 Operational conditions** — nominal, off-nominal, adverse, boundary, or prohibited behavior is represented where material to the Requirement.
- **RQ-14 Approval state** — the Requirement's governing authority/review state is known; draft text does not silently become binding.

The requirement **set** additionally satisfies:

- **RQ-15 Coverage/completeness** — all applicable stakeholder needs/mandatory concern families have Requirement coverage or explicit disposition.
- **RQ-16 Set consistency** — the set is conflict-free or conflicts are explicitly unresolved/blocking.
- **RQ-17 Appropriate decomposition** — parent/child decomposition is coherent and does not lose or invent required meaning.
- **RQ-18 Duplicate/overlap control** — duplicates or materially overlapping Requirements are reconciled so verification/ownership is not ambiguous.

## `quality-requirement-quality/v1`

**Purpose:** make quality attributes objective instead of leaving “nonfunctional” expectations as adjectives.

**Sources:** `STD-25030-2019`, `STD-25010-2023`, `STD-25019-2023`, `STD-25023-2016`.

An applicable quality Requirement satisfies:

- **QR-01 Quality dimension** — applicable product-quality or quality-in-use characteristic/subcharacteristic is identified or an equivalently precise project quality dimension is justified.
- **QR-02 Context** — operating/context-of-use conditions relevant to the quality expectation are identified.
- **QR-03 Measure** — the property is tied to a defined measure/measurement method where objective measurement is possible.
- **QR-04 Target** — acceptable target, range, threshold, or ordinal rule is fixed before affected Work Items are released.
- **QR-05 Evaluation method** — how the target will be evaluated is identified.
- **QR-06 Acceptance relationship** — the quality Requirement's role in product acceptance is explicit.
- **QR-07 Trade-offs** — material conflicts/trade-offs with other quality characteristics are identified and dispositioned rather than hidden.
- **QR-08 Traceability** — the quality Requirement traces into architectural decisions, Verification/Validation, and product-quality evaluation as applicable.

ISO/IEC 25023 deliberately does not define universal acceptable values for its measures. PriFly therefore treats an unset project threshold as `UNKNOWN`, not permission for a later Reviewer to invent one.

## `plan-quality/v1`

**Purpose:** judge whether a delivery/project plan is an adequate basis for execution.

**Sources:** `STD-16326-2019`, `GUIDE-NASA-SWE013`, `STD-12207-2026`.

NASA's operational quality model is retained explicitly: a plan must be **complete, correct, workable, consistent, and verifiable**.

- **PL-01 Complete** — all required work/process obligations within plan scope are represented or explicitly delegated to another governed plan/artifact.
- **PL-02 Correct** — planned activities accurately implement the governing scope, Requirements, Design, policy, and declared lifecycle approach.
- **PL-03 Workable** — sequencing, dependencies, roles, resources/capacity assumptions, environments, and constraints form a credible executable plan.
- **PL-04 Consistent** — the plan does not contradict itself or other governing plans/baselines.
- **PL-05 Verifiable** — completion/progress can be objectively established rather than inferred from narrative status.
- **PL-06 Scope/objectives** — scope, objectives, boundaries, and major deliverables/outcomes are explicit.
- **PL-07 Responsibilities** — ownership/responsibility for required activities is defined.
- **PL-08 Dependencies/interfaces** — relevant dependencies, external interfaces, sequencing constraints, and integration points are identified.
- **PL-09 Risk/uncertainty** — material risks/assumptions affecting plan feasibility are represented and linked to treatment/monitoring.
- **PL-10 Assurance/V&V** — verification, validation, review, quality/security, and acceptance activities required by scope are planned.
- **PL-11 Change/configuration** — change/configuration control obligations are represented where applicable.
- **PL-12 Information/support** — documentation, rollout, operations/support, maintenance, or retirement obligations are represented when applicable.
- **PL-13 Standards/procedures** — standards/procedures the work claims to follow are identified rather than assumed.

## `architecture-description-quality/v1`

**Purpose:** judge whether an architecture description is sufficient to communicate and govern the architecture that downstream work must implement.

**Sources:** `STD-42010-2022`, `GUIDE-NASA-SWE057`, `STD-25010-2023`.

- **AD-01 Entity/boundary** — the entity/system of interest and relevant environment/boundaries are identified.
- **AD-02 Stakeholders** — architecture-relevant stakeholders are identified.
- **AD-03 Concerns** — architecture-relevant stakeholder concerns are explicit and addressed by appropriate views/models/decisions.
- **AD-04 Requirements/qualities** — driving functional Requirements and quality Requirements trace into architectural decisions.
- **AD-05 Structure** — major elements/components/subsystems and their responsibilities/properties are identified to the level needed for the architecture's purpose.
- **AD-06 Relationships** — material relationships/dependencies/interactions between architectural elements are described.
- **AD-07 Interfaces** — important internal/external interfaces and ownership/contracts are identified.
- **AD-08 Viewpoint/model adequacy** — each architecture view/model has a clear concern/purpose and provides the information necessary for that concern.
- **AD-09 Cross-view consistency** — models/views do not materially contradict one another.
- **AD-10 Constraints/assumptions** — architecture-shaping constraints and assumptions are explicit.
- **AD-11 Alternatives/rationale** — meaningful alternatives and the rationale for consequential architecture choices are captured where a real choice existed.
- **AD-12 Risks/trade-offs** — material architecture risks and quality trade-offs are represented.
- **AD-13 Evolution/change impact** — architectural dependencies/rules are sufficiently clear to support impact analysis and consistent evolution.
- **AD-14 Verification/conformance points** — architecture obligations are expressed precisely enough that downstream conformance can be checked.

This profile evaluates the quality of the architecture **description**. Whether a later implementation obeys that architecture is project conformance, not another architecture-quality criterion.

## `architecture-evaluation-quality/v1`

**Purpose:** judge whether an architecture evaluation is an adequate basis for accepting/challenging a Design Baseline.

**Source:** `STD-42030-2019`.

- **AE-01 Exact subject** — evaluated architecture/revision and evaluation scope are explicit.
- **AE-02 Evaluation purpose** — stakeholder concerns/questions/intended-purpose claims being evaluated are explicit.
- **AE-03 Criteria/method** — scenarios, criteria, measures, analysis methods, or review methods used are declared and appropriate to the concern.
- **AE-04 Evidence** — conclusions trace to evidence rather than evaluator preference alone.
- **AE-05 Concern coverage** — every concern required by the evaluation scope has a disposition.
- **AE-06 Quality/intended purpose** — evaluation addresses whether the architecture is fit for the declared intended purpose and relevant quality objectives.
- **AE-07 Risks/opportunities** — evaluation surfaces material architecture risk, weakness, uncertainty, or opportunity rather than only summarizing strengths.
- **AE-08 Findings** — findings identify the subject/problem/evidence and are specific enough for disposition.
- **AE-09 Uncertainty** — unsupported assumptions or unavailable evidence become explicit uncertainty/`UNKNOWN` rather than an implicit pass.
- **AE-10 Conclusion** — final verdict follows from the evaluated criteria/findings and identifies residual concerns.

## `risk-record-quality/v1`

**Purpose:** judge whether a Risk is useful enough for engineering decision-making and ongoing control.

**Source:** `STD-16085-2021`.

- **RK-01 Risk subject** — affected product/process/decision/scope is clear.
- **RK-02 Cause/event/consequence** — the risk statement distinguishes source/cause, uncertain event/condition, and material consequence sufficiently for treatment.
- **RK-03 Likelihood/uncertainty** — probability/likelihood or uncertainty is assessed using the project's declared scale/method.
- **RK-04 Impact** — technical, safety/security, cost, schedule, operational, quality, or other relevant impact is assessed using the declared method.
- **RK-05 Priority/exposure** — relative priority is derived from the declared risk method rather than intuition alone.
- **RK-06 Treatment** — avoidance/mitigation/transfer/acceptance or other treatment is explicit where action is required.
- **RK-07 Owner** — accountable owner exists.
- **RK-08 Triggers/monitoring** — conditions, indicators, or review cadence for reassessment are defined when relevant.
- **RK-09 Residual risk** — expected residual risk after treatment is explicit when treatment does not eliminate the risk.
- **RK-10 Traceability** — related Requirements, Decisions, Design, Work Items, evidence, and acceptance/owner actions are linked as applicable.

## `evidence-provenance-quality/v1`

**Purpose:** judge whether a Research Claim, verification observation, metric, or other evidence can be trusted, revisited, and interpreted in context.

**Source:** `STD-PROV-DM`.

- **EV-01 Entity identity** — evidence/source entity is identifiable rather than an unattributed assertion.
- **EV-02 Activity provenance** — the research/measurement/test/transformation activity that produced or retrieved the evidence is represented when material.
- **EV-03 Agent responsibility** — responsible producer/collector/Worker/tool is identifiable when relevant to trust/independence.
- **EV-04 Derivation** — derived evidence/claims can be related back to source evidence/entities.
- **EV-05 Source locator** — official/stable locator exists when the source supports one.
- **EV-06 Temporal context** — acquisition/observation/valid-as-of time is recorded where freshness matters.
- **EV-07 Transformation context** — material transformations, summaries, normalization, filtering, or computation between source and derived claim are represented.
- **EV-08 Integrity identity** — immutable content hash/version/object identity is retained when byte-level evidence identity matters.
- **EV-09 Conflicts/limitations** — conflicting evidence, missing coverage, uncertainty, or known limitations are not hidden.
- **EV-10 Reproducibility of interpretation** — another evaluator can determine what evidence was used and why it supports the associated claim/result.

## `verification-plan-quality/v1`

**Purpose:** judge whether proposed Verification can objectively establish that a work product conforms to its specified Requirements/Outcomes.

**Sources:** `STD-1012-2024`, `STD-29119-2-2021`, `GUIDE-NASA-SWE028`.

- **VP-01 Verification subject** — exact Requirement/Outcome/work product property being verified is identified.
- **VP-02 Verification objective** — the property to be established is explicit; a command/tool name alone is not a verification objective.
- **VP-03 Appropriate method** — analysis, inspection, demonstration, test, or other method is appropriate to the property and risk/integrity context.
- **VP-04 Environment/configuration** — environment/configuration/base/runtime conditions that materially affect evidence are defined.
- **VP-05 Inputs/preconditions** — required data, setup, fixtures, states, and preconditions are defined.
- **VP-06 Observable result** — expected observable behavior/measurement is explicit.
- **VP-07 Objective criterion** — pass/fail, numeric range, boolean condition, tolerance, or other objective satisfaction rule is predeclared where possible.
- **VP-08 Coverage basis** — required scenarios, boundaries, failure modes, paths, configurations, or other coverage are derived from Requirements/risk rather than convenience.
- **VP-09 Independence** — required evaluator/runner independence is defined according to governing risk/integrity/project policy.
- **VP-10 Evidence retention** — evidence required to support later Review/Acceptance is identified.
- **VP-11 Tool/runner identity** — tool/version/runner identity is fixed when it can materially change the result.
- **VP-12 Exception/skip handling** — skipped/unavailable verification cannot silently count as pass; allowed exception/disposition paths are explicit.
- **VP-13 Traceability** — Verification maps back to exact Requirements/Outcomes and forward to evidence/results.

## `validation-plan-quality/v1`

**Purpose:** judge whether proposed Validation can establish that the product satisfies intended use and stakeholder/user needs in its intended context.

**Sources:** `STD-1012-2024`, `GUIDE-NASA-SWE029`, `STD-25019-2023`.

- **VA-01 Intended use** — user/stakeholder need or intended-use claim being validated is explicit.
- **VA-02 Context/environment** — intended environment and relevant context-of-use are represented.
- **VA-03 Representative scenarios** — scenarios/tasks/data are representative enough to exercise the intended use and relevant adverse/boundary conditions.
- **VA-04 Method** — demonstration, operational exercise, test, analysis, prototype, or other method is appropriate to the intended-use claim.
- **VA-05 Objective criteria** — acceptance/satisfaction criteria and relevant quality-in-use measures/targets are predeclared.
- **VA-06 Representative configuration** — product/configuration used is sufficiently representative of what will be accepted/delivered.
- **VA-07 Evidence** — required observed evidence and provenance are defined.
- **VA-08 Independence** — required validation independence is defined by governing policy/risk.
- **VA-09 Failure/discrepancy handling** — failed/partial intended-use claims become explicit Findings/deviations rather than narrative caveats.
- **VA-10 Traceability** — validation evidence traces to stakeholder needs/intended use and downstream acceptance.

## `product-quality-evaluation/v1`

**Purpose:** judge whether product/system quality has been evaluated rigorously enough to support acceptance or improvement.

**Sources:** `STD-25010-2023`, `STD-25023-2016`, `STD-25040-2024`, `STD-25030-2019`.

- **PQ-01 Quality model applicability** — relevant product-quality characteristics/subcharacteristics are explicitly selected/dispositioned.
- **PQ-02 Predeclared requirements** — evaluation uses quality Requirements/targets fixed before evaluation; it does not invent a favorable threshold after observing results.
- **PQ-03 Evaluation subject** — exact product/build/configuration/context is identified.
- **PQ-04 Measures/methods** — defined measures and evaluation methods are appropriate to each applicable quality Requirement.
- **PQ-05 Evidence/provenance** — observations are retained with sufficient evidence/provenance to support the evaluation conclusion.
- **PQ-06 Coverage** — every quality Requirement required for this acceptance/evaluation scope is evaluated or explicitly unresolved.
- **PQ-07 Result against target** — observed value/result is compared with the predeclared target/range/rule.
- **PQ-08 Uncertainty/limitations** — measurement uncertainty, environmental limitations, skipped measures, or incomplete coverage are explicit.
- **PQ-09 Residual deficiencies** — quality deficiencies and accepted residual limitations are represented rather than averaged into an aggregate pass.
- **PQ-10 Evaluation conclusion** — conclusion follows from the individual quality Requirement results and declared acceptance policy.

## `security-engineering-quality/v1`

**Purpose:** judge whether secure software-development obligations were integrated into the lifecycle rather than added as a late penetration-test step.

**Core source:** `STD-SSDF-1.1`.

- **SE-01 Security governance/preparation** — applicable secure-development roles, policies, tooling/process expectations, and risk inputs are identified for the work scope.
- **SE-02 Security Requirements/risks** — material security needs/threats/risks trace into Requirements, Constraints, Design, Verification, or accepted residual risk.
- **SE-03 Protection of development assets** — source, artifacts, credentials/secrets, and development/build environments receive the protections required by the selected security profile.
- **SE-04 Secure production practices** — design/implementation/review/testing practices required to prevent or detect vulnerabilities are selected and evidenced.
- **SE-05 Third-party/reused components** — applicable provenance, vulnerability, licensing/security, and update obligations for reused/third-party components are addressed.
- **SE-06 Vulnerability handling** — discovered vulnerabilities/findings have triage, remediation, disclosure/response, and recurrence-prevention paths as applicable.
- **SE-07 Evidence** — claimed secure-development practices are supported by evidence rather than self-attestation alone when verification is required.
- **SE-08 Exceptions/residual risk** — unfulfilled security criteria require explicit disposition/risk authority rather than silent acceptance.

For a web application/API with `STD-ASVS-5.0.0` activated, the security profile additionally pins the exact ASVS versioned requirement identifiers and required verification level/profile before they become blocking. The evaluator records each selected ASVS requirement separately; PriFly does not restate the whole ASVS in this document.

For a web UI with `STD-WCAG-2.2` activated, the project/policy must pin the target conformance level before release. WCAG success criteria at or below that level become directly evaluable criteria rather than being paraphrased into a competing accessibility checklist.

For a distributable build with `STD-SLSA-1.2` activated, the project/policy pins the required SLSA track/level and evidence/attestation expectations before they become blocking.

## `implementation-quality/v1`

**Purpose:** judge implementation workmanship without inventing one universal PriFly coding style.

**Sources:** `GUIDE-NASA-SWE061`, `STD-25010-2023`, `STD-SSDF-1.1`; plus the Project's selected official language/repository coding standards.

- **IM-01 Coding profile selected** — applicable language/framework/repository coding methods, standards, and criteria are declared before implementation evaluation.
- **IM-02 Coding-profile adherence** — no undispositioned violation of the selected coding profile remains.
- **IM-03 Required build/static/tool checks** — checks mandated by the coding/security/project profile pass or have explicit Findings/disposition.
- **IM-04 Requirement/design traceability** — changed implementation can be related to the Work Item/Requirement/Design obligations it realizes.
- **IM-05 Quality-sensitive implementation** — implementation satisfies the code-level obligations derived from applicable product-quality Requirements (for example maintainability, performance, compatibility, reliability) rather than treating quality as test-only.
- **IM-06 Security-sensitive implementation** — applicable secure coding/dependency/secret/error-handling requirements from the selected security profile are satisfied.
- **IM-07 Reused/generated code obligations** — generated, vendored, reused, or third-party code has the required provenance/compliance treatment for the project.
- **IM-08 No hidden exception** — waived checks, unsupported configurations, known defects, or temporary bypasses are explicit Findings/Constraints rather than hidden in implementation detail.

Whether the implementation matches the project's specific Design is evaluated separately as project conformance.

## `review-inspection-quality/v1`

**Purpose:** judge whether a review/inspection itself was competent and complete enough to support a lifecycle decision.

**Sources:** `GUIDE-NASA-SWE087`, `STD-1012-2024`.

- **RV-01 Exact subject** — reviewed artifact/revision/scope is explicit.
- **RV-02 Readiness** — required inputs/evidence/rubrics exist before the review claims to start.
- **RV-03 Appropriate perspectives** — reviewer expertise/perspectives are appropriate to the artifact and risk.
- **RV-04 Applicable rubrics used** — artifact-specific standards-backed quality profiles are actually evaluated rather than replaced by free-form opinion.
- **RV-05 Project conformance checked** — governing Requirements/Design/Constraints/baseline adherence is checked separately from general quality.
- **RV-06 Technical focus** — review addresses technical integrity/quality and not merely formatting/status presentation.
- **RV-07 Evidence-backed Findings** — Findings identify exact subject/problem/evidence and are actionable/dispositionable.
- **RV-08 Action tracking** — required corrective actions/Findings remain tracked until appropriate disposition; review completion cannot hide unresolved blockers.
- **RV-09 Completion criteria** — review has explicit completion/pass/fail conditions and applies them consistently.
- **RV-10 Outcome record** — outcome, evaluator identity, rubric versions, evidence, Findings, and unresolved uncertainty are recorded.
- **RV-11 Independence** — independence requirements established by governing V&V/workflow policy are satisfied.

## `acceptance-quality/v1`

**Purpose:** judge whether an acceptance decision is based on adequate, predeclared, measurable evidence rather than a producer's declaration of completion.

**Sources:** `GUIDE-NASA-SWE034`, `STD-25010-2023`, `STD-25040-2024`, `STD-1012-2024`.

- **AC-01 Criteria predeclared** — acceptance criteria existed before observing the final candidate/result.
- **AC-02 Criteria measurable/objective** — each blocking criterion has a defined observable/measure/range/pass rule appropriate to the Requirement.
- **AC-03 Exact subject** — product/build/configuration/baseline being accepted is exact and current.
- **AC-04 Required V&V complete** — required verification and validation have completed for the acceptance scope.
- **AC-05 Product-quality Requirements satisfied** — applicable correctness/performance/reliability/availability/compatibility/maintainability/security/etc. claims are evaluated through their selected product-quality Requirements/profile rather than generic confidence.
- **AC-06 Documentation/configuration readiness** — required as-built information, user/operator information, release/configuration identity, licenses/rights or analogous acceptance deliverables are current where applicable.
- **AC-07 Deviations/findings** — unresolved defects/deviations/Finding dispositions are explicit; blockers cannot disappear inside an aggregate score.
- **AC-08 Residual risk** — material residual risk has the authority/disposition required by project policy.
- **AC-09 Evidence provenance** — acceptance conclusion traces to independent/credible evidence appropriate to the criterion.
- **AC-10 Decision record** — final acceptance outcome, criteria results, exceptions, evidence, and decision authority are recorded.

PriFly's exact Acceptance Certificate/evidence ordering is workflow/project conformance around this quality decision; it is not itself an external acceptance-quality rubric.

## `change-impact-quality/v1`

**Purpose:** judge whether a proposed change has been analyzed thoroughly enough before a baseline/project decision.

**Sources:** `STD-12207-2026`, `GUIDE-NASA-SWE053`, `STD-16085-2021`.

- **CH-01 Change identity/rationale** — proposed semantic change, requester/cause, and reason are explicit.
- **CH-02 Exact baseline/subjects** — affected baseline/Requirements/Design/product versions are identified.
- **CH-03 Traceability impact** — upstream/downstream requirements, design, interfaces, implementation, tests/verification, documentation, and other related work products are analyzed using available traceability.
- **CH-04 Technical impact** — architecture, behavior, interfaces, performance, reliability, compatibility, security/safety, data/migration, operational or other technical impacts are evaluated as applicable.
- **CH-05 Cost/resource impact** — rework/new effort, skills/resources, capacity/cost impacts are evaluated when material.
- **CH-06 Schedule/dependency impact** — sequencing, milestone/dependency, rollout/transition impacts are evaluated when material.
- **CH-07 Stakeholder impact** — affected users/owners/providers/operators/other stakeholders are identified when material.
- **CH-08 Risk impact** — new/changed risks and residual risks are evaluated.
- **CH-09 V&V/documentation impact** — required re-verification/re-validation and information updates are identified.
- **CH-10 Analysis evidence** — impact conclusion is documented with enough evidence/provenance to review.
- **CH-11 Uncertainty** — impact that cannot be proven becomes explicit `UNKNOWN`, not assumed unaffected.

## `documentation-quality/v1`

**Purpose:** judge lifecycle information and user-facing information for completeness/usefulness without forcing every information item to be a separate document.

**Sources:** `STD-15289-2019`; when user information is in scope, `STD-26514-2022` and/or `STD-26515-2018`.

- **DO-01 Purpose/audience** — information item's purpose and intended audience/use are identifiable.
- **DO-02 Required content** — information needed for the lifecycle/user task is present or explicitly linked to an authoritative structured source.
- **DO-03 Correct/current** — information matches the current authoritative product/configuration/process state for its claimed revision.
- **DO-04 Consistent** — information does not materially contradict governing Requirements/Design/other authoritative information.
- **DO-05 Traceable/source-backed** — consequential technical claims can be traced to their governing source/evidence when needed.
- **DO-06 Findable/navigation** — intended users can locate the information and related authoritative detail.
- **DO-07 Task suitability** — user-facing information supports the actual concepts/tasks/reference needs of intended users rather than merely describing implementation internals.
- **DO-08 Format/presentation suitability** — structure/format/media are usable for the intended information task/context.
- **DO-09 Maintenance ownership** — update trigger/owner/version relationship is known for information that must remain current.
- **DO-10 No duplicate authority** — documentation does not create an ungoverned competing source of truth where canonical structured state already exists.

## `estimate-quality/v1`

**Purpose:** judge whether an estimate is a credible decision input rather than unsupported precision.

**Source:** `GUIDE-GAO-20-195G`.

- **ES-01 Purpose/scope** — estimate purpose, decision use, scope, and time horizon are explicit.
- **ES-02 Technical baseline** — estimate is tied to a defined technical/product/planning baseline rather than an undefined future scope.
- **ES-03 Work decomposition/basis** — estimated work/content is structured enough to show what is included/excluded.
- **ES-04 Ground rules/assumptions** — material assumptions and constraints are explicit.
- **ES-05 Source data** — input data and provenance/basis are identified.
- **ES-06 Methodology** — estimating method/model is explained and appropriate to available data/maturity.
- **ES-07 Range/uncertainty** — uncertainty/risk is represented; unsupported point precision is not presented as certainty.
- **ES-08 Sensitivity/risk analysis** — major estimate drivers and sensitivity/risks are identified when material.
- **ES-09 Documentation/reproducibility** — another reviewer can understand how the estimate was produced.
- **ES-10 Update/calibration** — estimates intended for ongoing management can be compared with actuals and revised without erasing historical accuracy evidence.

## `closure-quality/v1`

**Purpose:** judge whether a project/Initiative can credibly claim that its intended delivery is complete, validated, documented, and transition-ready.

**Sources:** `STD-12207-2026`, `STD-1012-2024`, `STD-25040-2024`, `STD-15289-2019`.

- **CL-01 Requirement/accounting completeness** — required stakeholder/technical/product-quality Requirements for the closure scope are satisfied or have authorized residual disposition.
- **CL-02 Required V&V** — required verification/validation is complete for the delivered system/release/Initiative scope.
- **CL-03 Acceptance state** — required acceptance decisions are complete and current.
- **CL-04 Configuration/as-built state** — delivered configuration and relevant baselines/version identities are known.
- **CL-05 Outstanding findings/deviations** — remaining defects/Findings/deviations are explicitly dispositioned; no blocker is hidden by closure.
- **CL-06 Residual risk** — residual risks are explicit, owned, and accepted/transferred/treated as required.
- **CL-07 Information readiness** — required lifecycle/user/operator/support information is complete/current.
- **CL-08 Operational/support/transition obligations** — deployment/transition/support/maintenance/retirement obligations required by scope have explicit completion/disposition.
- **CL-09 Evidence preservation** — required acceptance/verification/configuration evidence remains available according to governing retention/recovery policy.
- **CL-10 Closure record** — closure decision and unresolved residuals are recorded rather than inferred from “all tickets closed.”

DORA delivery metrics may be attached as diagnostic observations for lessons/continuous improvement, but they do not add universal closure pass/fail thresholds.

---

# Lifecycle composition

The following table maps PriFly lifecycle points to reusable **quality** profiles. Project conformance and workflow conditions are evaluated alongside these profiles but are not duplicated here.

| Lifecycle point / artifact | Required general quality profiles | Conditional overlays |
|---|---|---|
| Owner/stakeholder intent ready for planning | `stakeholder-need-quality/v1`, relevant `evidence-provenance-quality/v1` | quality-in-use context through `STD-25019-2023` when relevant |
| Research Claim accepted as planning evidence | `evidence-provenance-quality/v1` | source/domain-specific evidence standards if adopted by project |
| Requirement accepted into planning baseline | `requirement-quality/v1` | `quality-requirement-quality/v1`, `security-engineering-quality/v1` as applicable |
| Quality Requirement accepted | `requirement-quality/v1`, `quality-requirement-quality/v1` | WCAG/ASVS/etc. when applicable |
| Risk accepted into planning | `risk-record-quality/v1` | security/safety-specific risk standards if adopted |
| Architecture description ready for Design Gate | `architecture-description-quality/v1` | `security-engineering-quality/v1` when trust/security architecture applies |
| Architecture evaluation / Design Completeness challenge | `architecture-evaluation-quality/v1` plus quality profiles for the artifacts it evaluates | conditional quality/security/accessibility overlays |
| Estimate used for planning/scheduling/capacity decision | `estimate-quality/v1` | none by default |
| Delivery plan / decomposition ready for Delivery Readiness | `plan-quality/v1`, `verification-plan-quality/v1`, `risk-record-quality/v1` for material risks | `security-engineering-quality/v1`, `documentation-quality/v1` as applicable |
| Work Item contract quality | `requirement-quality/v1` applied to Required Outcomes/Constraints where semantically applicable; `verification-plan-quality/v1` for Verification | project/product overlays |
| Implementation work product review | `implementation-quality/v1`, `review-inspection-quality/v1` | security/ASVS/WCAG/SLSA/project coding profile as applicable |
| Verification execution/result review | `verification-plan-quality/v1`, `review-inspection-quality/v1`, `evidence-provenance-quality/v1` | product/security profiles relevant to verified Requirement |
| Validation execution/result review | `validation-plan-quality/v1`, `review-inspection-quality/v1`, `evidence-provenance-quality/v1` | product-quality-in-use profiles |
| Candidate/product acceptance | `acceptance-quality/v1`, `product-quality-evaluation/v1`, applicable V&V profiles | security/accessibility/supply-chain/user-information overlays |
| Change Request / impact analysis | `change-impact-quality/v1`, updated `risk-record-quality/v1` where material | security/product-quality overlays if affected |
| Lifecycle/user documentation acceptance | `documentation-quality/v1` | WCAG when web-delivered information is in scope |
| Initiative/release closure | `closure-quality/v1`, `documentation-quality/v1`, relevant acceptance/product-quality profiles | operational/security/support profiles as applicable |

## Gate composition examples

### Design Completeness

The standards-backed quality side of the Design Completeness decision normally requires successful evaluations for:

- stakeholder/Requirement quality;
- applicable quality-Requirement quality;
- architecture-description quality;
- architecture-evaluation quality;
- risk quality;
- evidence/provenance quality for consequential research claims;
- security-engineering quality where security/trust concerns apply.

PriFly then separately applies project conformance (traceability to owner need/Requirements/Decisions/Constraints) and workflow policy (mandatory-concern coverage, authority, blocking `UNKNOWN`, fresh challenge, etc.).

### Delivery Readiness

The standards-backed quality side normally requires:

- plan quality;
- verification-plan quality;
- estimate quality where estimates influence scheduling/capacity;
- risk quality;
- applicable security/documentation quality planning.

PriFly separately checks project conformance (all baseline obligations covered; Work Items faithfully implement the baseline) and workflow policy (dependency graph, slicing/enabler rules, reviewer independence, no blockers, etc.).

### Candidate acceptance

The standards-backed quality side normally requires:

- acceptance quality;
- required Verification/Validation quality;
- applicable product-quality evaluation;
- evidence/provenance quality;
- applicable security/accessibility/supply-chain/documentation quality.

PriFly separately checks exact project conformance and its own Acceptance Certificate/evidence/publication lifecycle.

## Threshold policy

Some external standards provide directly testable conformance criteria; others define dimensions/measures/process quality while intentionally leaving thresholds to the project.

PriFly therefore uses this rule:

> **No evaluator may invent an acceptance threshold after work has begun. Any project-specific threshold needed to turn an applicable standards-backed quality dimension into PASS/FAIL must be present in the governing Planning Baseline before affected Work Items are released.**

Examples include latency/performance limits, availability targets, acceptable defect/security-risk levels, compatibility scope, product-quality measure ranges, and the exact WCAG/ASVS/SLSA target profile when those conditional overlays apply.

## What this document deliberately does not contain

- PriFly-specific durability/provider/authority rules — those are system/project conformance and workflow policy.
- a duplicate of ISO/IEEE copyrighted text;
- universal thresholds that the source standard intentionally leaves context-specific;
- heuristic frameworks presented as standards;
- model-created “best practices” that lack a pinned authoritative source.
