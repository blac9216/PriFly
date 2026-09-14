# Engineering standards registry

Kind: reference

This registry pins the external standards and authoritative engineering guidance PriFly uses to derive general quality rubrics. It does **not** define project-specific requirements/design conformance and it does **not** define PriFly workflow mechanics.

The normalized rubrics live in [Quality rubrics](quality-rubrics.md). When an evaluator needs more detail or finds an ambiguity, it should consult the exact official source/version recorded here rather than inventing criteria from model memory or substituting an unofficial summary.

## Registry rules

- Use the exact edition/version recorded here for normative evaluation until a governed update changes the registry.
- Drafts do not silently replace published standards.
- Official implementation guidance may operationalize a standard, but does not override the pinned standard.
- Paid/copyrighted standards are referenced, not reproduced. PriFly stores normalized criteria and source locators rather than copying protected text.
- If an official source is inaccessible and the normalized criterion is insufficient to resolve an ambiguity, the evaluation remains `UNKNOWN`.
- A source update is not automatically adopted merely because a newer edition exists.
- `Last verified` means the source identity/status was checked; it is not a claim that PriFly owns or redistributes the source text.

## Core lifecycle and engineering sources

| Source ID | Authority | Pinned source | Status / role | Primary PriFly use | Official source | Last verified |
|---|---|---|---|---|---|---|
| `STD-12207-2026` | ISO/IEC/IEEE | ISO/IEC/IEEE 12207:2026 — Software life cycle processes | Published international standard; lifecycle backbone | lifecycle/process framing; stage coverage; support/maintenance/retirement context | https://www.iso.org/standard/90219.html | 2026-09-14 |
| `STD-29148-2018` | ISO/IEC/IEEE | ISO/IEC/IEEE 29148:2018 — Requirements engineering | Published; confirmed current by ISO in 2024 | stakeholder/technical requirements quality and traceability | https://www.iso.org/standard/72089.html | 2026-09-14 |
| `GUIDE-NASA-SWE050` | NASA | SWE-050 — Software Requirements | Official public engineering guidance | operational requirement-quality checks supporting 29148 normalization | https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695421/SWE-050+-+Software+Requirements | 2026-09-14 |
| `STD-25019-2023` | ISO/IEC | ISO/IEC 25019:2023 — Quality-in-use model | Published | context-of-use and quality-in-use needs/acceptance | https://www.iso.org/standard/78177.html | 2026-09-14 |
| `STD-25030-2019` | ISO/IEC | ISO/IEC 25030:2019 — Quality requirements framework | Published; confirmed current by ISO in 2025 | eliciting/defining/governing quality requirements and targets | https://www.iso.org/standard/72116.html | 2026-09-14 |
| `STD-25010-2023` | ISO/IEC | ISO/IEC 25010:2023 — Product quality model | Published | product-quality characteristics; design/test/acceptance objectives | https://www.iso.org/standard/78176.html | 2026-09-14 |
| `STD-25023-2016` | ISO/IEC | ISO/IEC 25023:2016 — Measurement of system and software product quality | Published; confirmed current by ISO in 2022 | candidate quantitative measures supporting 25010 quality requirements | https://www.iso.org/standard/35747.html | 2026-09-14 |
| `STD-25040-2024` | ISO/IEC | ISO/IEC 25040:2024 — Quality evaluation framework | Published | product-quality evaluation process and evidence | https://www.iso.org/standard/83467.html | 2026-09-14 |
| `STD-16326-2019` | ISO/IEC/IEEE | ISO/IEC/IEEE 16326:2019 — Project management | Published | project/delivery-plan content and management quality | https://www.iso.org/standard/75276.html | 2026-09-14 |
| `GUIDE-NASA-SWE013` | NASA | SWE-013 — Software Plans | Official public engineering guidance | operational plan-quality qualities: complete/correct/workable/consistent/verifiable | https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695397/SWE-013+-+Software+Plans | 2026-09-14 |
| `STD-42010-2022` | ISO/IEC/IEEE | ISO/IEC/IEEE 42010:2022 — Architecture description | Published | architecture-description structure, stakeholders, concerns, viewpoints/models | https://www.iso.org/standard/74393.html | 2026-09-14 |
| `STD-42030-2019` | ISO/IEC/IEEE | ISO/IEC/IEEE 42030:2019 — Architecture evaluation framework | Published; confirmed current by ISO in 2025 | architecture evaluation against concerns/intended purpose | https://www.iso.org/standard/73436.html | 2026-09-14 |
| `GUIDE-NASA-SWE057` | NASA | SWE-057 — Software Architecture | Official public engineering guidance | operational architecture-content and traceability checks | https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695442/SWE-057+-+Software+Architecture | 2026-09-14 |
| `STD-16085-2021` | ISO/IEC/IEEE | ISO/IEC/IEEE 16085:2021 — Risk management | Published | software/system lifecycle risk information and treatment quality | https://www.iso.org/standard/74371.html | 2026-09-14 |
| `STD-1012-2024` | IEEE | IEEE 1012-2024 — System, Software, and Hardware Verification and Validation | Active IEEE standard | V&V planning, integrity/risk-scaled independence, verification vs validation | https://standards.ieee.org/ieee/1012/7324/ | 2026-09-14 |
| `STD-29119-2-2021` | ISO/IEC/IEEE | ISO/IEC/IEEE 29119-2:2021 — Software testing — Test processes | Published | generic test governance/management/implementation process | https://www.iso.org/standard/79428.html | 2026-09-14 |
| `GUIDE-NASA-SWE028` | NASA | SWE-028 — Verification Planning | Official public engineering guidance | operational verification method/environment/criteria checks | https://swehb.nasa.gov/spaces/7150/pages/16450576/SWE-028+-+Verification+Planning | 2026-09-14 |
| `GUIDE-NASA-SWE029` | NASA | SWE-029 — Validation Planning | Official public engineering guidance | intended-use/intended-environment validation checks | https://swehb.nasa.gov/pages/viewpage.action?pageId=23429440 | 2026-09-14 |
| `GUIDE-NASA-SWE034` | NASA | SWE-034 — Acceptance Criteria | Official public engineering guidance | measurable predeclared acceptance criteria and acceptance evidence | https://swehb.nasa.gov/spaces/7150/pages/16450634/SWE-034+-+Acceptance+Criteria | 2026-09-14 |
| `GUIDE-NASA-SWE087` | NASA | SWE-087 — Software Peer Reviews and Inspections | Official public engineering guidance | review readiness/completion, artifact checklists, finding/action tracking | https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695472/SWE-087+-+Software+Peer+Reviews+and+Inspections+for+Requirements+Plans+Design+Code+and+Test+Procedures | 2026-09-14 |
| `GUIDE-NASA-SWE061` | NASA | SWE-061 — Coding Standards | Official public engineering guidance | selection/definition/adherence to language/project coding standards | https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695445/SWE-061+-+Coding+Standards | 2026-09-14 |
| `STD-SSDF-1.1` | NIST | NIST SP 800-218, Secure Software Development Framework (SSDF) Version 1.1 | Final NIST publication | secure software-development quality overlay across the lifecycle | https://csrc.nist.gov/pubs/sp/800/218/final | 2026-09-14 |
| `STD-PROV-DM` | W3C | PROV-DM — The PROV Data Model | W3C Recommendation family specification | evidence/research provenance: entities, activities, agents, derivation/responsibility | https://www.w3.org/TR/prov-dm/Overview.html | 2026-09-14 |
| `GUIDE-NASA-SWE053` | NASA | SWE-053 — Manage Requirements Changes | Official public engineering guidance | structured change request and impact-analysis quality | https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695435/SWE-053+-+Manage+Requirements+Changes | 2026-09-14 |
| `STD-15289-2019` | ISO/IEC/IEEE | ISO/IEC/IEEE 15289:2019 — Content of life-cycle information items | Published; confirmed current by ISO in 2025 | lifecycle information/documentation purpose/content quality | https://www.iso.org/standard/74909.html | 2026-09-14 |
| `STD-26514-2022` | ISO/IEC/IEEE | ISO/IEC/IEEE 26514:2022 — Design and development of information for users | Published | user-information needs, structure, content, format and lifecycle | https://www.iso.org/standard/77451.html | 2026-09-14 |
| `STD-26515-2018` | ISO/IEC/IEEE | ISO/IEC/IEEE 26515:2018 — Developing information for users in an agile environment | Published; confirmed current by ISO in 2024 | user-information process in iterative/agile delivery | https://www.iso.org/standard/70880.html | 2026-09-14 |
| `GUIDE-GAO-20-195G` | U.S. GAO | GAO-20-195G — Cost Estimating and Assessment Guide | Public government best-practice guide | estimate basis, assumptions, methods, sensitivity/risk, documentation/update quality | https://www.gao.gov/products/gao-20-195g | 2026-09-14 |

## Conditional quality/security overlays

These sources are not automatically applicable to every Project. Planning policy activates an exact version/target when project context makes the profile relevant.

| Source ID | Authority | Pinned source | Applicability | Official source | Last verified |
|---|---|---|---|---|---|
| `STD-WCAG-2.2` | W3C | Web Content Accessibility Guidelines (WCAG) 2.2 | user-facing web content/UI; exact conformance level must be declared by project/policy before blocking use | https://www.w3.org/TR/WCAG22/ | 2026-09-14 |
| `STD-ASVS-5.0.0` | OWASP | OWASP Application Security Verification Standard 5.0.0 | web applications/APIs; exact versioned requirement identifiers/profile must be selected before evaluation | https://owasp.org/www-project-application-security-verification-standard/ | 2026-09-14 |
| `STD-SLSA-1.2` | SLSA community specification | SLSA v1.2 | projects that build/distribute artifacts and adopt supply-chain assurance targets | https://slsa.dev/spec/v1.2/ | 2026-09-14 |

## Diagnostic sources — not acceptance rubrics

| Source ID | Authority | Pinned source | Use | Official source | Last verified |
|---|---|---|---|---|---|
| `DIAG-DORA-2026` | DORA | DORA software delivery performance metrics, current five-metric model | historical delivery/learning diagnostics only; not universal pass/fail thresholds | https://dora.dev/guides/dora-metrics/ | 2026-09-14 |

DORA currently measures delivery throughput and instability using change lead time, deployment frequency, failed-deployment recovery time, change fail rate, and deployment rework rate. PriFly may use those observations for trend/experiment analysis, but the registry does not convert them into universal gate thresholds.

## Sources deliberately not treated as normative quality standards

- **INVEST** may remain useful decomposition vocabulary, but it is not adopted as a normative industry-standard rubric.
- **Walking skeleton / vertical slice** remain PriFly delivery-policy concepts, not external quality standards.
- **Draft standards** do not replace pinned published versions. For example, a draft successor to ISO/IEC/IEEE 29148:2018 or NIST SSDF 1.1 requires an explicit registry update before use.
- Blogs, vendor summaries, model memory, forum posts, and search snippets may help locate an authoritative source but cannot override a pinned criterion.

## Standards update procedure

A standards update is a governed change when it can alter a blocking rubric.

At minimum the change must record:

1. old and proposed source identity/version;
2. official evidence that the proposed version is published/current;
3. rubric criteria materially added/removed/changed;
4. compatibility effect on active Planning Baselines and in-flight evaluations;
5. whether old rubric versions remain interpretable for historical decisions;
6. independent review of the normalized mapping before it becomes effective.

Historical Rubric Evaluations remain bound to the source/rubric version used at evaluation time; a registry update does not rewrite history.
