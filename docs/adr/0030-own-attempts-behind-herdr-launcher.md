# ADR-0030: Own attempts behind a controller-owned HerdR launcher

Status: Proposed
Amends: 0014, 0015, 0019, 0025
Date: 2026-09-16

## Context

R1 established that HerdR's private socket offers orchestration control, while its pane/process observations do not prove detached writers stopped. Two subscription harnesses must run concurrently, retained workspaces must survive fresh correction, and Workers must not gain controller/owner privileges.

## Decision Drivers

Typed attempt authority; no HerdR fork on current evidence; cancellation/handoff; ordinary interactive subscription mode; separation of Factory-hosting and Worker Docker; measured shared-host resource bounds.

## Considered Options

(1) Separate per-attempt Linux users/cgroups inside one runtime service: lower container overhead but more complex UID/ACL/home and detached-child controls. (2) Trusted lifecycle launcher attaching attempt containers to private HerdR panes: explicit process/filesystem/container inventory, at the cost of privileged trusted lifecycle control and wrapper qualification. A shared UID with only environment filtering is invalid because the raw socket remains reachable.

## Decision

Adopt the initial topology and execution-runtime contract: one disposable attempt container, one retained Work Item workspace, private controller HerdR, launcher-only stack-engine lifecycle access, separate Worker Docker through scoped proxy, no Worker outer/control socket, no auto-resume, verified stop before handoff, quarantine on uncertainty. Only trusted controller operations attach/create/stop; Worker Docker requests cannot create Factory attempts. Observation is read-only by default. All profiles retain the accepted non-malicious threat model.

## Consequences

No inherent claim of malicious-code containment. Real mount, UID, cgroup and Docker proxy qualification is mandatory. The running controller is outside candidate Worker mounts. Native HerdR agent detection may be reduced across wrappers but never becomes workflow authority. Failure of the interactive-launch/cancellation conformance probes requires design revision before runtime admission.

Refs: [owner scope and ratified research](https://github.com/blac9216/PriFly/issues/38), [architecture](../explanation/architecture.md), [parameters](../reference/deployment-parameters.md), [conformance](../reference/conformance.md), [owner D3 design approval](https://github.com/blac9216/PriFly/issues/38#issuecomment-5701739109). This ADR remains Proposed; owner approval of the D3 design baseline containing this choice is recorded in the linked #38 comment, not in this file.
