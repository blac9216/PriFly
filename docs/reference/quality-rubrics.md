# Engineering quality rubrics

Kind: reference

## Detailed general engineering rubric inventory

## Effective criterion descriptors and policy bindings

The nineteen `/v1` inventories below preserve the PRD's exact criterion identities and questions.
For a particular evaluation, each effective criterion descriptor resolves:

- profile/criterion version and normalized question;
- exact official source/version and reviewed locator/derivation, including access limitations;
- artifact kind, lifecycle phase, applicability rule and N/A evidence;
- required evidence, method and any project-baselined threshold;
- result, rationale, exact subject and evidence references.

Profile-level source references and evaluator/output descriptions are inherited by their rows.
The row supplies its evidence question; an admitted descriptor supplies any further precision
required to reach an objective result. Unresolved interpretation is `UNKNOWN`, not fabricated
clause authority. [Standards registry](standards-registry.md) governs sources and updates.

The separate **policy binding** selects the criterion version, required/advisory effect, gate,
independence and authority. It cannot rewrite the engineering question to make a candidate pass.
Project-specific rules belong in conformance; phase permission belongs in workflow eligibility.

## Lifecycle application

This map identifies applicable families, not a claim that any current artifact passed them.
Scope-specific policy pins every actual profile version and threshold before evaluation.

| Artifact/phase | Core profiles to resolve |
|---|---|
| Owner need and requirements | stakeholder-need, requirement, quality-requirement, evidence-provenance |
| Architecture and design package | architecture-description, architecture-evaluation, risk-record, requirement/quality-requirement, evidence-provenance, documentation, applicable security-engineering |
| Delivery package | plan, verification-plan, validation-plan where applicable, estimate, risk-record, documentation |
| Implementation and independent review | implementation, review-inspection, evidence-provenance, applicable security-engineering and documentation |
| Candidate acceptance/product evaluation | acceptance, product-quality-evaluation, applicable verification/validation-plan and security-engineering |
| Material change | change-impact plus every affected artifact's profiles |
| Release and closeout | closure, acceptance, documentation and applicable product-quality-evaluation |

All names above refer to the full `*-quality/v1` IDs below (the product evaluation ID is
`product-quality-evaluation/v1`). WCAG/ASVS/SLSA and user-information overlays require explicit
project applicability and target selection. Runtime evidence not yet available at design time is
recorded as a future qualification obligation; a design-stage criterion requiring feasibility
evidence is not automatically excused by calling the artifact “documentation.”

### How to use this inventory

The following profiles preserve the adopted local criterion identities from PriFly's standards-backed reference [P3](source-register.md#source-p3). They are normalized engineering questions, not copied ISO/IEEE clauses, a claim of full formal conformance, or a list of new project-specific architecture rules. The source references identify the standard families and public official guidance that support the profiles. When a precise clause-level interpretation is needed, the source-access and ambiguity procedure in [Section 10](../explanation/engineering-quality.md#engineering-quality-standards-and-mechanical-application) applies.

Each row is evaluated against an exact artifact and its declared scope/phase. Evidence can be a specific passage, trace relationship, analysis, measurement, test observation, approved external constraint, or other admitted artifact. A bare “yes” without supporting evidence is not a complete result. A criterion result is `PASS`, `FAIL`, `NOT_APPLICABLE`, or `UNKNOWN`, with a reason and evidence references. Gate policy determines which applicable results are blocking; the evaluator does not invent that policy after reviewing the artifact.

Source categories are kept separate. ISO/IEEE documents provide published engineering frameworks; NASA pages provide official operational guidance; NIST, W3C, OWASP, and SLSA supply their respective published practices/specifications. The local normalized questions still require reviewed source mapping. An official catalog page verifies identity and scope, not access to the entire paid standard.

### Stakeholder need quality — `stakeholder-need-quality/v1`

**Sources:** ISO/IEC/IEEE 29148:2018 [S12](source-register.md#source-s12); ISO/IEC 25019:2023 [S15](source-register.md#source-s15).

**Evaluated by:** Reviewer when needs are accepted into planning; Architect uses the same profile while preparing them.

**Output:** explicit, usable input to requirements engineering—not a prematurely prescribed implementation.

| ID | Evaluation question and required evidence |
|---|---|
| SN-01 | Is the purpose or desired outcome explicit? Point to the problem and the intended change in user/system behavior. |
| SN-02 | Are the affected stakeholder/user classes identified? Show whose need is being represented. |
| SN-03 | Is material context of use described? Identify relevant user tasks, environment, and operating assumptions. |
| SN-04 | Is the system/product boundary clear enough to distinguish included and excluded behavior? |
| SN-05 | Are known external constraints recorded separately from unexamined assumptions? |
| SN-06 | Can observable success requirements be derived from this need? Identify what could demonstrate a useful outcome. |
| SN-07 | Are material unknowns explicit and routed rather than silently filled in? |
| SN-08 | Does the need remain solution-neutral unless a particular solution is itself a real external requirement? |

### Requirement quality — `requirement-quality/v1`

**Sources:** ISO/IEC/IEEE 29148:2018 [S12](source-register.md#source-s12); NASA SWE-050 [S13](source-register.md#source-s13).

**Evaluated by:** Reviewer for individual Requirements and requirement sets.

**Output:** requirements that can govern design and objective evaluation.

| ID | Evaluation question and required evidence |
|---|---|
| RQ-01 | Does the Requirement have a unique stable identity? |
| RQ-02 | Is it necessary? Trace to a stakeholder need, parent requirement, external obligation, or justified derived need. |
| RQ-03 | Does it correctly express the intended obligation? Compare with its source rather than only grammatical form. |
| RQ-04 | Is the statement clear and unambiguous in the shared vocabulary? Resolve material undefined terms. |
| RQ-05 | Is it sufficiently singular to evaluate independently? Split unrelated obligations or provide explicit sub-identities. |
| RQ-06 | Is it consistent with other governing requirements and constraints? Record unresolved conflicts. |
| RQ-07 | Is it feasible under known technical/resource constraints? Supply a credible basis; lack of proof of impossibility alone is weak evidence. |
| RQ-08 | Does it avoid unnecessary implementation prescription? Identify the authority for any mandated mechanism. |
| RQ-09 | Are necessary quantities, tolerances, ranges, limits, or timing conditions defined? |
| RQ-10 | Can an objective method establish satisfaction? Point to the verification relationship or planned method. |
| RQ-11 | Is upstream derivation traceable? Identify the exact source or parent. |
| RQ-12 | Is downstream traceability available to the extent required at this phase? Do not demand final code before design, or excuse missing code traces at acceptance. |
| RQ-13 | Are relevant nominal, adverse, boundary, and prohibited operating conditions addressed? |
| RQ-14 | Is the requirement's review/authority state known? Evaluate whether the record is explicit, not whether a model can grant itself approval. |
| RQ-15 | Does the set cover the applicable stakeholder needs and concern families, with justified exclusions? |
| RQ-16 | Is the requirement set internally consistent, rather than only each sentence in isolation? |
| RQ-17 | Does parent/child decomposition preserve required meaning without losing or adding hidden scope? |
| RQ-18 | Are duplicates and material overlaps reconciled so ownership and evaluation are not ambiguous? |

### Quality requirement quality — `quality-requirement-quality/v1`

**Sources:** ISO/IEC 25010:2023 [S14](source-register.md#source-s14), 25019:2023 and 25030:2019 [S15](source-register.md#source-s15), 25023:2016 [S16](source-register.md#source-s16).

**Evaluated by:** Reviewer during requirements/design and acceptance-plan review.

**Output:** measurable quality expectations instead of unsupported adjectives such as “fast” or “robust.”

| ID | Evaluation question and required evidence |
|---|---|
| QR-01 | Is the relevant product-quality or quality-in-use dimension identified? State any justified mapping across source editions. |
| QR-02 | Is the operating context for the expectation explicit? A latency target without load/context is incomplete. |
| QR-03 | Is the measure and its measurement method defined where objective measurement is possible? |
| QR-04 | Is the target, range, tolerance, or ordinal decision rule fixed before affected work? |
| QR-05 | Is the evaluation method capable of observing the relevant measure under the required conditions? |
| QR-06 | Is the relationship to acceptance explicit: required, advisory, or otherwise governed? |
| QR-07 | Are material quality trade-offs identified and resolved by the proper design authority? |
| QR-08 | Can the expectation be traced into design and later verification/validation/evaluation evidence? |

The 2016 measure standard and 2023 quality model are different editions of a family. Mapping is not assumed to be a perfect one-to-one subcharacteristic match. A reviewed profile documents the chosen relationship; it does not use a familiar label as proof of compatibility.

### Plan quality — `plan-quality/v1`

**Sources:** ISO/IEC/IEEE 16326:2019 and NASA SWE-013 [S18](source-register.md#source-s18); lifecycle framing from ISO/IEC/IEEE 12207:2026 [S11](source-register.md#source-s11).

**Evaluated by:** Reviewer at Delivery Readiness and material replanning.

**Output:** a complete, correct, workable, consistent, and verifiable plan.

| ID | Evaluation question and required evidence |
|---|---|
| PL-01 | Is all required work in the plan's scope represented or explicitly covered by another governed artifact? |
| PL-02 | Do planned activities correctly represent the governing objectives and intended lifecycle? |
| PL-03 | Are sequence, dependencies, roles, capacity, environments, and constraints workable together? |
| PL-04 | Is the plan consistent internally and with other governing plans? |
| PL-05 | Can progress and completion be objectively established? |
| PL-06 | Are objectives, boundaries, scope, and major deliverables/outcomes explicit? |
| PL-07 | Are responsibilities assigned for required activities? |
| PL-08 | Are interfaces, dependencies, sequencing constraints, and integration points identified? |
| PL-09 | Are feasibility-affecting risks and assumptions linked to treatment or monitoring? |
| PL-10 | Are required review, verification, validation, security, and acceptance activities planned? |
| PL-11 | Are applicable change and configuration management obligations represented? |
| PL-12 | Are documentation, rollout, operation/support, maintenance, or retirement obligations covered when needed? |
| PL-13 | Are the standards and procedures claimed by the plan identified explicitly? |

This profile evaluates plan quality. PriFly's slice/enabler rule, gate authority, batching thresholds, and dependency-release state remain workflow/product policy rather than external criteria.

### Architecture description quality — `architecture-description-quality/v1`

**Sources:** ISO/IEC/IEEE 42010:2022 and NASA SWE-057 [S19](source-register.md#source-s19); quality concerns from ISO/IEC 25010:2023 [S14](source-register.md#source-s14).

**Evaluated by:** Reviewer; Architect prepares the description.

**Output:** architecture information sufficient to communicate and govern the chosen design.

| ID | Evaluation question and required evidence |
|---|---|
| AD-01 | Are the entity of interest, boundaries, and relevant environment identified? |
| AD-02 | Are the architecture-relevant stakeholders known? |
| AD-03 | Are their concerns addressed by suitable views, models, or decisions? |
| AD-04 | Are architecture-driving functional and quality requirements traced into the design? |
| AD-05 | Are principal elements, responsibilities, and relevant properties described to the needed depth? |
| AD-06 | Are material dependencies and interactions between elements shown? |
| AD-07 | Are important internal/external interfaces and their ownership/contracts explicit? |
| AD-08 | Does each viewpoint/model answer its declared concern rather than provide decorative boxes? |
| AD-09 | Are the views mutually consistent in naming, authority, state, and interactions? |
| AD-10 | Are architecture-shaping constraints and assumptions explicit? |
| AD-11 | Are meaningful alternatives and the rationale for consequential choices recorded? |
| AD-12 | Are material risks and quality trade-offs visible? |
| AD-13 | Is enough dependency/evolution information present to support later impact analysis? |
| AD-14 | Are architecture obligations precise enough that implementation conformance can be assessed? |

### Architecture evaluation quality — `architecture-evaluation-quality/v1`

**Source:** ISO/IEC/IEEE 42030:2019 [S20](source-register.md#source-s20).

**Evaluated by:** Reviewer performing architecture challenge, with later review-quality sampling where warranted.

**Output:** an evidence-backed evaluation, not the Architect's confidence in its own description.

| ID | Evaluation question and required evidence |
|---|---|
| AE-01 | Is the exact evaluated architecture/revision and scope identified? |
| AE-02 | Are the stakeholder concerns and purpose of the evaluation explicit? |
| AE-03 | Are scenarios, criteria, measures, and analysis/review methods declared and appropriate? |
| AE-04 | Do conclusions cite supporting evidence? |
| AE-05 | Does every required concern in the evaluation scope have a result? |
| AE-06 | Does the evaluation assess fitness for intended purpose and relevant quality objectives? |
| AE-07 | Are risks, weaknesses, uncertainties, and opportunities surfaced rather than only strengths? |
| AE-08 | Are findings sufficiently specific for disposition and action? |
| AE-09 | Are unavailable evidence and unsupported assumptions represented explicitly? |
| AE-10 | Does the final conclusion follow from individual results and residual concerns? |

### Risk record quality — `risk-record-quality/v1`

**Source:** ISO/IEC/IEEE 16085:2021 [S21](source-register.md#source-s21).

**Evaluated by:** Reviewer for risk records used in design, planning, change, or acceptance.

**Output:** useful risk information with treatment and ownership.

| ID | Evaluation question and required evidence |
|---|---|
| RK-01 | Is the affected product/process/decision scope clear? |
| RK-02 | Does the record distinguish cause, uncertain event/condition, and consequence? |
| RK-03 | Is likelihood or uncertainty assessed with the declared method/scale? |
| RK-04 | Is relevant technical, security, cost, schedule, operational, or other impact assessed? |
| RK-05 | Is priority/exposure traceable to that method rather than an unexplained label? |
| RK-06 | Is required treatment explicit? |
| RK-07 | Is an accountable owner identified? |
| RK-08 | Are relevant triggers, indicators, or review conditions defined? |
| RK-09 | Is residual risk after treatment stated? |
| RK-10 | Are related requirements, decisions, work, evidence, and authority references traceable? |

### Evidence provenance quality — `evidence-provenance-quality/v1`

**Source model:** W3C PROV-DM [S24](source-register.md#source-s24).

**Evaluated by:** the role consuming evidence, and Reviewer where consequential promotion requires it.

**Output:** evidence whose origin and use can be revisited. Provenance is not itself proof that a claim is true.

| ID | Evaluation question and required evidence |
|---|---|
| EV-01 | Is the source/evidence entity identifiable? |
| EV-02 | Is the activity that generated or retrieved it known when material? |
| EV-03 | Is the responsible collector/producer/agent/tool identified? |
| EV-04 | Can derived evidence or claims be traced back to their sources? |
| EV-05 | Is an official/stable source locator retained when available? |
| EV-06 | Are acquisition, observation, or valid-as-of times recorded where freshness matters? |
| EV-07 | Are material filtering, transformations, calculations, or summaries represented? |
| EV-08 | Is a content hash/version/object identity retained when exact bytes matter? |
| EV-09 | Are conflicts, coverage gaps, uncertainty, and limitations visible? |
| EV-10 | Can another evaluator determine what evidence was used and why it supports the interpretation? |

These are local evaluation questions using the provenance model. PROV is not being represented as a universal factual-truth or research-method scoring standard.

### Verification plan quality — `verification-plan-quality/v1`

**Sources:** IEEE 1012-2024 and ISO/IEC/IEEE 29119-2:2021 [S22](source-register.md#source-s22); NASA SWE-028 [S27](source-register.md#source-s27).

**Evaluated by:** Reviewer during planning and whenever the verification contract materially changes.

**Output:** a method that can establish specified properties with objective evidence.

| ID | Evaluation question and required evidence |
|---|---|
| VP-01 | Is the exact requirement/outcome/property to be verified identified? |
| VP-02 | Is the objective a property to establish, not only a tool or command name? |
| VP-03 | Is analysis, inspection, demonstration, testing, or another method suitable for that property and risk? |
| VP-04 | Are material environment/configuration conditions specified? |
| VP-05 | Are necessary inputs, states, fixtures, setup, and preconditions defined? |
| VP-06 | Is the expected observable behavior/measurement explicit? |
| VP-07 | Is the pass/fail, range, tolerance, or other satisfaction rule predeclared? |
| VP-08 | Does scenario/boundary/failure/coverage selection follow requirements and risk rather than convenience? |
| VP-09 | Are required independence conditions explicit? Do not assume that independence always requires rerunning the whole suite. |
| VP-10 | Is the evidence needed for later acceptance identified? |
| VP-11 | Are tool/runner/version identities fixed where they materially affect the result? |
| VP-12 | Is unavailable/skipped verification handled explicitly rather than treated as pass? |
| VP-13 | Can verification trace backward to the obligation and forward to evidence/results? |

### Validation plan quality — `validation-plan-quality/v1`

**Sources:** IEEE 1012-2024 [S22](source-register.md#source-s22); NASA SWE-029 [S27](source-register.md#source-s27); ISO/IEC 25019:2023 [S15](source-register.md#source-s15).

**Evaluated by:** Reviewer for planned product validation; Validator uses it to execute and report.

**Output:** representative intended-use proof, not a synonym for a unit-test run.

| ID | Evaluation question and required evidence |
|---|---|
| VA-01 | Is the stakeholder need or intended-use claim explicit? |
| VA-02 | Is the relevant operating/user/task context represented? |
| VA-03 | Are scenarios and data representative, including material adverse/boundary conditions? |
| VA-04 | Is the chosen operational exercise, demonstration, test, or analysis appropriate? |
| VA-05 | Are satisfaction criteria and quality-in-use targets fixed before the run? |
| VA-06 | Is the product/configuration sufficiently representative of what is being accepted? |
| VA-07 | Are required observations and provenance defined? |
| VA-08 | Are validation independence requirements explicit and achievable? |
| VA-09 | Do failed or partial intended-use claims become explicit findings/limitations? |
| VA-10 | Does evidence trace to intended use and the relevant acceptance scope? |

### Product quality evaluation — `product-quality-evaluation/v1`

**Sources:** ISO/IEC 25010:2023 [S14](source-register.md#source-s14), 25030:2019 [S15](source-register.md#source-s15), 25023:2016 [S16](source-register.md#source-s16), and 25040:2024 [S17](source-register.md#source-s17).

**Evaluated by:** Reviewer for product/candidate acceptance where applicable; Validator supplies intended-use observations.

**Output:** an explicit evaluation of selected quality requirements.

| ID | Evaluation question and required evidence |
|---|---|
| PQ-01 | Are relevant quality dimensions selected or explicitly dispositioned? |
| PQ-02 | Does evaluation use predeclared quality requirements and targets? |
| PQ-03 | Is the exact product/build/configuration/context identified? |
| PQ-04 | Are measures and methods appropriate to each expectation? |
| PQ-05 | Are observations retained with useful provenance? |
| PQ-06 | Is every required quality expectation covered or explicitly unresolved? |
| PQ-07 | Is each observation compared to its declared target/rule? |
| PQ-08 | Are measurement uncertainty, skips, and environmental limitations explicit? |
| PQ-09 | Are deficiencies visible individually rather than averaged away? |
| PQ-10 | Does the conclusion follow the individual results and declared acceptance policy? |

### Security engineering quality — `security-engineering-quality/v1`

**Core source:** NIST SP 800-218, SSDF 1.1 [S23](source-register.md#source-s23).

**Conditional verification sources:** OWASP ASVS [S29](source-register.md#source-s29) and selected supply-chain requirements [S30](source-register.md#source-s30), when activated.

**Evaluated by:** appropriate planning/design/code/release Reviewer; scope and evidence differ by lifecycle phase.

| ID | Evaluation question and required evidence |
|---|---|
| SE-01 | Are applicable security roles, policies, tools, process expectations, and risk inputs identified? |
| SE-02 | Do security needs/threats trace into requirements, constraints, design, verification, or explicit residual risk? |
| SE-03 | Are development assets, credentials, source, artifacts, and environments protected according to the selected profile? |
| SE-04 | Are the selected secure design, implementation, review, and testing practices evidenced? |
| SE-05 | Are applicable third-party provenance, vulnerability, update, and component obligations addressed? |
| SE-06 | Is there a working path for vulnerability triage, remediation, response, and recurrence analysis? |
| SE-07 | Is claimed practice supported by the required evidence rather than confidence alone? |
| SE-08 | Are unfulfilled controls and residual risks explicit with the required authority? |

A hobby project can tailor scope transparently. It cannot claim every SSDF practice is fulfilled merely by activating this profile. ASVS requirements are selected and recorded by their official versioned identifiers instead of replaced with vaguely similar homegrown security questions.

### Implementation quality — `implementation-quality/v1`

**Sources:** NASA SWE-061 [S27](source-register.md#source-s27); ISO/IEC 25010:2023 [S14](source-register.md#source-s14); SSDF [S23](source-register.md#source-s23); selected official language/framework standards.

**Evaluated by:** Reviewer on code/configuration/documentation work products as applicable.

**Output:** workmanship assessed against declared engineering criteria, not an invented universal style guide.

| ID | Evaluation question and required evidence |
|---|---|
| IM-01 | Was the applicable coding/tooling profile selected before evaluation? |
| IM-02 | Are violations of that coding profile resolved or explicitly dispositioned? |
| IM-03 | Are required build/static/tool checks complete with known results? |
| IM-04 | Can changed implementation be traced to the obligations it realizes? |
| IM-05 | Are relevant code-level quality obligations addressed, not treated as purely external test properties? |
| IM-06 | Are selected secure coding/dependency/secret/error-handling expectations satisfied? |
| IM-07 | Are generated, reused, or third-party code obligations treated explicitly? |
| IM-08 | Are known defects, bypasses, waived checks, and unsupported configurations visible rather than hidden? |

Checking whether the implementation follows this Project's specific chosen design remains the separate conformance assessment.

### Review/inspection quality — `review-inspection-quality/v1`

**Sources:** NASA SWE-087 [S27](source-register.md#source-s27); IEEE 1012-2024 [S22](source-register.md#source-s22).

**Evaluated within:** Reviewer's completion record and Factory's structural checks; Auditor/independent sampling when warranted.

**Output:** a competent, complete, attributable review. It does not require an infinite chain of reviewers.

| ID | Evaluation question and required evidence |
|---|---|
| RV-01 | Is the exact reviewed subject/revision/scope known? |
| RV-02 | Were required inputs, evidence, and rubrics available? |
| RV-03 | Are reviewer capabilities/perspectives appropriate to the artifact and risk? |
| RV-04 | Were the relevant artifact quality profiles actually evaluated? |
| RV-05 | Was project conformance assessed separately rather than confused with general quality? |
| RV-06 | Did the review address technical integrity and not merely formatting or presentation? |
| RV-07 | Do findings state a specific problem with evidence and relevance? |
| RV-08 | Are required actions/findings tracked instead of lost at review completion? |
| RV-09 | Are completion and pass/fail conditions explicit and consistently applied? |
| RV-10 | Are verdict, evidence, evaluator identity, profiles, findings, and limitations recorded? |
| RV-11 | Were the required independence conditions satisfied? |

### Acceptance quality — `acceptance-quality/v1`

**Sources:** NASA SWE-034 [S27](source-register.md#source-s27); SQuaRE [S14](source-register.md#source-s14), [S17](source-register.md#source-s17); IEEE 1012 [S22](source-register.md#source-s22).

**Evaluated by:** Reviewer for the named candidate, product, or release acceptance scope.

**Output:** an evidence-supported acceptance recommendation with explicit authority and limitations.

| ID | Evaluation question and required evidence |
|---|---|
| AC-01 | Did acceptance criteria exist before observing the final result? |
| AC-02 | Are required criteria objective/measurable enough to decide satisfaction? |
| AC-03 | Is the accepted subject/build/configuration/baseline exact? |
| AC-04 | Is all verification/validation required for this acceptance scope complete? Candidate-for-merge scope does not imply product-validation completion. |
| AC-05 | Are relevant product-quality expectations evaluated through their selected measures/profiles? |
| AC-06 | Are required documentation, configuration identity, user/operator information, and release deliverables ready? |
| AC-07 | Are defects/deviations and their treatment explicit, with no hidden blockers? |
| AC-08 | Does material residual risk have the required disposition and authority? |
| AC-09 | Does the conclusion trace to credible evidence with the required independence? |
| AC-10 | Are the acceptance result, criteria, exceptions, evidence, and authority recorded? |

### Change impact quality — `change-impact-quality/v1`

**Sources:** ISO/IEC/IEEE 12207 [S11](source-register.md#source-s11), NASA SWE-053 [S27](source-register.md#source-s27), ISO/IEC/IEEE 16085 [S21](source-register.md#source-s21).

**Evaluated by:** Reviewer for proposed semantic baseline changes.

**Output:** explicit impact analysis that informs authority and downstream revalidation.

| ID | Evaluation question and required evidence |
|---|---|
| CH-01 | Are the proposed semantic change, source/requester, and rationale explicit? |
| CH-02 | Are affected baseline/object/product versions identified? |
| CH-03 | Has upstream/downstream traceability been examined across requirements, design, implementation, tests, and information? |
| CH-04 | Are material technical/behavior/interface/data/quality/security/operational impacts evaluated? |
| CH-05 | Are material cost, effort, skills, and resource impacts assessed? |
| CH-06 | Are schedule, dependency, rollout, and transition effects assessed where relevant? |
| CH-07 | Are affected stakeholders identified? |
| CH-08 | Are changed/new risks and residual risks evaluated? |
| CH-09 | Are required verification, validation, and documentation updates identified? |
| CH-10 | Can an independent evaluator follow the impact evidence and conclusion? |
| CH-11 | Is impact uncertainty explicit rather than treated as proof of no impact? |

### Documentation quality — `documentation-quality/v1`

**Sources:** ISO/IEC/IEEE 15289:2019, 26514:2022, and 26515:2018 [S26](source-register.md#source-s26).

**Evaluated by:** Reviewer; Validator exercises supported operator material when appropriate.

**Output:** usable lifecycle/user information, whether a document or structured record.

| ID | Evaluation question and required evidence |
|---|---|
| DO-01 | Is the intended audience and purpose identifiable? |
| DO-02 | Is the required information present or linked to an authoritative source? |
| DO-03 | Is it correct and current for the product/revision it claims to describe? |
| DO-04 | Is it consistent with governing information? |
| DO-05 | Are consequential claims traceable to design/evidence/source where needed? |
| DO-06 | Can the intended reader find it and navigate to related detail? |
| DO-07 | Does it support the actual task/concept/reference need, not just internal implementation? |
| DO-08 | Is format, structure, and media suitable for the reader and task? |
| DO-09 | Are maintenance ownership and update triggers known? |
| DO-10 | Does it avoid creating an ungoverned competing source of truth? |

### Estimate quality — `estimate-quality/v1`

**Source:** GAO-20-195G [S25](source-register.md#source-s25), tailored to the bounded estimate being made.

**Evaluated by:** Reviewer when an estimate materially informs planning/capacity; Estimator produces it.

**Output:** a defensible prediction of execution time and supportable token use for already-defined work, with uncertainty. Scope and file-footprint inputs come from planning/discovery; Estimator does not decompose or schedule the work.

| ID | Evaluation question and required evidence |
|---|---|
| ES-01 | Are estimate purpose, decision use, scope, and horizon explicit? |
| ES-02 | Is it tied to a defined technical/planning baseline? |
| ES-03 | Is included/excluded work structured sufficiently to understand the basis? |
| ES-04 | Are material assumptions and constraints recorded? |
| ES-05 | Are source data and provenance available? |
| ES-06 | Is the method explained and suitable for the data/maturity? |
| ES-07 | Is uncertainty represented rather than concealed by false precision? |
| ES-08 | Are major drivers, sensitivities, and risks considered where material? |
| ES-09 | Can another evaluator understand how the estimate was produced? |
| ES-10 | Can estimates be compared with actuals without erasing the original prediction? |

### Closure quality — `closure-quality/v1`

**Sources:** ISO/IEC/IEEE 12207 [S11](source-register.md#source-s11), IEEE 1012 [S22](source-register.md#source-s22), ISO/IEC 25040 [S17](source-register.md#source-s17), and ISO/IEC/IEEE 15289 [S26](source-register.md#source-s26).

**Evaluated by:** Reviewer for the closing scope, with Factory's separate workflow checks.

**Output:** a supported statement of completion and transition readiness.

| ID | Evaluation question and required evidence |
|---|---|
| CL-01 | Are all requirements/outcomes in the closing scope accounted for? |
| CL-02 | Is required delivery work complete for the scope being closed? |
| CL-03 | Are required verification, validation, and acceptance obligations complete? |
| CL-04 | Is the delivered configuration/as-built baseline known? |
| CL-05 | Are findings, defects, and deviations explicitly resolved or legitimately dispositioned? |
| CL-06 | Are residual risks owned and treated/accepted with the required authority? |
| CL-07 | Is required lifecycle/user/operator information complete and current? |
| CL-08 | Are required operational, support, maintenance, and transition obligations addressed? |
| CL-09 | Does required acceptance/configuration/evaluation evidence remain available? |
| CL-10 | Is the closure decision recorded rather than inferred from ticket counts? |

### Conditional profiles and direct source identifiers

WCAG 2.2 [S28](source-register.md#source-s28), OWASP ASVS 5.0.0 [S29](source-register.md#source-s29), and SLSA 1.2 [S30](source-register.md#source-s30) are not universal obligations for every artifact. Planning selects the relevant version, applicability, level/track, and official requirement identifiers. Evaluation records those official identifiers rather than disguising them as new PriFly criteria.

A web UI may need WCAG success criteria at a declared conformance level; the product definition does not silently choose a universal level. A web API may need selected ASVS controls; it does not follow that every ASVS requirement applies. A distributed build may need a declared SLSA assurance target; merely recording its source commit does not imply a particular SLSA level.

DORA [S31](source-register.md#source-s31) remains diagnostic. INVEST and walking-skeleton heuristics are not mislabeled as formal standards. The latter can still inform PriFly's explicit product delivery policy.

### Worked rubric application

Consider an illustrative Work Item whose Outcome is: “The status command reports the last completed backup time for the selected archive.” This is not a PriFly feature requirement; it illustrates the evaluation mechanics.

Architect has already defined what “completed,” “selected archive,” and time representation mean. Planner gives the Outcome a verification method and ties it to those definitions. Implementer adds the command and tests, records the candidate, test data, expected output, and observed output. Reviewer checks requirement clarity and verifiability, coding-profile adherence, evidence provenance, and the command's conformance to the accepted design.

If the displayed timestamp is correct but there is no declared behavior when no backup exists, the Reviewer identifies the relevant requirement/design gap. It cannot invent a preferred behavior and demand it as a current correction without a governing basis. It may propose a planning change. If the accepted requirement already says “show no completed backup,” and the candidate crashes, a fresh Implementer receives a current-correction job in the existing workspace.

If the existing evidence covers the declared states and the Reviewer finds it credible, it can accept it. If a boundary case is doubtful, it runs that case and continues the same review. A missing target definition yields criterion-unknown; a demonstrated incorrect result yields fail. Factory aggregates those records with conformance and workflow policy before any candidate acceptance.
