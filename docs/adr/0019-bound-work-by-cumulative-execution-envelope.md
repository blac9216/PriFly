# ADR-0019: Bound autonomous work with cumulative execution envelopes

Status: Accepted
Amended-by: 0025, 0030
Date: 2026-09-13

## Context

The Factory is intended to operate unattended, so autonomy needs an explicit stopping boundary that remains meaningful across child jobs and retries.

## Decision Drivers

- Autonomous retries, Fixers, Reviewers, and reimplementations can otherwise loop indefinitely.
- Per-job limits are insufficient when every child starts a fresh budget.
- Runtime descendants and Docker workloads must remain attributable to an active attempt.

## Considered Options

### Work Item-wide cumulative envelope + managed runtime resources

Attempts/fixes/reviews share one bounded budget; exhaustion escalates and runtime cleanup is enforced.

### Unlimited retry until success

Maximizes persistence but can burn subscription/API capacity indefinitely.

### Only per-job timeout

Easy but child jobs reset the meter and daemon-managed resources can outlive the attempt.

### Hard global Worker count only

Bounds concurrency but not cumulative cost/time/storage or stale execution.

## Decision

Every Work Item carries a cumulative execution envelope spanning implementation, fixes, reviews, validation, and diagnostic arbitration. Uncontrolled runtime resume modes are not admitted. Attempt-owned Docker/runtime resources are reconciled on cancellation; uncertain shared Worker-Docker cleanup blocks new Docker work and may reset the disposable daemon.

## Consequences

Some useful work may escalate to the owner rather than retry forever. The runtime adapter needs attempt-resource inventories and cancellation tests. The design prefers blunt disposable reset over hidden stale execution.
