# Architectural principles

Kind: explanation

These invariants are the guardrails other design docs must preserve. They are concise on purpose: detailed mechanisms live in the linked subsystem docs and accepted ADRs.

1. Factory is the sole authoritative workflow-state owner.
2. There is one authoritative typed Command mutation path.
3. Pilot is an interface, never a project Worker.
4. Losing Pilot cannot lose meaningful Factory work.
5. Workers do not orchestrate Factory Workers.
6. Consequential AI artifacts cannot self-promote.
7. Provider systems are external facts/projections, not Factory workflow authority.
8. Git stores code/history; it does not become PriFly workflow state.
9. AUTHORITATIVE semantic state is not acknowledged until its transaction is remotely durable **and its remote frontier is CAS-published in the coordination record**.
10. The coordination publication is the authoritative recovery-lineage linearization point.
11. Uploaded-but-unpublished database tails are non-authoritative and may be discarded on recovery.
12. Consequential external effects are durable obligations and must reach AUTHORITATIVE `SEND_ARMED` before the first network send.
13. A recovered unresolved `SEND_ARMED` operation is treated as possibly sent and therefore UNKNOWN until proven terminal by its operation profile.
14. Factory generations fence new authoritative publication/authorization; they do not cancel already-SEND_ARMED/sent effects.
15. v1 takeover is explicit, not timer-driven.
16. A takeover CAS fences further authoritative publication by the predecessor generation; successors restore exactly the predecessor's published frontier.
17. Code checkpoints preserve exact Worker Git commits; edits are never replayed merely to reconstruct code.
18. Acceptance Certificates bind exact planning, attempt, code, integration target, evidence, review, and policy revisions.
19. Required non-Git acceptance evidence is durably uploaded/verified before acceptance is released.
20. Supported recovery roots pin the required external evidence/Git/key closure until authoritative retirement.
21. `UNKNOWN` impact/applicability never silently clears a gate.
22. AI may propose semantic classifications; effective applicability/delegation follows explicit Factory authority rules.
23. Consequential owner consent requires an owner-only confirmation capability unavailable to Pilot/Worker credentials.
24. v1 Workers are fallible/non-malicious; hostile Worker/harness containment remains outside the v1 guarantee.
25. The Worker Docker daemon is separate from the outer Factory-hosting Docker context but is not a malicious-code security boundary.
26. Every admitted runtime can be cancelled/reconciled to one active Factory attempt; uncontrolled resume modes are not admitted.
27. If shared Worker-Docker cleanup cannot be proven, PriFly may destroy/recreate the disposable Worker Docker environment rather than tolerate stale execution.
28. Recovery guarantees local-host-loss recovery while declared remote dependencies/accounts remain available.
29. Rollback to pre-upgrade state ends when the upgraded Factory first publishes new authoritative state.
30. Runtime descendants remain inside one active job attempt and cumulative execution envelope.
31. Historical learning metrics are durable; ephemeral telemetry may be lost.
32. Replayability is explicit, not inferred from retained hashes.
33. Operational adaptation may be autonomous; governing policy evolution remains controlled.
34. General engineering quality, project conformance, and PriFly workflow permission are separate evaluations; none substitutes for another.
35. Consequential work products use pinned versioned standards-backed quality rubrics; applicable blocking `FAIL` or unresolved `UNKNOWN` prevents promotion.
36. When an industry standard leaves an acceptance threshold context-specific, the governing Planning Baseline fixes that threshold before affected delivery work is released; later Workers/Reviewers do not invent or weaken it.
