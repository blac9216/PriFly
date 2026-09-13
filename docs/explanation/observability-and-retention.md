# Observability, retention, and replayability

Kind: explanation

PriFly preserves compact semantic history and long-term learning metrics while allowing high-volume diagnostics and raw context to expire. Replayability is an explicit property, not something inferred from hashes after inputs are deleted.

### Historical metrics

Metrics used for long-term Factory learning are authoritative semantic state and are preserved across host loss.

Examples:

- exact Route/execution manifest;
- tokens/cache where available;
- duration;
- review rounds;
- severe failure/rescue;
- scope expansion;
- verification outcome;
- owner intervention;
- estimate/impact prediction accuracy.

### Diagnostic artifacts

Large logs/evidence reside in R2 with retention metadata.

### Replayability is explicit

PriFly does not retain every prompt/context forever merely to preserve theoretical replay.

A historical run has a computed replayability state such as:

- `EXACT_REPLAYABLE`;
- `CONDITIONALLY_REPLAYABLE`;
- `NOT_REPLAYABLE`.

Deleting raw context may legitimately change replayability without invalidating compact acceptance/audit evidence.

Experiments requiring exact replay may only select runs whose required inputs are retained.

### Auxiliary stores

If a harness/runtime maintains session history, caches, or pane history, the Route adapter declares whether those stores participate in retention/replay and ensures they are removed/disabled according to Factory policy for managed jobs.

Restoring an old Factory backup does not automatically restore deliberately expired auxiliary diagnostic data unless the retention policy explicitly guarantees it.

---
