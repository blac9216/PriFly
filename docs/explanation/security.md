# Security and trust model

Kind: explanation

This document states the actual v1 threat model. It deliberately avoids claiming hostile-agent containment that v1 does not provide, while preserving least-privilege workflow boundaries and explicit owner authority.

## v1 threat model

PriFly v1 is a **personal autonomous software factory**, not a hostile-code execution platform, enterprise disaster-recovery product, or multi-user hosted control plane.

### Worker threat model

Workers and configured harnesses are treated as fallible, capable of misunderstanding instructions, modifying the wrong file if not constrained, producing bad code or reasoning, accidentally conflicting with another Worker, and issuing overly broad Docker commands within the Worker Docker environment; they are **not assumed malicious or actively compromised**.

v1 promises strong guardrails against ordinary operational mistakes, but it does **not** promise containment of an intentionally malicious Worker/harness that attempts privilege escalation, kernel/container escape, direct Factory tampering, or deliberate secret theft. Stronger adversarial isolation remains a future `SandboxProvider` concern.

### Recovery threat model

v1 primarily promises recovery from **loss/corruption of the local PriFly host** while Cloudflare R2, configured Git remotes, the owner's cloud/provider accounts, and the Recovery Kit/root recovery material remain available.

v1 does **not** promise survival of permanent R2 account loss, permanent Git hosting account loss, simultaneous loss of every external dependency, hostile cloud-credential deletion of every remote recovery copy, or malicious corruption of every retained recovery root. PriFly still protects at least one known-good checkpoint from ordinary cleanup mistakes.

## Worker execution boundary

PriFly v1 uses ephemeral Worker identities, dedicated worktrees, root-owned Factory state, Factory-owned provider credentials, and a Worker-only Docker daemon to prevent ordinary workflow mistakes from becoming control-plane mutations. The shared Worker Docker daemon is not an adversarial security boundary. Stronger hostile-code containment is intentionally deferred behind `SandboxProvider`.

## Privileged operations

Provider credentials remain with Factory. Workers do not normally receive protected-ref authority. The trusted Branch Publisher imports exact Worker commits into a controlled Git context rather than performing privileged pushes from a Worker-owned checkout.

## Owner authority

Consequential owner approval uses the separate owner-confirmation capability defined in [Pilot and owner interaction](pilot.md). Pilot may draft and explain but cannot mint the confirmation proof.

## Data egress and privacy scope

v1 does **not** attempt enterprise DLP. Configured model/harness services are permitted to receive the project context necessary to perform their jobs.

PriFly still avoids needless leakage: raw secrets do not belong in Worker packets; raw environment dumps are not normal logs; diagnostics are not exported unnecessarily; and unknown third-party destinations are not invented dynamically by Workers. Stronger per-Project destination classification, egress firewalling, and customer-data governance are deferred until the use case requires them.
