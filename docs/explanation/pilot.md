# Pilot and owner interaction

Kind: explanation

Pilot is a disposable natural-language control surface over Factory state. It is intentionally prevented from becoming a second orchestrator or from minting consequential owner consent.

### Pilot drafts; the human authorizes consequential actions

Pilot may interpret conversation and draft an Owner Action, but it does not possess the capability that confirms consequential owner actions. A consequential Owner Action is immutable/revision-bound and includes the exact action, target/revision, scope, material consequences, package digest, and expiry/staleness condition.

### Separate owner-confirmation capability

v1 provides an **owner-only local confirmation surface** unavailable to Pilot and Worker credentials.

```text
Pilot
  └─ may draft/present OA-19

Owner
  └─ prifly owner confirm OA-19
       ↓
     owner-control endpoint/capability
       ↓
     Factory verifies OA-19 digest/revision
```

The owner-control endpoint is protected separately from Pilot/job capabilities and is not mounted or exposed to Pilot/Worker identities. The confirmation proof binds Owner Action ID, package digest, target revision, scope, command ID, and owner-control principal. If the package changed, confirmation is rejected.

### Standing delegations

Owner confirmation is not required for every harmless action. Explicit standing delegations may authorize ordinary Local implementation choices, routine pause/resume, creation of research/planning requests, and other bounded reversible actions. Consequential actions outside a standing delegation require the owner-only confirmation capability.

### Silence and conversational interpretation

Silence is never approval. Pilot's interpretation of “yes”, quoted text, exploratory language, or negated language is never sufficient evidence for consequential confirmation. Pilot may explain a pending Owner Action and direct the owner to the confirmation surface.

## Attention and Pilot

Owner attention remains durable Factory state. Attention classes include BLOCKING, ACTION_REQUIRED, REVIEW_WHEN_CONVENIENT, and INFORMATIONAL. Pilot/Bridge consume canonical Attention Items and state-dependent actions. New Pilot sessions receive bounded Orientation Packets and progressively retrieve deeper context.
