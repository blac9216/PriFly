# Agent guidance

## Read design before changing the system

1. Read `docs/doc-manifest.md` to learn the adopted documentation shape.
   The accepted product baseline is `docs/reference/product-requirements.md`; focused docs decompose it.
2. Read `CONTEXT.md` for canonical vocabulary.
3. Read the generated table in `docs/adr/README.md` first; open only the active ADRs relevant to the change.
4. Read the relevant explanation/reference docs from `docs/README.md`.
5. Before producing or reviewing a consequential engineering artifact, identify the applicable profile(s) in `docs/reference/quality-rubrics.md` and their pinned authoritative sources in `docs/reference/standards-registry.md`.

## Quality, conformance, and workflow are different

Do not collapse these three questions:

- **Industry quality:** is the artifact good engineering according to the applicable standards-backed rubric?
- **Project conformance:** does it obey the governing Requirements, Design, Constraints, Planning Baseline, Work Item, and project-specific thresholds?
- **PriFly workflow:** is it allowed to advance given authority, lifecycle state, review independence, Findings, evidence, and other Factory policy?

Use the exact rubric version selected by policy/planning. Do not invent or weaken criteria because evidence is inconvenient. When an official-source ambiguity cannot be resolved, return `UNKNOWN` rather than making up a rule. When an external standard leaves an acceptance threshold to project context, use the threshold already fixed in the governing Planning Baseline; do not choose one after seeing implementation results.

Project-specific PriFly architecture rules are conformance requirements, not fake “industry standards.”

## Durable design flow

Durable design decisions are made with owner interrogation, decomposed through planning, recorded through the `design-docs` framework, and then implemented/reviewed through the repository workflow.

- Do not commit design specs, plans, interrogation transcripts, research reports, or audit gap reports.
  The owner-authorized exception is the single accepted PRD at `docs/reference/product-requirements.md`.
  Keep it and affected decomposition consistent; do not create additional PRD copies or silently override it.
- Do not create `docs/design/`, `docs/superpowers/`, or other spec directories.
- Architecture-changing decisions that pass the ADR trigger test require an ADR plus updates to every affected canonical design document in the same change.
- Once an ADR is Accepted, its Context, Decision Drivers, Considered Options and Decision are immutable; supersede or amend it with a new ADR instead.
- Code comments should not carry issue/ADR archaeology. When a local implementation needs durable reasoning, use a `# why:` pointer into a declared rationale area.
