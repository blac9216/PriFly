# ADR-0026: Bootstrap from an encrypted private Git manifest

Status: Proposed
Amends: 0016
Date: 2026-09-16

## Context

ADR-0016 requires an independent Recovery Kit without fixing its packaging. PRD Candidate 2.1 §24 selects a private Git repository containing bootstrap.json and secrets.json.age. This amends the Kit's concrete delivery contract while retaining its host-loss assumptions and upgrade cutoff. Owner direction is issue #36.

## Decision Drivers

- A clean host must recover without the lost home directory or circular credentials.
- Plaintext secrets must not enter prompts, Git, logs or general scratch.
- Bootstrap must distinguish new initialization from existing Factory recovery.

## Considered Options

### Pinned private repository manifest plus age-encrypted JSON

Selected by the PRD. Gives versioned configuration and encrypted secret distribution with independent fetch/decryption prerequisites.

### Unspecified manually assembled recovery material

The former abstract Kit permits several mechanisms but does not provide the requested reproducible startup path.

These alternatives compare the supplied product direction with the prior documented mechanisms; they do not reconstruct an unrecorded owner interrogation.

## Decision

The bootstrap repository contains a non-secret versioned bootstrap.json, secrets.json.age and supported instructions. The independent Recovery Kit retains the repository locator/revision, fetch access, age decryption material and owner/recovery authority outside the disposable host and outside the encrypted dependency. Restricted bootstrap fetches the exact revision without executing hooks, validates identity/compatibility/digests, decrypts through protected transient handling, validates the secret schema and scopes provisioning. Remote discovery failure never initializes an empty Factory. Existing recovery requires explicit takeover and exact Published Frontier restoration. Rotation preserves compatible keys or verified rewrap paths for supported roots.

## Consequences

The release must qualify versions, protected input/storage, clean-host acquisition and rotation. The private repository is configuration delivery, not a new workflow database. Pre-ACTIVE repair remains usable without Pilot.

Canonical contracts: [documentation index](../README.md) and [source traceability](../reference/traceability.md). Proposed here for independent review; no implementation certification is implied.
