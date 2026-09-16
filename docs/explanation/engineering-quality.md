# Engineering quality and evaluation

Kind: explanation

## Engineering quality: standards and mechanical application

### Three independent questions

Every consequential evaluation distinguishes:

| Layer | Question | Source of the answer |
|---|---|---|
| General engineering quality | Is this requirement, plan, design, test approach, or work product well engineered? | Pinned external standards and authoritative engineering guidance, normalized into reusable rubrics. |
| Project conformance | Does this exact artifact satisfy this Project's requirements, design, constraints, and approved choices? | The Project's governing baseline and work contract. |
| Workflow eligibility | Is this result authorized, current, complete, and permitted to advance now? | PriFly lifecycle policy and recorded state. |

The system's own database or PR behavior is not relabeled as an industry rubric. It is part of project conformance when PriFly itself is being built and workflow policy when PriFly manages another project.

### The adopted source families

The detailed inventory in [Appendix A](../reference/quality-rubrics.md#detailed-general-engineering-rubric-inventory) preserves nineteen reusable profiles from the PriFly source material [P3](../reference/source-register.md#source-p3). Their external basis is summarized below. Each source has an official locator in [Appendix C](../reference/source-register.md#sources-provenance-and-standards-access).

| Engineering concern | Adopted source family | Use in PriFly |
|---|---|---|
| Lifecycle coverage | ISO/IEC/IEEE 12207:2026 | Identify lifecycle concerns, including operations, maintenance, and retirement; not prescribe a particular methodology. |
| Requirements | ISO/IEC/IEEE 29148:2018; NASA SWE-050 | Evaluate requirement and requirement-set quality. |
| Product qualities and acceptance measures | ISO/IEC 25010:2023, 25019:2023, 25030:2019, 25023:2016, 25040:2024 | Select quality dimensions, contextual requirements, measures, targets, and evaluation evidence. |
| Plan quality | ISO/IEC/IEEE 16326:2019; NASA SWE-013 | Assess whether a plan is complete, correct, workable, consistent, and verifiable. |
| Architecture description | ISO/IEC/IEEE 42010:2022; NASA SWE-057 | Check stakeholders, concerns, views, structure, interfaces, dependencies, rationale, and consistency. |
| Architecture evaluation | ISO/IEC/IEEE 42030:2019 | Check whether evaluation addresses intended purpose, concerns, evidence, and risks. |
| Risk | ISO/IEC/IEEE 16085:2021 | Assess risk information, ownership, treatment, monitoring, and residuals. |
| Verification and validation | IEEE 1012-2024; ISO/IEC/IEEE 29119-2:2021; NASA SWE-028/029 | Define adequate methods, contexts, criteria, coverage, evidence, and appropriate independence. |
| Review and acceptance | NASA SWE-087 and SWE-034; the V&V and SQuaRE families | Inspect review quality and the adequacy of predeclared acceptance evidence. |
| Secure development | NIST SP 800-218 SSDF 1.1 | Apply secure-development practices across applicable lifecycle activities. |
| Provenance | W3C PROV-DM | Identify evidence entities, activities, responsible agents, and derivation. |
| Change analysis | NASA SWE-053; lifecycle and risk standards | Assess effects on requirements, design, implementation, tests, documentation, costs, and dependencies. |
| Coding practices | NASA SWE-061 plus selected official language/tool guidance | Require a declared coding profile rather than invent a universal PriFly style guide. |
| Estimation | GAO-20-195G | Make estimation scope, basis, method, uncertainty, and calibration inspectable. |
| Information quality | ISO/IEC/IEEE 15289:2019, 26514:2022, 26515:2018 | Evaluate lifecycle and user/operator information without forcing giant documents. |

Conditional overlays are WCAG 2.2 for applicable web information/UI, ASVS 5.0.0 for applicable web application/API security, and SLSA 1.2 for selected source/build assurance. The Project declares the precise level, track, requirements, and applicability before these become blocking. DORA delivery metrics are diagnostic evidence, not universal quality gates [S28](../reference/source-register.md#source-s28)–[S31](../reference/source-register.md#source-s31).

### Source access and limits

A source's public catalog establishes its identity and scope; it does not establish that every clause has been inspected. This design does not claim certification against the complete text of every ISO/IEEE standard. It does not reproduce paid standards or fabricate clause numbers.

The criterion inventory is a normalized engineering profile. Public official guidance, particularly NASA's handbook, supplies detailed operational support. Where a criterion requires a detail not established by the available public material, the source registry must identify the limitation and the implementation must qualify the mapping with legitimately available source text. An inaccessible source does not require every already-clear criterion to stop; it blocks a judgment when the unresolved interpretation is necessary to decide that criterion.

The nineteen profiles are **general engineering rubrics**, not nineteen new agent roles or mandatory separate model calls. The same Reviewer evaluates the profiles relevant to its subject in one bounded review.

### Records needed for evaluation

**Standards Source** records identity, publisher, edition/version, official locator, publication status, access mode, and last identity check. **Rubric Profile** is an immutable versioned collection of criteria for one artifact type. **Rubric Criterion** is an individually addressable quality question. **Rubric Evaluation** is the evidence-backed result for an exact artifact and profile version.

A criterion definition must contain its local criterion ID, source and source locator, normalized question, applicability conditions, lifecycle phase, required evidence kinds, evaluation method, and allowed result values. A separate policy binding specifies where the profile is required and who may resolve applicability. This separates the external quality question from PriFly's promotion rules.

An evaluation records artifact identity/revision, selected profile version, source versions, evaluator identity, evidence references, result for every required criterion, rationale for failure/uncertainty/N/A, and completion time. It cannot merely record “requirements quality passed” without the criterion-level record.

### Evaluation algorithm

1. **Select before execution.** Factory resolves the artifact type, Project context, lifecycle phase, and activated overlays into a pinned profile set. The producer sees the same quality expectations the Reviewer will use.
2. **Resolve applicability.** Policy and reviewed evidence determine applicable criteria. Unsupported detector coverage or unresolved interpretation remains explicitly unknown. “Not checked” is not N/A.
3. **Collect existing evidence.** The subject's current evidence is attached with exact code/artifact and environment identity. Reuse is preferred where it actually supports the question.
4. **Perform structural checks.** Software can check identities, missing fields, reference validity, declared thresholds, required result coverage, and consistency of version bindings.
5. **Perform semantic assessment.** The assigned qualified Worker judges criteria that require engineering meaning, such as whether a requirement is ambiguous or whether a test meaningfully covers a failure mode. It supplies reasons and evidence rather than an unsupported score.
6. **Resolve material ambiguity.** The evaluating Worker submits a typed source-investigation or dispute request; Factory maps it to Researcher or Arbiter and admits it only within the authorized scope. The evaluating Reviewer can inspect additional evidence during its existing review.
7. **Record the evaluation.** Results are published with exact subject and profile identities.
8. **Evaluate the gate.** Factory computes eligibility from required quality results, separate conformance results, and workflow conditions. The aggregate is deterministic; the underlying semantic judgments are not falsely described as mathematically objective.

### Figure 12 — Quality evaluation without recursive reviewers

```mermaid
sequenceDiagram
    participant Factory
    participant Producer
    participant Reviewer
    participant Tools as Evidence tools
    participant Registry as Pinned source registry
    Factory->>Producer: Work contract and selected quality profiles
    Producer-->>Factory: Exact artifact plus evidence
    Factory->>Factory: Structural, authority, reference checks
    Factory->>Reviewer: Same profiles, governing baseline, exact artifact, evidence
    Reviewer->>Reviewer: Assess quality and project conformance separately
    opt More evidence or source clarification needed
        Reviewer->>Tools: Run relevant check or inspect source evidence
        Tools-->>Reviewer: Observations
        Reviewer->>Registry: Resolve pinned authoritative locator
        Registry-->>Reviewer: Source identity and access/interpretation limits
        Reviewer->>Reviewer: Continue the same review
    end
    Reviewer-->>Factory: Criterion results, evidence decisions, verdict, Findings
    Factory->>Factory: Apply deterministic gate rules
```

No universal numeric “quality score” replaces required criteria. An aggregate percentage may show progress but cannot offset one blocking failure. Review quality itself is governed by readiness and completion criteria; that does not require an infinite chain of reviewers reviewing reviewers. Auditor performs bounded calibration or retrospective sampling separately.

### Phase-aware use

A design-stage requirement need not already have implementation commits. Its downstream trace criterion is satisfied for that phase by planned design/verification relationships, with later obligations recorded. Release-stage evidence must then show the actual implementation and results. A profile binding must state the maturity being evaluated.

Similarly, candidate acceptance is acceptance **for merge**. It does not falsely claim that a post-merge Validation Target has already passed. Product/release acceptance later evaluates the validation evidence required for that broader scope.

### Thresholds and exceptions

ISO/IEC 25023 supplies measures without universal acceptable ranges; acceptable values depend on the product and its context [S16](../reference/source-register.md#source-s16). PriFly therefore requires a baselined target, range, or other objective rule before affected work is released. “Fast,” “secure,” or “adequately tested” without a defined applicable interpretation is not a usable acceptance threshold.

When a quality result is `FAIL`, it stays failed. An authorized risk acceptance may permit a separately visible exception only where policy allows; it does not rewrite the evaluation to `PASS`. Removing a required criterion or changing its threshold requires the normal policy/baseline change and impact path. The record must preserve why the original evaluation failed.

### Required quality controls

| ID | Requirement |
|---|---|
| PF-QUAL-01 | Exact profile and criterion identities accompany consequential quality results. |
| PF-QUAL-02 | Producers and reviewers receive the same predeclared expectations. |
| PF-QUAL-03 | Source ambiguity is resolved against pinned official sources; unsupported interpretation remains Criterion UNKNOWN. |
| PF-QUAL-04 | Quality, conformance, and workflow results remain separately inspectable. |
| PF-QUAL-05 | Required criteria cannot be silently weakened by the producer, Reviewer, or model routing policy. |
| PF-QUAL-06 | Profile updates are versioned, reviewed, and impact-assessed; historical evaluations retain their original meaning. |
| PF-QUAL-07 | Every activated overlay has explicit applicability and level/requirement selection. |
| PF-QUAL-08 | Review-quality assurance does not create an automatic recursive review pipeline. |
