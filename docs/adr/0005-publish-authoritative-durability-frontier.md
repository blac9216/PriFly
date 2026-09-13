# ADR-0005: Publish an authoritative durability frontier before acknowledgement

Status: Proposed
Date: 2026-09-13

## Context

PriFly needs a stronger guarantee than either “SQLite committed” or “remote bytes exist”: every permitted successor must recover every acknowledged authoritative result.

## Decision Drivers

- Acknowledged semantic state must survive loss of the local host.
- Remote bytes alone are not enough if recovery can choose an older lineage.
- The protocol must have a testable linearization point without distributed consensus.

## Considered Options

### Remote durability plus CAS-published frontier

Commit locally, sync the exact transaction remotely, then CAS-publish the authoritative restore frontier before release.

### Asynchronous replication for semantic state

Lower latency but permits acknowledged Findings/decisions/acceptance state to disappear.

### Remote sync without published recovery frontier

Proves bytes exist remotely but not that every successor must preserve them.

### Synchronous remote database as primary store

Avoids local/remote frontier distinction but changes the local-first architecture and adds remote dependency to every DB operation.

## Decision

An authoritative mutation is not released until its SQLite transaction is remotely durable and the exact remote restore position is CAS-published in the single Factory coordination record. Uploaded-but-unpublished tails are non-authoritative.

## Consequences

Authoritative publication may add network latency, so v1 serializes the release lane for simplicity. Recovery has an exact allowed frontier. Ephemeral telemetry remains asynchronous/lossy.
