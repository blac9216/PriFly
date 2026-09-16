# ADR-0021: Use standards-backed quality rubrics for engineering work

Status: Accepted
Amended-by: 0023
Date: 2026-09-14

## Context

PriFly already has explicit lifecycle gates, independent review, project-specific conformance checks, and exact acceptance/evidence rules. What was missing was an objective, reusable answer to a different question: **how does a Worker or Reviewer know whether an engineering work product is high quality in the first place?**

Without a pinned quality rubric, an AI producer or reviewer can silently invent criteria from its own training, vary the bar between runs, or confuse project-specific design adherence with general engineering quality. The software industry already defines detailed requirements, planning, architecture, V&V, product-quality, security, review, documentation, risk, and change-management practices. PriFly should normalize and version those sources instead of recreating them ad hoc.

The quality layer must remain distinct from two existing PriFly concerns:

1. **Project conformance** asks whether work obeys the governing Requirements, Design, Constraints, Planning Baseline, Work Item, and other project-specific authority.
2. **PriFly workflow policy** asks whether the artifact may advance, including independence, authority, traceability, blocking Findings, and lifecycle state.

Neither of those is an industry-quality rubric.

## Decision Drivers

- Workers need a stable answer to “what does done look like?” before they start work.
- Reviewers need an objective quality bar fixed before seeing the artifact they judge.
- Industry standards and authoritative engineering guidance already define strong criteria for most software work products.
- Agents must be able to resolve ambiguity against official sources rather than inventing interpretations.
- Standards evolve, so quality judgments must bind exact source and rubric versions.
- Project-specific thresholds must be fixed during planning when an external standard deliberately leaves the acceptable value to the project.
- Paid/copyrighted standards must be referenced and normalized without copying protected text into the repository.
- General engineering quality, project conformance, and PriFly workflow permission must remain independently inspectable.

## Considered Options

### Versioned standards-backed reusable rubrics

Maintain a registry of pinned authoritative sources and reusable artifact/work-product quality rubrics derived from them. Gates compose those rubrics but do not redefine them. Review records which rubric version and criteria were evaluated.

### Let each Worker or Reviewer infer quality criteria

Flexible but non-reproducible. Different models can invent different definitions of completeness, good architecture, adequate verification, or acceptable evidence.

### Encode one giant PriFly-specific checklist

Centralizes evaluation but mixes general engineering quality with project conformance and PriFly workflow mechanics. It would also duplicate standards and become difficult to maintain.

### Use only project requirements/design as the quality bar

Necessary for conformance, but insufficient. A project design can itself contain ambiguous requirements, incomplete architecture, poor verification, weak risk treatment, or low-quality documentation.

### Adopt heuristic frameworks as if they were standards

Practices such as INVEST or a walking-skeleton strategy can still inform delivery policy, but they are not promoted into authoritative industry-quality rubrics merely because they are popular.

## Decision

PriFly uses **versioned, standards-backed reusable quality rubrics** for consequential engineering work products.

The model has three deliberately separate layers:

```text
INDUSTRY QUALITY
Is this work product objectively good engineering according to the pinned rubric?

PROJECT CONFORMANCE
Does it obey the governing Requirements, Design, Constraints, baseline, and project rules?

PRIFLY WORKFLOW POLICY
May it advance to the next lifecycle state?
```

The following rules apply:

1. `docs/reference/standards-registry.md` owns the pinned external source registry, including edition/version, source status, official locator, applicability, and last verification date.
2. `docs/reference/quality-rubrics.md` owns the normalized reusable quality criteria and the mapping of rubric profiles to PriFly lifecycle stages/artifact kinds.
3. Rubric criteria are paraphrased PriFly normalization of authoritative sources; the repository does not reproduce copyrighted standards text.
4. A consequential artifact is evaluated against an exact rubric profile/version selected **before** the evaluation. A producer/reviewer cannot silently add, remove, weaken, or strengthen criteria after inspecting the artifact.
5. Each applicable blocking criterion resolves to `PASS`, `FAIL`, `NOT_APPLICABLE`, or `UNKNOWN`. `FAIL` blocks. Unresolved `UNKNOWN` blocks. `NOT_APPLICABLE` requires the applicability path declared by policy; absence of evidence is not N/A.
6. Where an external source defines a quality dimension or measure but intentionally leaves the acceptable threshold to the project, the governing Planning Baseline must establish the measure and acceptable target/range before affected implementation is released. A Worker or Reviewer may not invent that threshold later.
7. When a rubric is ambiguous, the evaluator follows the pinned official source/version and locator. If the source cannot be accessed or the ambiguity cannot be resolved, the criterion remains `UNKNOWN`; unofficial summaries cannot silently redefine the criterion.
8. Project-specific design/requirement adherence is evaluated separately as **conformance**. PriFly-specific rules such as Published Frontier ordering, SEND_ARMED, exact-ref integration, or owner-control authority remain project/system conformance concerns and are not mislabeled as external quality standards.
9. PriFly lifecycle gates compose reusable quality rubrics plus project conformance plus workflow conditions. A gate is not itself a substitute for the underlying quality rubric.
10. Diagnostic frameworks such as DORA metrics may inform improvement and lessons, but are not converted into arbitrary universal pass/fail thresholds.
11. Conditional standards such as OWASP ASVS, WCAG, or SLSA activate only when project/product context and policy make them applicable. Their exact version and target level/profile must be pinned before they become blocking.
12. Executable rubric schemas/checkers may be introduced with the first real evaluator/consumer. They must conform to these semantic references and ADR-0018 rather than redefining the criteria during implementation.

## Consequences

PriFly gains an explicit, source-backed definition of engineering quality before implementation begins. Workers receive clearer stopping conditions, Reviewers use stable criteria, and disagreement can be traced to an official source rather than model intuition.

Gates become easier to reason about because quality, project conformance, and workflow permission are separately visible. A high-quality artifact can still fail conformance; a conforming artifact can still fail general engineering quality; neither advances when blocking workflow conditions remain unresolved.

The standards registry requires deliberate maintenance as authoritative sources change. Upgrading a pinned standard or materially changing a normalized rubric is a governed design/policy change rather than an invisible prompt update.
