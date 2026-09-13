# Canonical schema families

Kind: reference

PriFly's durable semantic contracts are structured JSON with explicit schema versions. JSON Schema provides structural validation; Go domain logic provides semantic validation.

## Core families

| Family | Purpose |
|---|---|
| `command/*` | Requested authoritative mutations. |
| `event/*` | Semantic facts appended to the Ledger. |
| `planning-record/*` | Planning graph and lifecycle metadata. |
| `research-claim/*` | Claim-level provenance, freshness, and confidence. |
| `decision/*` | Scoped approved choices and authority metadata. |
| `work-item/*` | Goal, Required Outcomes, Constraints, Verification, scope. |
| `worker-job/*` | Role, Route, attempt identity, context, execution envelope. |
| `worker-result/*` | Structured Worker output and produced artifact identities. |
| `finding/*` | Review/validation/research finding for Factory triage. |
| `review-result/*` | Independent review verdict and structured findings. |
| `verification-result/*` | Machine-observed checks and execution manifest. |
| `acceptance-certificate/*` | Exact acceptance subject. |
| `acceptance-evidence-manifest/*` | Required evidence, optional diagnostics, and code roots. |
| `recovery-root-manifest/*` | External dependency closure for a supported checkpoint. |
| `attention-item/*` | Durable owner-attention state and permitted actions. |
| `owner-action/*` | Immutable consequential action package awaiting owner authority. |
| `route/*` | Versioned execution configuration. |
| `experiment/*` | Controlled experiment definition, assignment, metrics, guards. |
| `provider-obligation/*` | External operation intent, conflict scope, and state. |
| `factory-status/*` | Factory health/recovery state for clients. |

## Versioning rules

- Schema version is part of the type identity.
- Historical Ledger events are not rewritten merely to use a newer schema.
- Current projections may be deterministically migrated.
- A Worker output must pass structural and semantic validation before becoming canonical state.
- Renderer/template changes do not mutate canonical semantics.

## Prompt serialization

Prompt codecs are projections over canonical objects. Compact JSON, Markdown, XML-tagged formats, TOON, or future codecs may be benchmarked experimentally without changing the underlying schema.
