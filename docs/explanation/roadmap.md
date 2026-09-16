# Product delivery progression

Kind: explanation

## Delivery strategy and release progression

### Build usable vertical paths

Implementation should reach a testable product early, rather than complete every backend subsystem before exposing a single owner journey. The following progression is a proposed decomposition strategy, not dated commitments or already-created milestones. Detailed Work Items are created only after this design is reviewed and their planning gates are satisfied.

| Increment | Usable outcome | Necessary controls included from the start |
|---|---|---|
| 1. Durable conversational control slice | CLI/Pilot can capture Intake without fan-out, query it, replace its session, and observe one explicitly authorized bounded HerdR job. | Typed commands, exact-scope owner release, actor identity, core persistence/publication proof, separated sessions, runtime attempt/prompt identity, deterministic rendering, basic metrics. |
| 2. One reviewed PR | One scoped Work Item is implemented, tested, independently reviewed, corrected in the same workspace if necessary, and merged through GitHub. | Exact evidence identity, Implementer-authored PR Draft, same-review test collection, fresh Implementer correction, structured review history, branch authority, admitted merge profile. |
| 3. Product proof and common triage | Integrated work creates a validation target; Validator failure creates normal planned work and later returns the target to pending. | Per-target versions, common triage, hold/batch tracking, validation precedence, normal target re-pending and scheduling. |
| 4. Full planning and multi-repository work | Owner intent passes requirements/design and delivery gates, then produces useful parallel slices across repositories and Routes. | Three owner releases, reviewable new/feature design packages, synthesis, pure execution estimates, configurable Initiative-milestone/issue/board projections, standards profiles, change control, collision handling, cumulative envelopes. |
| 5. Operational recovery and safe update qualification | The useful product survives host loss and an interrupted upgrade under the declared guarantees. | Recovery Kit, restore lifetime, required evidence pins, migration policy, repair CLI, runtime cleanup. |
| 6. Complete v1 product lifecycle and learning | Releases/closeout account for all findings and validation; measured experiments support route decisions. | Release evidence, closure sweep, all-assigned experiment accounting, source/version governance, owner control. |

Durability cannot be deferred until Increment 5 while earlier increments claim host-loss-safe authoritative success. Increment 1 must prove the narrow publication/recovery foundation for its own state; Increment 5 broadens and qualifies the complete recovery surface as more objects/resources exist. Likewise, metrics begin with the first jobs rather than being reconstructed later from logs.

### Qualification before broad autonomy

Each newly supported harness, runtime mode, repository integration profile, persistence configuration, and validation environment is admitted only after the controls it relies on are tested. Early increments can use a smaller admitted matrix without claiming arbitrary compatibility.

The owner can operate narrowly scoped real work while some later product capabilities remain unavailable. Unsupported operations return explicit unsupported/not-ready status. The product must not let a partially implemented gate silently become an unconditional pass.

### v1 release gate

A full v1 release requires the agreed scope, required acceptance scenarios, selected deployment bill of materials, supported recovery/upgrade paths, operator documentation, and measured quality requirements to be satisfied. Architecture approval alone is not a release certification. Any accepted residual limitations are named, authorized, and reflected in product claims.
