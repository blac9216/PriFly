# ADR-0012: Checkpoint exact Worker commits and integrate with exact-ref compare-and-update

Status: Accepted
Date: 2026-09-13

## Context

PriFly needs both durable in-progress code and a strong guarantee that the code integrated is the code independently verified.

## Decision Drivers

- Worker progress should survive local-host loss without granting Workers protected-ref authority.
- Review must apply to the exact code later integrated.
- The target branch can move between verification and provider execution.

## Considered Options

### Exact Worker commits + Factory-published job refs + exact-ref integration

Preserve identical Git objects upstream, verify exact integration commit, update target only from expected base SHA.

### Replay Worker edits in trusted checkout

Avoids trusting Worker Git metadata but duplicates work and can lose exact history.

### Give Workers provider credentials

Easy checkpointing but Workers can push main or unrelated refs.

### Ordinary provider PR merge API

Good UI but does not necessarily enforce the exact verified base revision at execution time.

## Decision

Workers commit normally in dedicated worktrees. Factory checkpoints the exact commits to namespaced remote job refs through a controlled Branch Publisher. Accepted integration constructs and verifies exact commit M against base B and updates the target only if it is still exactly B.

## Consequences

Pull requests remain projections/UI rather than the authoritative integration primitive. Target movement forces revalidation. Job branches can be discarded after accepted code is retained elsewhere or the candidate is abandoned.
