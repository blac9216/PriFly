# Planning policy defaults

Kind: reference

PriFly separates **proposed semantic classification** from **effective authorization**.

### 11.1 Mandatory concern inventory

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

### 11.2 Applicability state

Each concern has:

```text
proposed_applicability:
  APPLICABLE | NOT_APPLICABLE | UNKNOWN

effective_applicability:
  APPLICABLE | NOT_APPLICABLE | UNKNOWN
```

A Worker may propose the first value. Only Factory policy can establish the second.

`UNKNOWN` is always conservative.

### 11.3 Initial effective authority table

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

### 11.4 Protected triggers and trigger provenance

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

### 11.5 Delegation grants

A standing delegation is an owner/policy-authorized object with:

- scope;
- allowed decision classes;
- protected surfaces it may not cross;
- expiry/version;
- evidence/review requirements.

A Local decision is effective only if an applicable delegation covers it.

Any protected-surface change, uncertainty, or cumulative scope expansion outside the grant invalidates the delegation and escalates.

### 11.6 NOT_APPLICABLE transition

A proposed `NOT_APPLICABLE` becomes effective only when:

1. an active policy rule names the allowed assertion/review path;
2. required evidence is present;
3. required independent review passes;
4. no protected trigger conflicts;
5. no required detector/coverage result is `UNKNOWN`;
6. the assertion remains inside any applicable delegation.

A reviewed `NOT_APPLICABLE` string by itself is never authority.
