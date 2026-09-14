# Planning policy defaults

Kind: reference

PriFly separates **proposed semantic classification** from **effective authorization** and evaluates planning artifacts through three distinct layers:

1. **Industry quality** — reusable standards-backed rubrics from [Quality rubrics](quality-rubrics.md).
2. **Project conformance** — adherence to the governing owner need, Requirements, Decisions, Constraints, Design, and released Planning Baseline.
3. **PriFly workflow policy** — authority, applicability, traceability, gate state, independence, dependencies, blocking Findings, and other lifecycle rules.

A gate passes only when all three applicable layers pass. Project-specific design rules are not converted into “industry rubrics,” and a high-quality artifact does not pass if it violates the governing project design.

## Mandatory concern inventory

Factory owns a versioned mandatory concern inventory. Candidate families include:

- product/user behavior;
- functional requirements;
- quality attributes;
- persisted data;
- migration/compatibility;
- security/trust;
- public/external contracts;
- recovery/destructive behavior;
- operations/observability;
- verification/testing;
- rollout/rollback;
- documentation/support;
- dependency/risk.

A concern family not covered by the active policy remains `UNKNOWN` and cannot clear a blocking gate.

## Applicability state

Each concern has:

```text
proposed_applicability:
  APPLICABLE | NOT_APPLICABLE | UNKNOWN

effective_applicability:
  APPLICABLE | NOT_APPLICABLE | UNKNOWN
```

A Worker may propose the first value. Only Factory policy can establish the second.

`UNKNOWN` is always conservative.

## Initial effective authority table

The initial v1 policy uses the following minimum authority rules:

| Concern / change family | Minimum effective treatment | Who may establish NOT_APPLICABLE / lower treatment |
|---|---|---|
| Constitution | Constitutional / owner-gated | Only explicit owner action may change/supersede Constitution; not suppressible by Worker classification |
| Security/trust boundary | At least Strategic when the trust boundary changes; otherwise concern remains evaluated | Architect proposal + fresh independent review may establish N/A only when no protected trigger/uncertainty exists |
| Persisted schema/state & migration | Migration concern forced applicable when declared persisted schema/storage semantics change | Architect proposal + fresh review may establish N/A only with evidence that no persisted state/schema/compatibility behavior changes |
| Destructive/data-loss/recovery semantics | At least Strategic for materially destructive/irreversible behavior | Cannot be lowered below policy minimum by producer; owner action required for accepted material residual risk |
| Public/external API or compatibility contract | At least Project, Strategic when materially breaking | Architect proposal + fresh review may establish N/A only when no external/public contract is affected |
| Cross-project architecture | At least Strategic | Owner action for material cross-project direction |
| Ordinary local implementation detail | Local within the Work Item/Design delegation envelope | Producer may act under standing delegation if no protected trigger/UNKNOWN exists |
| Other mandatory concern families | According to explicit policy rule | If no rule exists or evidence/coverage is insufficient: `UNKNOWN` and blocking |

The table may evolve through versioned owner-approved policy changes, but **absence of a rule never becomes permission**.

## Protected triggers and trigger provenance

Factory applies deterministic/procedural triggers where the project exposes independently observable surfaces.

Examples:

- a declared persisted schema/migration manifest changes;
- a new external endpoint or public interface is declared;
- a secret/auth/trust-boundary configuration changes;
- destructive/recovery operations are introduced;
- work crosses Project boundaries.

Every protected-trigger result records its provenance.

Where PriFly cannot determine the protected condition from an admitted observable surface, it records `UNKNOWN`; it does not accept a producer's "nothing changed" assertion as the trigger itself.

AI semantic judgment may still provide evidence, but is represented as a reviewed assertion rather than deterministic fact.

## Standards-backed rubric applicability

The active Planning Policy pins the exact version of every blocking quality-rubric profile used by its gates. Core profiles and lifecycle composition are defined in [Quality rubrics](quality-rubrics.md); their source versions are pinned in [Standards registry](standards-registry.md).

For an applicable blocking criterion:

```text
PASS            clears the quality criterion
FAIL            blocks
NOT_APPLICABLE  clears only through its declared applicability path
UNKNOWN         blocks
```

A producer/reviewer may not remove a criterion because it is inconvenient or unavailable. If an official source/criterion cannot be resolved with adequate evidence, the result remains `UNKNOWN`.

Conditional overlays such as WCAG, OWASP ASVS, SLSA, user-information, or other project-specific standards profiles become blocking only after project/policy applicability and the exact version/target profile are fixed.

### Thresholds left to the project

When a source standard defines a quality characteristic/measure but leaves the acceptable value context-specific, Planning must establish the target/range/rule before releasing affected Work Items.

Examples include:

- performance/latency/resource limits;
- availability/reliability targets;
- product-quality measure ranges;
- compatibility scope;
- accessibility conformance target;
- application-security verification target/profile;
- supply-chain assurance target;
- other context-dependent acceptance thresholds.

A Worker, Reviewer, Validator, or acceptance step cannot invent or weaken a threshold after observing implementation results.

## Gate 1 — Design Completeness

Gate 1 releases an immutable Design Baseline only when all blocking planning/design concerns are resolved.

### Industry-quality layer

At minimum, apply the relevant versions of:

- `stakeholder-need-quality/v1` where owner/stakeholder intent is being formalized;
- `requirement-quality/v1` to all binding Requirements;
- `quality-requirement-quality/v1` to applicable quality Requirements;
- `architecture-description-quality/v1`;
- `architecture-evaluation-quality/v1`;
- `risk-record-quality/v1` to material Risks;
- `evidence-provenance-quality/v1` to consequential Research Claims/evidence relied on by the Design;
- `security-engineering-quality/v1` where security/trust concerns are applicable.

Any other activated standards profile required by the Project also applies.

### Project-conformance layer

Before release, verify at least:

- Design traces to the governing owner needs and Requirements;
- Decisions/Design do not violate governing Constraints/Constitution;
- quality targets used by Design match the baselined quality Requirements;
- Research Claims/evidence support the Decisions that rely on them;
- material interfaces/dependencies and change-impact assumptions are consistent with the Project's actual boundary.

### Workflow-policy layer

Zero unresolved blocking applicable concerns before decomposition, including no blocking `UNKNOWN`; required authority decisions resolved; required fresh challenge/review complete; traceability sufficient for downstream invalidation/change control.

PriFly claims deterministic enforcement of declared gate criteria, **not mathematical proof that AI discovered every possible semantic concern**.

## Gate 2 — Delivery Readiness

Gate 2 releases an executable delivery plan only after decomposition and verification planning are objectively ready.

### Industry-quality layer

At minimum, apply the relevant versions of:

- `plan-quality/v1` to the released delivery plan/decomposition;
- `verification-plan-quality/v1` to every blocking Verification definition;
- `estimate-quality/v1` where estimates influence scheduling/capacity/commitment;
- `risk-record-quality/v1` to material delivery Risks;
- `security-engineering-quality/v1` and `documentation-quality/v1` when those obligations affect delivery.

For Work Item contracts, apply the requirement-quality dimensions that are semantically appropriate to Required Outcomes/Constraints and the verification-plan rubric to their Verification. PriFly's `SLICE` default, walking-skeleton priority, and exceptional `ENABLER` policy remain workflow/decomposition policy rather than being mislabeled as industry standards.

### Project-conformance layer

Before release:

- every baseline Requirement/Design obligation has appropriate delivery/verification coverage;
- no orphan Work Item exists without a baseline purpose;
- Work Item Goal/Required Outcomes/Constraints/Verification faithfully implement the Design Baseline;
- estimates and verification targets use the baselined scope/quality thresholds;
- no decomposition invents a new protected architecture/product decision without change control.

### Workflow-policy layer

Dependencies are valid/acyclic; slices are bounded; early integrated/testable value exists; lanes/collision assumptions are coherent; verification design survived fresh challenge; the plan survived fresh adversarial review; no blocking Finding/`UNKNOWN` remains.

## Delegation grants

A standing delegation is an owner/policy-authorized object with:

- scope;
- allowed decision classes;
- protected surfaces it may not cross;
- expiry/version;
- evidence/review requirements.

A Local decision is effective only if an applicable delegation covers it.

Any protected-surface change, uncertainty, or cumulative scope expansion outside the grant invalidates the delegation and escalates.

## NOT_APPLICABLE transition

A proposed `NOT_APPLICABLE` becomes effective only when:

1. an active policy rule names the allowed assertion/review path;
2. required evidence is present;
3. required independent review passes;
4. no protected trigger conflicts;
5. no required detector/coverage result is `UNKNOWN`;
6. the assertion remains inside any applicable delegation.

A reviewed `NOT_APPLICABLE` string by itself is never authority.
