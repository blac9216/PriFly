# Routing and capacity

Kind: explanation

PriFly routes work deterministically across harness/model combinations, protects scarce high-value capacity, and maximizes useful concurrency rather than raw Worker count.

A Route is a versioned execution configuration including harness, model, effort/reasoning, auth/account mode, capability profile, Capacity Pool, and material resolved execution manifest. Worker role and Route are independent. Routing policy is deterministic/versioned, quality eligibility precedes cost/capacity optimization, and capability tiers are contextual by role/task/language/risk.

## Capacity, concurrency, and cumulative execution envelope

### Capacity

Capacity Pools represent subscription, metered API, local compute, or harness limits. Unknown quota remains unknown. Pressure states may include HEALTHY, ELEVATED, PRESSURE, CRITICAL, and EXHAUSTED.

### Concurrency

PriFly maximizes useful concurrency subject to dependency readiness, critical path, worktree/file/semantic collision risk, review/validation backpressure, Route capacity, and host resource pressure. There is no arbitrary normal Factory-wide Worker target.

### Work Item execution envelope

Every Work Item has a cumulative execution envelope spanning Implementer attempts, Fixers, reimplementations, Reviews, Validators, and diagnostic arbitration. The envelope may constrain attempt count, elapsed time, premium-route usage, token/usage budget where measurable, storage/worktree growth, and repeated severe failures. Child jobs do not reset the envelope. Exhaustion enters owner attention/escalation rather than looping indefinitely. Factory preserves control/recovery headroom and may stop new Worker admission under severe disk/replication pressure.
