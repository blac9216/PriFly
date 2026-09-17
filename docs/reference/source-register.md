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

### Dependency inventory, update policy and dispositions

This is the committed dependency inventory, update policy and license/vulnerability disposition
record for the Go module at the repository root. It carries the A06 outcome "dependency inventory
and update policy identify modernc/Litestream candidates without claiming qualification"
([#57](https://github.com/blac9216/PriFly/issues/57)) and V13's "Exact dependency
list/license/vulnerability dispositions and no mutable tools/containers"
([D3 verification](https://github.com/blac9216/PriFly/issues/38#issuecomment-5701521439)).
The pins themselves live in `go.mod` and `.github/workflows/`; this section records how exactly
those pins are dispositioned and is valid only for the identities it names. Facts were read on
16 September 2026 against source commit `d94090a8991ec0570df9d5bc412a096cc4cbc7f5`. A license
identifier is the cited official source's classification, not legal advice. A fact that was not
verified is `UNKNOWN`.

### source-s53
**S53 — Go toolchain go1.27.1.** [Official release index](https://go.dev/dl/?mode=json&include=all), [linux/amd64 archive](https://go.dev/dl/go1.27.1.linux-amd64.tar.gz), [license classification for `std@go1.27.1`](https://pkg.go.dev/std@go1.27.1?tab=licenses), [license at the tag](https://go.googlesource.com/go/+/refs/tags/go1.27.1/LICENSE) and [BoringCrypto license at the tag](https://go.googlesource.com/go/+/refs/tags/go1.27.1/src/crypto/internal/boring/LICENSE), read 16 September 2026. Supplies the toolchain version, the go.dev archive digest and the licenses below. The index is a rolling page. The recorded digest identifies only the go.dev linux/amd64 archive, the one the local Go-suite recipe in [testing.md](../process/testing.md) downloads; that recipe checks the download against a live read of the index, not against this record. The digest does not identify the archive CI installs ([S58](#source-s58)).

### source-s54
**S54 — govulncheck and the Go vulnerability database.** [`golang.org/x/vuln` v1.8.0](https://pkg.go.dev/golang.org/x/vuln@v1.8.0), its [license classification](https://pkg.go.dev/golang.org/x/vuln@v1.8.0?tab=licenses) and [checksum-database record](https://sum.golang.org/lookup/golang.org/x/vuln@v1.8.0), and the [database module index](https://vuln.go.dev/index/modules.json), read 16 September 2026. A clean result is bounded by the database's modification time and govulncheck's source-mode reachability analysis. It is not proof that no vulnerability exists.

### source-s55
**S55 — `modernc.org/sqlite` v1.59.0.** [Package documentation](https://pkg.go.dev/modernc.org/sqlite@v1.59.0), [license classification](https://pkg.go.dev/modernc.org/sqlite@v1.59.0?tab=licenses) and [module proxy record](https://proxy.golang.org/modernc.org/sqlite/@v/v1.59.0.info), read 16 September 2026. Candidate identity and license only; not qualification evidence.

### source-s56
**S56 — Litestream v0.5.17.** [Official release](https://github.com/benbjohnson/litestream/releases/tag/v0.5.17) and [license at the tag](https://github.com/benbjohnson/litestream/blob/v0.5.17/LICENSE), classified by the GitHub license API at ref `v0.5.17`, read 16 September 2026. Candidate identity and license only. [S34](#source-s34) and [S35](#source-s35) describe its behavior; neither source is qualification evidence.

### source-s57
**S57 — Pinned GitHub Actions.** [`actions/checkout` license](https://github.com/actions/checkout/blob/3d3c42e5aac5ba805825da76410c181273ba90b1/LICENSE) and [`actions/setup-go` license](https://github.com/actions/setup-go/blob/b7ad1dad31e06c5925ef5d2fc7ad053ef454303e/LICENSE) at the commits `.github/workflows/` pins, classified by the GitHub license API at those refs, read 16 September 2026.

### source-s58
**S58 — CI Go toolchain archive.** [`actions/setup-go` installer at the pinned commit](https://github.com/actions/setup-go/blob/b7ad1dad31e06c5925ef5d2fc7ad053ef454303e/src/installer.ts), [`versions-manifest.json` at `actions/go-versions` commit `98ce2ae5799f67db39142219d880a369fc6a4891`](https://github.com/actions/go-versions/blob/98ce2ae5799f67db39142219d880a369fc6a4891/versions-manifest.json), [release `1.27.1-33583469715`](https://github.com/actions/go-versions/releases/tag/1.27.1-33583469715) with its [release API record](https://api.github.com/repos/actions/go-versions/releases/tags/1.27.1-33583469715), and the `go` job log of [go-checks run 35162949684](https://github.com/blac9216/PriFly/actions/runs/35162949684), read 16 September 2026. At that commit the installer first looks in the runner's tool cache. On a miss it reads `versions-manifest.json` from the `main` branch of `actions/go-versions`, downloads the listed asset and computes no digest of it. If that path fails or the manifest lists no match, it falls back to downloading the go.dev archive, again without a digest check. Its only SHA-256 use names a cache directory for a custom download URL. The run's log reads "Acquiring 1.27.1 from https://github.com/actions/go-versions/releases/download/1.27.1-33583469715/go-1.27.1-linux-x64.tar.gz". The manifest entry lists `filename`, `arch`, `platform` and `download_url` and publishes no digest. The release API record publishes a `digest` for the asset.

### Current dependency inventory

| Component | Exact identity | Pinned by | License | Vulnerability disposition |
|---|---|---|---|---|
| Go toolchain and standard library — local Go suite | `go1.27.1`; `go1.27.1.linux-amd64.tar.gz` from go.dev, SHA-256 `63d339f0da5ab53635a56f2490a7984dfe12dfcff22ad749f63edaf590168445` ([S53](#source-s53)), checked locally with `sha256sum -c` on the read date. Other platform archives' digests: `UNKNOWN`, not recorded. | Version: `go` directive in `go.mod`; `GOTOOLCHAIN=local`. Archive: this digest is recorded here only; the [testing.md](../process/testing.md) recipe checks a download against a live read of the go.dev index, not against this record. | BSD-3-Clause ([S53](#source-s53)); BoringCrypto note below | No known vulnerability found; see below |
| Go toolchain — CI (`go-checks.yml`) | `go1.27.1`; `go-1.27.1-linux-x64.tar.gz`, the `actions/go-versions` release asset at `https://github.com/actions/go-versions/releases/download/1.27.1-33583469715/go-1.27.1-linux-x64.tar.gz`, SHA-256 `6f00fbc5b337fbf00581b7ced382fecdc4fa9493aef971277652a25f7aa14c6e`. That digest was computed locally from a download on the read date and equals the release API's published `sha256:` digest; `versions-manifest.json` publishes none ([S58](#source-s58)). It is a different archive from the go.dev one. In a one-time local comparison, every regular file of the go.dev archive's `go/` tree was present with the same SHA-256, plus one extra file, `setup.sh`; modes, symlinks and directories were not compared. | Version only: `setup-go` reads `go-version-file: go.mod` and resolves it through the mutable `main` branch of `versions-manifest.json`, falls back to an unchecked go.dev download when that fails or the manifest lists no match, or uses a runner tool-cache hit, whose identity is `UNKNOWN`. **Not verified in CI**: no CI step checks the archive digest ([#170](https://github.com/blac9216/PriFly/issues/170)). | `UNKNOWN` for the repackaged archive; its go.dev files are those classified in the row above | Same go1.27.1 version as the row above; the archive itself has no separate disposition |
| Third-party Go modules | None. `go list -m all` lists only `github.com/blac9216/PriFly`; `go.mod` has no `require` and no `go.sum` exists. | `go.mod`; `GOFLAGS=-mod=readonly` | Not applicable | Not applicable |
| `actions/checkout`, `actions/setup-go` (CI only; not in the build output) | Full commit SHAs on the `uses:` lines of `.github/workflows/` | Those `uses:` lines | MIT ([S57](#source-s57)) | `UNKNOWN`; govulncheck does not scan Actions and no other disposition is recorded |

BoringCrypto note: pkg.go.dev classifies `src/crypto/internal/boring/LICENSE` in go1.27.1 as
BSD-3-Clause, ISC, OpenSSL. That file says "When building with GOEXPERIMENT=boringcrypto, the
following applies." No committed build or workflow sets `GOEXPERIMENT`.

Outside this inventory: host and CI tools that are not in the module's build closure — the
mutable `ubuntu-latest` runner image (its disposition is the header comment of
`.github/workflows/go-checks.yml`), and `gitleaks`, Python 3 and Bash used by the documentation
checks. Their inventory and dispositions are `UNKNOWN` here
([#165](https://github.com/blac9216/PriFly/issues/165)). The govulncheck tool is identified below.

CI toolchain gap: CI installs its toolchain by Go version, not by a pinned archive identity. V13's
"no mutable tools/containers" is therefore not met for that archive. The CI toolchain row above
records the archive's identity as read, marks it not verified in CI, and routes the fix to
[#170](https://github.com/blac9216/PriFly/issues/170).

### Vulnerability disposition

`go run golang.org/x/vuln/cmd/govulncheck@v1.8.0 -show verbose ./...` from the repository root
with go1.27.1, `GOTOOLCHAIN=local` and `GOFLAGS=-mod=readonly` scanned 4 root packages in 1 module
(`github.com/blac9216/PriFly`) and the go1.27.1 standard library against `https://vuln.go.dev`
(database updated 2026-09-15 18:39:25 UTC). Result: "No vulnerabilities found.", exit 0. Tool
identity: `golang.org/x/vuln` v1.8.0, module hash `h1:clG4qBU6zH5VKjti8n5j8BBuYzoSha392xXMkXS351U=`,
`go.mod` hash `h1:Fzm4XK3Hbl1ZvZ7JpNTEWb7CJWOZ7m2LX0GLu4Fsrwo=`, matching its checksum-database
record; BSD-3-Clause ([S54](#source-s54)).

Source-mode govulncheck does not report vulnerabilities in the `go` command itself. In the same
database index, no `stdlib` or `toolchain` entry lacks a fixed version or names a fixed version
later than go1.27.1 ([S54](#source-s54)). Disposition: no known vulnerability is outstanding or
accepted for the current subject. The result is point-in-time and does not carry over to a
changed `go.mod`, toolchain or database.

### Candidate dependencies — not qualified

| Candidate | Version named by D3 | License | Status |
|---|---|---|---|
| `modernc.org/sqlite` (SQLite driver through `database/sql`) | v1.59.0 — P4: "`modernc.org/sqlite` candidate v1.59.0 (observed package documentation)" | BSD-3-Clause ([S55](#source-s55)) | candidate — not qualified. Not in `go.mod`. |
| Litestream (separate replication daemon) | v0.5.17 — C3: "daemon Litestream v0.5.17 is separate"; source commit `ccd326c175b583b5e82893a6078f06dcef5fba3f` per the [#40 research](https://github.com/blac9216/PriFly/issues/40#issuecomment-5699701092) | Apache-2.0 ([S56](#source-s56)) | candidate — not qualified. Not installed, built or run by this repository. |

Versions come from [D3 contracts](https://github.com/blac9216/PriFly/issues/38#issuecomment-5701520946)
C3 and [profile](https://github.com/blac9216/PriFly/issues/38#issuecomment-5701521177) P4. Nothing
here admits either candidate. P4 fixes the path to admission: "Pin transitive SQLite/Go module
versions and hashes after compatibility build" and "V03/V10/V12 are admission evidence".
Qualification is owned by Q02 ([#110](https://github.com/blac9216/PriFly/issues/110), V03/V10/V12)
and Q13 ([#121](https://github.com/blac9216/PriFly/issues/121), V03/V12). Q02 is a planned
qualification item, not one of the live gates [validation.md](../process/validation.md) names.
Its live run is governed by its own issue body: "Live-run/admission predicates (separate from PR
authoring): Q01:authorized-full-environment", with its verified expectation `pending-live`. Q13 is
one of the two live gates validation.md names. Release SBOM and license/vulnerability dispositions
belong to U04 ([#105](https://github.com/blac9216/PriFly/issues/105)).

`UNKNOWN` for both candidates: the transitive module closure with its versions, hashes and
licenses; the SQLite library version the driver embeds; Litestream release binary digests; and a
vulnerability disposition. The database index lists no entry under either module path
(`modernc.org/sqlite`, `github.com/benbjohnson/litestream`) at the read date, which is not a
disposition of either closure.

### Dependency update policy

This policy restates the governing rules; it adds no threshold.

1. **Exact pins only.** V13 requires "no mutable tools/containers"; C3 puts "Qualified exact
   versions and binary hashes" in the release profile with "no mutable `latest` images"; the
   "Evidence inventory and limits" section of the D3 profile record, outside the P4 row
   ([profile comment](https://github.com/blac9216/PriFly/issues/38#issuecomment-5701521177)), says
   "Rolling pages must not replace pinned release manifests automatically". `GOTOOLCHAIN=local`
   and `GOFLAGS=-mod=readonly` keep a build from switching toolchains or rewriting
   `go.mod`/`go.sum`. Current exception: CI's toolchain archive is pinned by version only (the CI
   toolchain row above, [#170](https://github.com/blac9216/PriFly/issues/170)).
2. **No silent in-attempt update.** V13: "required maintenance gets a new manifest and smoke
   qualification rather than silent in-attempt update". The DP4
   [operating contract](https://github.com/blac9216/PriFly/issues/38#issuecomment-5702104540):
   "Later profile changes require new manifests, impact review and relevant requalification;
   maintain SBOM/license/vulnerability dispositions (A06/U04/U07)".
3. **One reviewed change per dependency change.** Adding, removing or re-versioning a module, the
   toolchain or an Action pin updates the pin, this inventory, the license row and a fresh
   govulncheck disposition for the new subject in the same pull request, with the requalification
   its governing profile names. P4: "Changes to driver/replica/PRAGMAs/SDK require requalification".
   `go.mod`/`go.sum` edits serialize ([maintenance.md](../process/maintenance.md)).
4. **Admitting a candidate is not an update.** Adding `modernc.org/sqlite` or Litestream follows the
   P4 admission path above, not this list alone.
5. **Not chosen here.** D3 and DP4 set no update cadence, vulnerability severity threshold or
   license allow-list for this subject; each is `UNKNOWN` until an owner or planning decision sets
   it. DP4 assigns "root-cause/related-instance search, remediation verification and
   recurrence-prevention evidence" for security maintenance to I05/U07.
