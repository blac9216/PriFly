# Agent guidance

## Read design before changing the system

1. Read `docs/doc-manifest.md` to learn the adopted documentation shape.
2. Read `CONTEXT.md` for canonical vocabulary.
3. Read the generated table in `docs/adr/README.md` first; open only the active ADRs relevant to the change.
4. Read the relevant explanation/reference docs from `docs/README.md`.

## Durable design flow

Durable design decisions are made with owner interrogation, decomposed through planning, recorded through the `design-docs` framework, and then implemented/reviewed through the repository workflow.

- Do not commit design specs, plans, interrogation transcripts, research reports, or audit gap reports.
- Do not create `docs/design/`, `docs/superpowers/`, or other spec directories.
- Architecture-changing decisions that pass the ADR trigger test require an ADR plus updates to every affected canonical design document in the same change.
- Once an ADR is Accepted, its Context, Decision Drivers, Considered Options and Decision are immutable; supersede or amend it with a new ADR instead.
- Code comments should not carry issue/ADR archaeology. When a local implementation needs durable reasoning, use a `# why:` pointer into a declared rationale area.
