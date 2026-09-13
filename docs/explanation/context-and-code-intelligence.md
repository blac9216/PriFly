# Context and code intelligence

Kind: explanation

Factory owns the durable meaning of project context. Git supplies universal deterministic repository facts; optional code-intelligence providers improve orientation and precision without becoming canonical knowledge.

Git is the universal code-intelligence substrate. Optional providers such as Graft/Serena provide richer analysis.

### Context fingerprints

Important code-intelligence results carry provenance/fingerprint sufficient for their permitted use, including as applicable:

- repository identity;
- base commit;
- dirty worktree/candidate identity;
- provider/version/configuration;
- dependency/tool inputs;
- coverage/uncertainty;
- timestamp/freshness conditions.

Out-of-order or mismatched results cannot satisfy exact delivery/planning gates. Best-effort context remains useful for orientation but cannot masquerade as exact acceptance evidence.

### Research freshness

Research Claims can carry `valid_as_of` / recheck conditions. Dispatch/acceptance checks whether a relied-on claim has expired when policy requires freshness.

### Derived caches

Indexes remain disposable derived caches, never canonical state.

## Execution manifests and tool compatibility

Recording a version string is insufficient. Every managed job records a resolved execution manifest containing the material components/configuration that affect the job, such as Factory protocol version, harness/model identity, tool/capability profile, Serena/Graft/runtime version if used, and relevant sandbox/runtime mode.

If a material maintenance update changes the actual execution closure during an attempt, Factory either proves the new combination compatible under the Route's declared policy or terminates/requeues a fresh attempt under a new execution identity. PriFly does not keep obsolete harnesses solely for performance, but maintenance/security updates still run compatibility/security smoke checks before ordinary autonomous use resumes.
