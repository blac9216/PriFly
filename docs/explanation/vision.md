# Vision and v1 scope

Kind: explanation

This document explains what PriFly is trying to become and, equally importantly, what v1 deliberately does not promise. Architectural mechanisms belong in the other explanation docs and ADRs.

PriFly is a local-first autonomous software factory. Its purpose is to let an owner express intent conversationally while deterministic software owns workflow, state, policy enforcement, scheduling, formatting, recovery, provider mutations, and long-running orchestration. AI is invoked only for bounded work that benefits from inference, judgment, research, coding, review, validation, or synthesis.

PriFly should continue useful work without an active conversational session. Its local installation is disposable: loss of the local PriFly host should cost at most bounded in-progress computation rather than the Factory's authoritative state, accepted code checkpoints, or historical metrics.

### Core maxim

> **Big orchestration system, small cognitive jobs.**

### Primary operating principle

> **Deterministic software owns workflow, authoritative state, policy enforcement, scheduling, formatting, recovery, and external side effects. AI Workers perform bounded cognitive jobs inside Factory-defined contracts.**

## v1 scope and threat model

PriFly v1 is a **personal autonomous software factory**, not a hostile-code execution platform, enterprise disaster-recovery product, or multi-user hosted control plane.

### Worker threat model

Workers and configured harnesses are treated as fallible, capable of misunderstanding instructions, capable of modifying the wrong file if not constrained, capable of producing bad code or reasoning, capable of accidentally conflicting with another Worker, and capable of issuing overly broad Docker commands within the Worker Docker environment; they are **not assumed malicious or actively compromised**.

v1 promises strong guardrails against ordinary operational mistakes, but it does **not** promise containment of an intentionally malicious Worker/harness that attempts privilege escalation, kernel/container escape, direct Factory tampering, or deliberate secret theft. Stronger adversarial isolation remains a future `SandboxProvider` concern.

### Recovery threat model

v1 primarily promises recovery from **loss/corruption of the local PriFly host** while Cloudflare R2, configured Git remotes, the owner's cloud/provider accounts, and the Recovery Kit/root recovery material remain available.

v1 does **not** promise survival of permanent R2 account loss, permanent Git hosting account loss, simultaneous loss of every external dependency, hostile cloud-credential deletion of every recovery copy, or malicious corruption of every retained recovery root.

## Explicit v1 deferrals and accepted limitations

Deferred: malicious/compromised Worker containment; per-Worker microVM isolation; multi-cloud recovery; permanent R2/Git account-loss recovery; hostile cloud-credential deletion recovery; enterprise DLP; remote/multi-user Bridge security; distributed Workers; automatic lease-expiry takeover; atomic cross-repository merge; Redis/PostgreSQL; hosted Factory; plugin SDK; automatic routing-policy mutation; broad GitLab implementation; and advanced prompt-codec optimization.

These deferrals are part of the v1 contract rather than hidden missing mechanisms.
