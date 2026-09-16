# Product and dependency sources

Kind: reference

## Sources, provenance, and standards access

### Product sources

Source precedence is explicit owner direction; the [accepted PRD](product-requirements.md);
the appropriately updated canonical design and active decision relationships; then qualified
implementation behavior. Historical artifacts provide provenance,
not permission to restore a replaced requirement. External technical documentation describes
dependencies; it does not decide PriFly's scope.

The P/S source identifiers below are retained from the owner-supplied PRD for stable references.
Historical read dates and conversation provenance are claims inherited from that source, not
claims that this repository reconciliation independently inspected those conversations or every
external page. [Traceability](traceability.md) pins the original supplied Candidate 2.1 bytes
and identifies their accepted canonical successor.
[Standards registry](standards-registry.md) governs editions and access limitations; technology
admission requires evidence for the selected version/configuration.

### source-p1

**P1 — Prior repository baseline.** [PriFly at a4778bac9567dee6d358478cdee2e16e1771f39a](https://github.com/blac9216/PriFly/tree/a4778bac9567dee6d358478cdee2e16e1771f39a).
Historical architecture, planning, execution, persistence, recovery and contracts. It is comparison
material, not the authority for a mechanism replaced by the revised PRD.

### source-p2

**P2 — Historical architecture decisions.** [Decision register at the baseline](https://github.com/blac9216/PriFly/blob/a4778bac9567dee6d358478cdee2e16e1771f39a/docs/adr/README.md).
The source PRD also cites earlier architecture-review candidates; those private review transcripts
are not independently reproduced or verified here. Accepted bodies remain history with explicit
amendment/supersession relationships.

### source-p3

**P3 — Adopted quality inventory.** [Prior quality rubrics](https://github.com/blac9216/PriFly/blob/a4778bac9567dee6d358478cdee2e16e1771f39a/docs/reference/quality-rubrics.md)
and [standards registry](https://github.com/blac9216/PriFly/blob/a4778bac9567dee6d358478cdee2e16e1771f39a/docs/reference/standards-registry.md).
Local profile/criterion identities are retained. Normalized questions are not verbatim clauses
or a claim of complete standards conformance.

### source-p4

**P4 — Owner product direction.** The [accepted PRD v2.1](product-requirements.md) and the owner's reconciliation request
govern phase releases, foundation/feature packages, execution estimates, Serena, fresh correction
attempts, review history, configurable projections and Initiative-to-milestone mapping. The PRD
attributes earlier direction to its design conversation; that conversation is not available as
independent evidence in this repository.

### source-p5

**P5 — Revision and documentation framework provenance.** The PRD describes Candidate 1 and
an edit discussion as earlier revision inputs. This decomposition uses the [accepted v2.1 baseline](product-requirements.md), not inferred
missing attachments. The adopted [design-docs framework](https://github.com/blac9216/.devcontainer/tree/main/ai/skills/design-docs)
supplies canonical layout and immutable decision-history rules; it does not grant Factory authority.

### source-p6

**P6 — Workflow inspiration, selectively adapted.** The source cites
[plan-work](https://github.com/blac9216/.devcontainer/tree/main/ai/skills/plan-work),
[github-workflow](https://github.com/blac9216/.devcontainer/tree/main/ai/skills/github-workflow) and
[github-pr-review](https://github.com/blac9216/.devcontainer/tree/main/ai/skills/github-pr-review).
Useful outcomes include concrete plans, review conversation and adversarial probes.
Their repository procedures are not imported as PriFly runtime authority, mandatory provider
hierarchy or Reviewer-owned merge behavior.

### PRD structure and runtime/tool sources

The following external bibliography is inherited from Candidate 2.1. Official public documentation
can support scope/capability claims, but cannot establish PriFly integration conformance. Mutable
tool URLs require version-specific qualification before admission. No fresh inspection of every
unchanged source or licensed full text is claimed.

### source-s01
**S01 — Atlassian: Product requirements documents.** [PRD guidance](https://www.atlassian.com/agile/product-management/requirements). Used for customary purpose, goals, scope, requirements, stories, and product alignment structure; not a formal mandatory PRD standard.

### source-s02
**S02 — Atlassian: Product requirements template.** [Template](https://www.atlassian.com/software/confluence/templates/product-requirements). Supports explicit goals, assumptions, requirements, design context, questions, and excluded scope. The product definition intentionally expands the usual short template with operational detail.

### source-s03
**S03 — HerdR agent automation.** [Official automation documentation](https://herdr.dev/docs/agent-automation/). Public runtime/automation behavior; runtime state is not a semantic Worker acceptance result.

### source-s04
**S04 — HerdR socket API.** [Official API documentation](https://herdr.dev/docs/socket-api/). CLI/socket control surface; the selected authentication, identity, cancellation, and packaging topology still requires qualification.

### source-s05
**S05 — HerdR session state.** [Session-state documentation](https://herdr.dev/docs/session-state/). Relevant to restart/resume reconciliation; session restoration does not restore Factory workflow authority.

### source-s06
**S06 — HerdR agents.** [Agent documentation](https://herdr.dev/docs/agents). Relevant to admitted agent/harness support. A documented adapter is not automatically an admitted PriFly Route.

### source-s07
**S07 — Docker Engine security.** [Official security documentation](https://docs.docker.com/engine/security/). Supports the explicit limitation that Docker daemon access is powerful and is not a hostile-worker containment guarantee.

### source-s08
**S08 — Docker bind mounts.** [Official bind-mount documentation](https://docs.docker.com/engine/storage/bind-mounts/). Relevant to daemon-side filesystem paths in a separate Worker Docker deployment.

### source-s09
**S09 — Serena.** [Programming-language support](https://oraios.github.io/serena/01-about/020_programming-languages.html) and [tool documentation](https://oraios.github.io/serena/01-about/035_tools.html). Supports optional semantic navigation/editing subject to admitted language/backend/tool versions.

### Engineering standards and authoritative guidance

The editions below are the source baseline for this design, not a commitment to adopt every future update automatically. Public ISO/IEEE pages usually provide scope and status rather than all normative text. Where full text is unavailable, the candidate does not invent clause locators or claim clause-complete compliance. NASA guidance is official public guidance, not a mandate to apply all aerospace organizational processes unchanged to a personal project.

### source-s11
**S11 — ISO/IEC/IEEE 12207:2026, Software life cycle processes.** [Official ISO record](https://www.iso.org/standard/90219.html). Lifecycle framing and coverage; not a specific methodology or a substitute for artifact-level criteria.

### source-s12
**S12 — ISO/IEC/IEEE 29148:2018, Requirements engineering.** [Official ISO record](https://www.iso.org/standard/72089.html). Requirements engineering and information quality. A draft successor is not silently substituted for the pinned edition.

### source-s13
**S13 — NASA SWE-050, Software Requirements.** [Official handbook guidance](https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695421/SWE-050%2B-%2BSoftware%2BRequirements). Public operational support for well-formed, usable, traceable requirements and requirement sets.

### source-s14
**S14 — ISO/IEC 25010:2023, Product quality model.** [Official ISO record](https://www.iso.org/standard/78176.html). Quality dimensions used to drive contextual requirements and evaluation, not universal numeric thresholds.

### source-s15
**S15 — Quality in use and quality requirements.** [ISO/IEC 25019:2023](https://www.iso.org/standard/78177.html) and [ISO/IEC 25030:2019](https://www.iso.org/standard/72116.html). Context of use, quality expectations, and their definition/governance.

### source-s16
**S16 — ISO/IEC 25023:2016, Measurement of system and software product quality.** [Official ISO record](https://www.iso.org/standard/35747.html). Candidate measures; acceptable ranges are context-dependent rather than universally assigned by the standard.

### source-s17
**S17 — ISO/IEC 25040:2024, Quality evaluation framework.** [Official ISO record](https://www.iso.org/standard/83467.html). Supports a declared evaluation subject, criteria, methods, evidence, and conclusion.

### source-s18
**S18 — Project/software plan quality.** [ISO/IEC/IEEE 16326:2019](https://www.iso.org/standard/75276.html) and [NASA SWE-013, Software Plans](https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695397/SWE-013%2B-%2BSoftware%2BPlans). Plan content and the public complete/correct/workable/consistent/verifiable quality model.

### source-s19
**S19 — Architecture description.** [ISO/IEC/IEEE 42010:2022](https://www.iso.org/standard/74393.html) and [NASA SWE-057, Software Architecture](https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695442/SWE-057%2B-%2BSoftware%2BArchitecture). Stakeholders/concerns/views and operational architecture-content guidance.

### source-s20
**S20 — ISO/IEC/IEEE 42030:2019, Architecture evaluation framework.** [Official ISO record](https://www.iso.org/standard/73436.html). Evaluation of architecture against purpose, concerns, and evidence.

### source-s21
**S21 — ISO/IEC/IEEE 16085:2021, Risk management.** [Official ISO record](https://www.iso.org/standard/74371.html). Lifecycle risk information, assessment, treatment, and monitoring.

### source-s22
**S22 — Verification, validation, and test processes.** [IEEE 1012-2024](https://standards.ieee.org/ieee/1012/7324/) and [ISO/IEC/IEEE 29119-2:2021](https://www.iso.org/standard/79428.html). V&V and generic testing processes. This design does not infer a universal mandatory duplicate-test rule from these sources.

### source-s23
**S23 — NIST SP 800-218, SSDF Version 1.1.** [Final publication record](https://csrc.nist.gov/pubs/sp/800/218/final). Secure-development practices integrated into the selected lifecycle; tailoring and unfulfilled practices remain explicit.

### source-s24
**S24 — W3C PROV-DM.** [W3C Recommendation](https://www.w3.org/TR/prov-dm/). Entity/activity/agent and derivation provenance model; not a truth certification.

### source-s25
**S25 — GAO-20-195G, Cost Estimating and Assessment Guide.** [Official publication](https://www.gao.gov/products/gao-20-195g). Basis, assumptions, data, method, uncertainty, documentation, and actuals update practices for estimates, tailored to the estimate scope.

### source-s26
**S26 — Lifecycle and user information.** [ISO/IEC/IEEE 15289:2019](https://www.iso.org/standard/74909.html), [26514:2022](https://www.iso.org/standard/77451.html), and [26515:2018](https://www.iso.org/standard/70880.html). Information purpose/content and user-information development. Structured records can meet information needs without duplicating giant documents.

### source-s27
**S27 — NASA operational engineering guidance.** The following public handbook pages support the associated normalized profiles:

- [SWE-028 — Verification Planning](https://swehb.nasa.gov/spaces/7150/pages/16450576/SWE-028%2B-%2BVerification%2BPlanning).
- [SWE-029 — Validation Planning](https://swehb.nasa.gov/spaces/7150/pages/16449860/SWE-029%2B-%2BValidation%2BPlanning).
- [SWE-034 — Acceptance Criteria](https://swehb.nasa.gov/spaces/7150/pages/16450634/SWE-034%2B-%2BAcceptance%2BCriteria).
- [SWE-087 — Software Peer Reviews and Inspections](https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695472/SWE-087%2B-%2BSoftware%2BPeer%2BReviews%2Band%2BInspections%2Bfor%2BRequirements%2BPlans%2BDesign%2BCode%2Band%2BTest%2BProcedures).
- [SWE-061 — Coding Standards](https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695445/SWE-061%2B-%2BCoding%2BStandards).
- [SWE-053 — Manage Requirements Changes](https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695435/SWE-053%2B-%2BManage%2BRequirements%2BChanges).

These references support the method/criteria/evidence/change questions. They do not establish that every organizational NASA requirement is universally applicable to every PriFly Project.

### source-s28
**S28 — W3C WCAG 2.2.** [Recommendation](https://www.w3.org/TR/WCAG22/). Conditional web-content/UI accessibility requirements at a declared conformance level.

### source-s29
**S29 — OWASP ASVS 5.0.0.** [Official project](https://owasp.org/www-project-application-security-verification-standard/). Conditional application security verification using selected versioned requirement IDs.

### source-s30
**S30 — SLSA 1.2.** [Versioned specification](https://slsa.dev/spec/v1.2/). Conditional source/build supply-chain assurance with a selected track/level and evidence expectations.

### source-s31
**S31 — DORA software delivery metrics.** [Official guide](https://dora.dev/guides/dora-metrics/), consulted 14 September 2026. Diagnostic delivery performance measures; not a universal pass/fail product or employee score.

### Provider and persistence sources

### source-s32
**S32 — GitHub REST pull requests API.** [Official API reference](https://docs.github.com/en/rest/pulls/pulls). The merge request's `sha` parameter refers to the PR head, not an atomic expected base. Merge results and configured methods must be recorded honestly.

### source-s33
**S33 — GitHub protected branches.** [Official branch-protection documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches). PR requirements, status checks, freshness, and merge controls. Availability and behavior must be qualified for the actual repository/profile; no mandatory queue assumption.

### source-s34
**S34 — Litestream synchronization.** [Official sync reference](https://litestream.io/reference/sync/). Blocking sync and remote transaction-position reporting relevant to a pinned durability adapter. Command output/version details must be qualified rather than assumed permanent.

### source-s35
**S35 — Litestream restore.** [Official restore reference](https://litestream.io/reference/restore/). Restore positions, retained LTX boundaries, and retention/compaction limitations relevant to exact published-frontier lifetime.

### source-s36
**S36 — Cloudflare R2 consistency.** [Official consistency reference](https://developers.cloudflare.com/r2/reference/consistency/). Supports reasoning about storage observations; the precise conditional-write/CAS adapter still requires implementation tests.

### source-s37
**S37 — Cloudflare R2 pricing.** [Official pricing reference](https://developers.cloudflare.com/r2/pricing/). Storage, operation, and egress treatment. The product definition does not freeze price figures or claim the selected architecture has no operating cost.

### source-s38
**S38 — HerdR session organization and terminal control.** [Concepts](https://herdr.dev/docs/concepts/) and [CLI reference](https://herdr.dev/docs/cli-reference/), checked 15 September 2026. Support named sessions, workspaces/tabs/panes, explicit no-focus creation, and separate read-only observation versus writable control streams. Session-restoration behavior was also rechecked against [S05](#source-s05). The owner/Worker layout and PriFly viewer remain product requirements to implement and qualify.

### source-s39
**S39 — GitHub review events and approval eligibility.** [PR reviews API](https://docs.github.com/en/rest/pulls/reviews) and [approving a PR with required reviews](https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/approving-a-pull-request-with-required-reviews), checked 15 September 2026. Establish native review-event semantics and the restriction on author self-approval; a comment is not a native approval.

### source-s40
**S40 — GitHub planning representations.** [About milestones](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/about-milestones) and [About Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects), checked 15 September 2026. Establish repository-scoped milestones and configurable Project views. Mapping an Initiative to milestone(s) is the owner's PriFly product decision, not a GitHub-prescribed ontology.

### source-s41
**S41 — age encryption.** [Maintainer repository and README](https://github.com/FiloSottile/age), checked 15 September 2026. Supports the selected file-encryption format and tooling/library. PriFly's private-repository manifest, independent-key custody, startup validation, and rotation mechanics are the approved product design; implementation must qualify its pinned version.

### source-s42
**S42 — Mermaid sequence diagram syntax.** [Official sequence diagram reference](https://mermaid.js.org/syntax/sequenceDiagram.html), checked 15 September 2026. In message text, semicolons are syntax-sensitive and can be escaped as `#59;`; Candidate 2 instead uses punctuation that avoids that delimiter where practical. Parser/render tests and visual review are separate from merely checking Markdown fences.

### Source update and evidence discipline

An evaluator uses the pinned source version and normalized profile. When wording is materially ambiguous, it retrieves the official detail or admitted official guidance. If the detail is unavailable, it records the access/interpretation limit and criterion-unknown where necessary. A blog, model memory, or new draft cannot silently replace the source.

Changing a source version requires a reviewed mapping of criterion changes and impact on active baselines/evaluations. Historical evaluations keep the versions they used. Source registry maintenance must distinguish source identity verification, full-text access, normalization review, and implementation conformance—four different claims.

### Focused prompt and AI-code-trap research — Candidate 2.1

The following primary/maintainer sources were consulted on **16 September 2026** only for the prompt/context and attack-profile amendment. They do not change unrelated product decisions, activate new industry rubric criteria, or certify these prompts. Vendor observations and historical research are not universal defect-rate claims about all current models.

### source-s43
**S43 — Anthropic, Prompting best practices.** [Official guide](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices), especially “Overeagerness,” “Avoid focusing on passing tests and hardcoding,” and “Minimizing hallucinations in agentic coding.” Describes model-specific overengineering and test-fitting tendencies. PriFly adapts the risk, not a blanket prohibition on useful abstraction or required defensive checks.

### source-s44
**S44 — Anthropic, Skill authoring best practices.** [Official guide](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices), especially progressive disclosure, shallow reference structure, tool naming/environment requirements, and evaluation-driven iteration. Supports explicit dependencies and clean-context evaluation; executable bindings remain PriFly admission requirements.

### source-s45
**S45 — Anthropic, Effective context engineering for AI agents.** [Engineering article](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents), published 29 September 2025. Supports selected high-signal context, well-defined tools, and just-in-time retrieval rather than a monolithic manual. PriFly retains deterministic job/authority selection.

### source-s46
**S46 — OpenAI, Prompt engineering.** [Official guide](https://developers.openai.com/api/docs/guides/prompt-engineering). Supports explicit instructions, relevant context, examples, version-aware prompting and evaluations. Does not establish a universal best prompt or eliminate runtime checks.

### source-s47
**S47 — OpenAI, Harness engineering: leveraging Codex in an agent-first world.** [Engineering report](https://openai.com/index/harness-engineering/), published 11 February 2026. Reports structured navigable context and drift from copied repository patterns in one engineering setting. PriFly does not import its autonomous merge or recurring cleanup workflow.

### source-s48
**S48 — Agent Skills specification.** [Maintainer specification](https://agentskills.io/specification). Describes skill metadata, body/resources, compatibility and progressive disclosure; tool-allowlist support depends on the host. PriFly requires actual runtime bindings and authority enforcement independently of metadata.

### source-s49
**S49 — Google Engineering Practices, What to look for in a code review.** [Official guidance](https://google.github.io/eng-practices/review/reviewer/looking-for.html), especially complexity, tests, comments, style, and context. Supports review of unjustified generality while distinguishing personal preference from a blocking issue. General engineering guidance, not an AI-only defect taxonomy.

### source-s50
**S50 — Spracklen et al., We Have a Package for You!** [USENIX Security 2025 publication](https://www.usenix.org/conference/usenixsecurity25/presentation/spracklen). Empirical investigation of hallucinated package recommendations and their supply-chain implications. Its reported rates are specific to its models/tasks; PriFly adopts package/API verification rather than extrapolating those rates to current Routes.

### source-s51
**S51 — Zhang et al., LLM Hallucinations in Practical Code Generation.** [Research paper, arXiv:2409.20550v1](https://arxiv.org/html/2409.20550v1), published 30 September 2024. Repository-level study distinguishes conflicts with requirements, factual/library/API knowledge, and project context. Supports concrete context/contract probes; it is not evidence that every generated patch or modern model has the same failure distribution.

### source-s52
**S52 — Anthropic, Best practices for Claude Code.** [Official guide](https://code.claude.com/docs/en/best-practices), especially runnable verification, specific context, and self-contained task specifications. PriFly retains its own phase gates, independent review, evidence reuse, and dispatch boundaries rather than copying an entire vendor workflow.
