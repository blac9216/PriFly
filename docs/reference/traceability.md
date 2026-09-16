# Requirement and source traceability

Kind: reference

The design decomposes the [Accepted PriFly PRD v2.1](product-requirements.md), accepted by the
owner on 16 September 2026. The PRD governs product requirements; each linked document is its
focused decomposition home, not a separate source of product authority. Review material remains
outside the repository. [Design governance](design-governance.md) defines change control.

The supplied pre-acceptance file was `PriFly-PRD-Candidate-v2.1.md`, SHA-256
`e14d47b25992df100003ddd697627c08bd9343c74bd984a6e744ceb7ef680490`.
Its complete content is now maintained in the accepted PRD, with acceptance metadata, current
baseline framing and canonical navigation replacing candidate-only packaging. The hash identifies
the original input, not the edited accepted file. **Source line** values below refer to that original
input; stable section/requirement/figure IDs navigate the accepted baseline after line shifts.
Requirement, criterion, role/job and diagram identities are retained.

## Source sections

| PRD section | Canonical home |
|---|---|
| 1 | [docs/explanation/product.md](../explanation/product.md#product-summary-and-problem-statement) |
| 2 | [docs/explanation/product.md](../explanation/product.md#users-scope-and-bounding-principles) |
| 3 | [docs/explanation/architecture.md](../explanation/architecture.md#architecture) |
| 4 | [docs/explanation/product-lifecycle.md](../explanation/product-lifecycle.md#user-stories-and-a-worked-journey) |
| 5 | [docs/explanation/architecture.md](../explanation/architecture.md#technology-choices) |
| 6 | [docs/reference/worker-roles.md](worker-roles.md#worker-role-catalog-and-responsibility-routing) |
| 7 | [Domain model](../explanation/domain-model.md#domain-objects-identities-and-explicit-states); [states and uncertainty](state-machines.md) |
| 8 | [docs/explanation/pilot.md](../explanation/pilot.md#pilot-cli-startup-and-owner-attention) |
| 9 | [docs/explanation/planning.md](../explanation/planning.md#idea-refinement-research-architecture-and-design-completeness) |
| 10 | [docs/explanation/engineering-quality.md](../explanation/engineering-quality.md#engineering-quality-standards-and-mechanical-application) |
| 11 | [docs/explanation/delivery-planning.md](../explanation/delivery-planning.md#decomposition-estimation-and-delivery-readiness) |
| 12 | [docs/explanation/routing-and-capacity.md](../explanation/routing-and-capacity.md#scheduling-routing-capacity-and-bounded-autonomy) |
| 13 | [Execution runtime](../explanation/execution-runtime.md#herdr-workspaces-and-worker-runtime); [context and code intelligence](../explanation/context-and-code-intelligence.md) |
| 14 | [docs/explanation/execution.md](../explanation/execution.md#implementation-and-reusable-verification-evidence) |
| 15 | [Independent review](../explanation/review.md#independent-review-and-the-current-correction-path); [attack profiles](attack-profiles.md) |
| 16 | [docs/explanation/findings-and-triage.md](../explanation/findings-and-triage.md#findings-semantic-triage-backlog-control-and-batching) |
| 17 | [docs/explanation/git-integration.md](../explanation/git-integration.md#git-branches-pull-requests-rebasing-and-merge) |
| 18 | [docs/explanation/validation.md](../explanation/validation.md#product-validation-and-pending-target-scheduling) |
| 19 | [docs/explanation/change-control.md](../explanation/change-control.md#change-control-arbitration-and-the-blocking-chain) |
| 20 | [docs/explanation/release-and-closeout.md](../explanation/release-and-closeout.md#release-closeout-and-completion-of-the-product-journey) |
| 21 | [Application API](api-contract.md#application-api-canonical-records-and-deterministic-presentation); [canonical record contracts](schemas.md) |
| 22 | [docs/explanation/providers.md](../explanation/providers.md#provider-broker-projections-reconciliation-and-rate-limits) |
| 23 | [docs/explanation/persistence-and-durability.md](../explanation/persistence-and-durability.md#canonical-persistence-published-durability-and-retention) |
| 24 | [docs/explanation/recovery.md](../explanation/recovery.md#bootstrap-host-loss-recovery-and-operational-repair) |
| 25 | [docs/explanation/upgrades.md](../explanation/upgrades.md#factory-upgrades-and-database-migrations) |
| 26 | [docs/explanation/experiments-and-metrics.md](../explanation/experiments-and-metrics.md#metrics-experiments-and-institutional-learning) |
| 27 | [docs/explanation/security.md](../explanation/security.md#security-privacy-resource-safety-and-data-retention) |
| 28 | [docs/explanation/operator-experience.md](../explanation/operator-experience.md#operator-experience-documentation-and-evolution) |
| 29 | [docs/reference/product-acceptance.md](product-acceptance.md#nonfunctional-requirements-and-product-acceptance) |
| 30 | [docs/explanation/roadmap.md](../explanation/roadmap.md#delivery-strategy-and-release-progression) |
| 31 | [Unselected parameters](deployment-parameters.md#unselected-parameters-and-admission-dependencies); [risks and assumptions](../explanation/risks-and-assumptions.md) |
| 32 | [docs/reference/design-governance.md](design-governance.md#design-review-approval-and-change-governance) |

## Requirement families

| ID | Owning definition | Source line |
|---|---|---|
| BP-01 | [product](../explanation/product.md#bounding-principles) | 143 |
| BP-02 | [product](../explanation/product.md#bounding-principles) | 144 |
| BP-03 | [product](../explanation/product.md#bounding-principles) | 145 |
| BP-04 | [product](../explanation/product.md#bounding-principles) | 146 |
| BP-05 | [product](../explanation/product.md#bounding-principles) | 147 |
| BP-06 | [product](../explanation/product.md#bounding-principles) | 148 |
| BP-07 | [product](../explanation/product.md#bounding-principles) | 149 |
| BP-08 | [product](../explanation/product.md#bounding-principles) | 150 |
| BP-09 | [product](../explanation/product.md#bounding-principles) | 151 |
| BP-10 | [product](../explanation/product.md#bounding-principles) | 152 |
| BP-11 | [product](../explanation/product.md#bounding-principles) | 153 |
| BP-12 | [product](../explanation/product.md#bounding-principles) | 154 |
| BP-13 | [product](../explanation/product.md#bounding-principles) | 155 |
| BP-14 | [product](../explanation/product.md#bounding-principles) | 156 |
| BP-15 | [product](../explanation/product.md#bounding-principles) | 157 |
| BP-16 | [product](../explanation/product.md#bounding-principles) | 158 |
| BP-17 | [product](../explanation/product.md#bounding-principles) | 159 |
| BP-18 | [product](../explanation/product.md#bounding-principles) | 160 |
| BP-19 | [product](../explanation/product.md#bounding-principles) | 161 |
| BP-20 | [product](../explanation/product.md#bounding-principles) | 162 |
| US-01 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 252 |
| US-02 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 253 |
| US-03 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 254 |
| US-04 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 255 |
| US-05 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 256 |
| US-06 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 257 |
| US-07 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 258 |
| US-08 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 259 |
| US-09 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 260 |
| US-10 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 261 |
| US-11 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 262 |
| US-12 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 263 |
| US-13 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 264 |
| US-14 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 265 |
| US-15 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 266 |
| US-16 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 267 |
| US-17 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 268 |
| US-18 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 269 |
| US-19 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 270 |
| US-20 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 271 |
| US-21 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 272 |
| US-22 | [product-lifecycle](../explanation/product-lifecycle.md#core-user-stories) | 273 |
| PF-INT-01 | [pilot](../explanation/pilot.md#required-interface-behavior) | 688 |
| PF-INT-02 | [pilot](../explanation/pilot.md#required-interface-behavior) | 689 |
| PF-INT-03 | [pilot](../explanation/pilot.md#required-interface-behavior) | 690 |
| PF-INT-04 | [pilot](../explanation/pilot.md#required-interface-behavior) | 691 |
| PF-INT-05 | [pilot](../explanation/pilot.md#required-interface-behavior) | 692 |
| PF-INT-06 | [pilot](../explanation/pilot.md#required-interface-behavior) | 693 |
| PF-INT-07 | [pilot](../explanation/pilot.md#required-interface-behavior) | 694 |
| PF-INT-08 | [pilot](../explanation/pilot.md#required-interface-behavior) | 695 |
| PF-INT-09 | [pilot](../explanation/pilot.md#required-interface-behavior) | 696 |
| PF-INT-10 | [pilot](../explanation/pilot.md#required-interface-behavior) | 697 |
| PF-INT-11 | [pilot](../explanation/pilot.md#required-interface-behavior) | 698 |
| PF-PLN-01 | [planning](../explanation/planning.md#figure-11-design-review-and-release) | 844 |
| PF-PLN-02 | [planning](../explanation/planning.md#figure-11-design-review-and-release) | 844 |
| PF-PLN-03 | [planning](../explanation/planning.md#figure-11-design-review-and-release) | 844 |
| PF-PLN-04 | [planning](../explanation/planning.md#annotation-revision-and-release-identity) | 889 |
| PF-PLN-05 | [planning](../explanation/planning.md#annotation-revision-and-release-identity) | 890 |
| PF-PLN-06 | [planning](../explanation/planning.md#annotation-revision-and-release-identity) | 891 |
| PF-PLN-07 | [planning](../explanation/planning.md#annotation-revision-and-release-identity) | 892 |
| PF-PLN-08 | [planning](../explanation/planning.md#annotation-revision-and-release-identity) | 893 |
| PF-PLN-09 | [planning](../explanation/planning.md#annotation-revision-and-release-identity) | 894 |
| PF-PLN-10 | [planning](../explanation/planning.md#annotation-revision-and-release-identity) | 895 |
| PF-PLN-11 | [planning](../explanation/planning.md#annotation-revision-and-release-identity) | 896 |
| PF-QUAL-01 | [engineering-quality](../explanation/engineering-quality.md#required-quality-controls) | 1010 |
| PF-QUAL-02 | [engineering-quality](../explanation/engineering-quality.md#required-quality-controls) | 1011 |
| PF-QUAL-03 | [engineering-quality](../explanation/engineering-quality.md#required-quality-controls) | 1012 |
| PF-QUAL-04 | [engineering-quality](../explanation/engineering-quality.md#required-quality-controls) | 1013 |
| PF-QUAL-05 | [engineering-quality](../explanation/engineering-quality.md#required-quality-controls) | 1014 |
| PF-QUAL-06 | [engineering-quality](../explanation/engineering-quality.md#required-quality-controls) | 1015 |
| PF-QUAL-07 | [engineering-quality](../explanation/engineering-quality.md#required-quality-controls) | 1016 |
| PF-QUAL-08 | [engineering-quality](../explanation/engineering-quality.md#required-quality-controls) | 1017 |
| PF-PLAN-01 | [delivery-planning](../explanation/delivery-planning.md#figure-13-decomposition-and-plan-review) | 1111 |
| PF-PLAN-02 | [delivery-planning](../explanation/delivery-planning.md#figure-13-decomposition-and-plan-review) | 1111 |
| PF-PLAN-03 | [delivery-planning](../explanation/delivery-planning.md#figure-13-decomposition-and-plan-review) | 1111 |
| PF-PLAN-04 | [delivery-planning](../explanation/delivery-planning.md#figure-13-decomposition-and-plan-review) | 1111 |
| PF-PLAN-05 | [delivery-planning](../explanation/delivery-planning.md#materialize-the-plan-through-the-configured-provider-projection) | 1127 |
| PF-PLAN-06 | [delivery-planning](../explanation/delivery-planning.md#materialize-the-plan-through-the-configured-provider-projection) | 1128 |
| PF-PLAN-07 | [delivery-planning](../explanation/delivery-planning.md#materialize-the-plan-through-the-configured-provider-projection) | 1129 |
| PF-PLAN-08 | [delivery-planning](../explanation/delivery-planning.md#materialize-the-plan-through-the-configured-provider-projection) | 1130 |
| PF-PLAN-09 | [delivery-planning](../explanation/delivery-planning.md#materialize-the-plan-through-the-configured-provider-projection) | 1131 |
| PF-PLAN-10 | [delivery-planning](../explanation/delivery-planning.md#materialize-the-plan-through-the-configured-provider-projection) | 1132 |
| PF-SCH-01 | [routing-and-capacity](../explanation/routing-and-capacity.md#execution-envelopes-and-failures) | 1200 |
| PF-SCH-02 | [routing-and-capacity](../explanation/routing-and-capacity.md#execution-envelopes-and-failures) | 1201 |
| PF-SCH-03 | [routing-and-capacity](../explanation/routing-and-capacity.md#execution-envelopes-and-failures) | 1202 |
| PF-SCH-04 | [routing-and-capacity](../explanation/routing-and-capacity.md#execution-envelopes-and-failures) | 1203 |
| PF-SCH-05 | [routing-and-capacity](../explanation/routing-and-capacity.md#execution-envelopes-and-failures) | 1204 |
| PF-SCH-06 | [routing-and-capacity](../explanation/routing-and-capacity.md#execution-envelopes-and-failures) | 1205 |
| PF-SCH-07 | [routing-and-capacity](../explanation/routing-and-capacity.md#execution-envelopes-and-failures) | 1206 |
| PF-RUN-01 | [execution-runtime](../explanation/execution-runtime.md#cancellation-and-ambiguous-launch) | 1317 |
| PF-RUN-02 | [execution-runtime](../explanation/execution-runtime.md#cancellation-and-ambiguous-launch) | 1318 |
| PF-RUN-03 | [execution-runtime](../explanation/execution-runtime.md#cancellation-and-ambiguous-launch) | 1319 |
| PF-RUN-04 | [execution-runtime](../explanation/execution-runtime.md#cancellation-and-ambiguous-launch) | 1320 |
| PF-RUN-05 | [execution-runtime](../explanation/execution-runtime.md#cancellation-and-ambiguous-launch) | 1321 |
| PF-RUN-06 | [execution-runtime](../explanation/execution-runtime.md#cancellation-and-ambiguous-launch) | 1322 |
| PF-RUN-07 | [execution-runtime](../explanation/execution-runtime.md#cancellation-and-ambiguous-launch) | 1323 |
| PF-RUN-08 | [execution-runtime](../explanation/execution-runtime.md#cancellation-and-ambiguous-launch) | 1324 |
| PF-RUN-09 | [execution-runtime](../explanation/execution-runtime.md#cancellation-and-ambiguous-launch) | 1325 |
| PF-RUN-10 | [execution-runtime](../explanation/execution-runtime.md#versioned-dispatch-instructions) | 1339 |
| PF-RUN-11 | [execution-runtime](../explanation/execution-runtime.md#versioned-dispatch-instructions) | 1340 |
| PF-RUN-12 | [execution-runtime](../explanation/execution-runtime.md#versioned-dispatch-instructions) | 1341 |
| PF-RUN-13 | [execution-runtime](../explanation/execution-runtime.md#versioned-dispatch-instructions) | 1342 |
| PF-IMP-01 | [execution](../explanation/execution.md#pr-draft-and-submission-contract) | 1439 |
| PF-IMP-02 | [execution](../explanation/execution.md#pr-draft-and-submission-contract) | 1440 |
| PF-IMP-03 | [execution](../explanation/execution.md#pr-draft-and-submission-contract) | 1441 |
| PF-IMP-04 | [execution](../explanation/execution.md#pr-draft-and-submission-contract) | 1442 |
| PF-IMP-05 | [execution](../explanation/execution.md#pr-draft-and-submission-contract) | 1443 |
| PF-IMP-06 | [execution](../explanation/execution.md#pr-draft-and-submission-contract) | 1444 |
| PF-IMP-07 | [execution](../explanation/execution.md#pr-draft-and-submission-contract) | 1445 |
| PF-IMP-08 | [execution](../explanation/execution.md#pr-draft-and-submission-contract) | 1446 |
| PF-REV-01 | [review](../explanation/review.md#candidate-acceptance-certificate) | 1551 |
| PF-REV-02 | [review](../explanation/review.md#candidate-acceptance-certificate) | 1552 |
| PF-REV-03 | [review](../explanation/review.md#candidate-acceptance-certificate) | 1553 |
| PF-REV-04 | [review](../explanation/review.md#candidate-acceptance-certificate) | 1554 |
| PF-REV-05 | [review](../explanation/review.md#candidate-acceptance-certificate) | 1555 |
| PF-REV-06 | [review](../explanation/review.md#candidate-acceptance-certificate) | 1556 |
| PF-REV-07 | [review](../explanation/review.md#candidate-acceptance-certificate) | 1557 |
| PF-REV-08 | [review](../explanation/review.md#candidate-acceptance-certificate) | 1558 |
| PF-REV-09 | [review](../explanation/review.md#candidate-acceptance-certificate) | 1559 |
| PF-REV-10 | [review](../explanation/review.md#candidate-acceptance-certificate) | 1560 |
| PF-REV-11 | [review](../explanation/review.md#acceptance-ends-in-an-explicit-factory-integration-action) | 1632 |
| PF-REV-12 | [review](../explanation/review.md#acceptance-ends-in-an-explicit-factory-integration-action) | 1633 |
| PF-REV-13 | [review](../explanation/review.md#acceptance-ends-in-an-explicit-factory-integration-action) | 1634 |
| PF-REV-14 | [review](../explanation/review.md#acceptance-ends-in-an-explicit-factory-integration-action) | 1635 |
| PF-REV-15 | [review](../explanation/review.md#acceptance-ends-in-an-explicit-factory-integration-action) | 1636 |
| AA-01 | [attack-profiles](attack-profiles.md#ai-assisted-code-traps-ai-code-trapsv1) | 1605 |
| AA-02 | [attack-profiles](attack-profiles.md#ai-assisted-code-traps-ai-code-trapsv1) | 1606 |
| AA-03 | [attack-profiles](attack-profiles.md#ai-assisted-code-traps-ai-code-trapsv1) | 1607 |
| AA-04 | [attack-profiles](attack-profiles.md#ai-assisted-code-traps-ai-code-trapsv1) | 1608 |
| AA-05 | [attack-profiles](attack-profiles.md#ai-assisted-code-traps-ai-code-trapsv1) | 1609 |
| AA-06 | [attack-profiles](attack-profiles.md#ai-assisted-code-traps-ai-code-trapsv1) | 1610 |
| AA-07 | [attack-profiles](attack-profiles.md#ai-assisted-code-traps-ai-code-trapsv1) | 1611 |
| AA-08 | [attack-profiles](attack-profiles.md#ai-assisted-code-traps-ai-code-trapsv1) | 1612 |
| PF-FND-01 | [findings-and-triage](../explanation/findings-and-triage.md#figure-22-closeout-cannot-hide-the-backlog) | 1761 |
| PF-FND-02 | [findings-and-triage](../explanation/findings-and-triage.md#figure-22-closeout-cannot-hide-the-backlog) | 1762 |
| PF-FND-03 | [findings-and-triage](../explanation/findings-and-triage.md#figure-22-closeout-cannot-hide-the-backlog) | 1763 |
| PF-FND-04 | [findings-and-triage](../explanation/findings-and-triage.md#figure-22-closeout-cannot-hide-the-backlog) | 1764 |
| PF-FND-05 | [findings-and-triage](../explanation/findings-and-triage.md#figure-22-closeout-cannot-hide-the-backlog) | 1765 |
| PF-FND-06 | [findings-and-triage](../explanation/findings-and-triage.md#figure-22-closeout-cannot-hide-the-backlog) | 1766 |
| PF-FND-07 | [findings-and-triage](../explanation/findings-and-triage.md#figure-22-closeout-cannot-hide-the-backlog) | 1767 |
| PF-FND-08 | [findings-and-triage](../explanation/findings-and-triage.md#figure-22-closeout-cannot-hide-the-backlog) | 1768 |
| PF-FND-09 | [findings-and-triage](../explanation/findings-and-triage.md#figure-22-closeout-cannot-hide-the-backlog) | 1769 |
| PF-FND-10 | [findings-and-triage](../explanation/findings-and-triage.md#figure-22-closeout-cannot-hide-the-backlog) | 1770 |
| PF-GIT-01 | [git-integration](../explanation/git-integration.md#after-merge) | 1868 |
| PF-GIT-02 | [git-integration](../explanation/git-integration.md#after-merge) | 1869 |
| PF-GIT-03 | [git-integration](../explanation/git-integration.md#after-merge) | 1870 |
| PF-GIT-04 | [git-integration](../explanation/git-integration.md#after-merge) | 1871 |
| PF-GIT-05 | [git-integration](../explanation/git-integration.md#after-merge) | 1872 |
| PF-GIT-06 | [git-integration](../explanation/git-integration.md#after-merge) | 1873 |
| PF-GIT-07 | [git-integration](../explanation/git-integration.md#after-merge) | 1874 |
| PF-GIT-08 | [git-integration](../explanation/git-integration.md#after-merge) | 1875 |
| PF-GIT-09 | [git-integration](../explanation/git-integration.md#review-publication-and-provider-identity) | 1887 |
| PF-GIT-10 | [git-integration](../explanation/git-integration.md#review-publication-and-provider-identity) | 1888 |
| PF-GIT-11 | [git-integration](../explanation/git-integration.md#review-publication-and-provider-identity) | 1889 |
| PF-VAL-01 | [validation](../explanation/validation.md#failure-attribution-and-freshness) | 2017 |
| PF-VAL-02 | [validation](../explanation/validation.md#failure-attribution-and-freshness) | 2018 |
| PF-VAL-03 | [validation](../explanation/validation.md#failure-attribution-and-freshness) | 2019 |
| PF-VAL-04 | [validation](../explanation/validation.md#failure-attribution-and-freshness) | 2020 |
| PF-VAL-05 | [validation](../explanation/validation.md#failure-attribution-and-freshness) | 2021 |
| PF-VAL-06 | [validation](../explanation/validation.md#failure-attribution-and-freshness) | 2022 |
| PF-VAL-07 | [validation](../explanation/validation.md#failure-attribution-and-freshness) | 2023 |
| PF-VAL-08 | [validation](../explanation/validation.md#failure-attribution-and-freshness) | 2024 |
| PF-VAL-09 | [validation](../explanation/validation.md#failure-attribution-and-freshness) | 2025 |
| PF-VAL-10 | [validation](../explanation/validation.md#failure-attribution-and-freshness) | 2026 |
| PF-CHG-01 | [change-control](../explanation/change-control.md#change-after-a-provider-request-is-armed) | 2096 |
| PF-CHG-02 | [change-control](../explanation/change-control.md#change-after-a-provider-request-is-armed) | 2097 |
| PF-CHG-03 | [change-control](../explanation/change-control.md#change-after-a-provider-request-is-armed) | 2098 |
| PF-CHG-04 | [change-control](../explanation/change-control.md#change-after-a-provider-request-is-armed) | 2099 |
| PF-CHG-05 | [change-control](../explanation/change-control.md#change-after-a-provider-request-is-armed) | 2100 |
| PF-CHG-06 | [change-control](../explanation/change-control.md#change-after-a-provider-request-is-armed) | 2101 |
| PF-REL-01 | [release-and-closeout](../explanation/release-and-closeout.md#journey-completion-example) | 2197 |
| PF-REL-02 | [release-and-closeout](../explanation/release-and-closeout.md#journey-completion-example) | 2198 |
| PF-REL-03 | [release-and-closeout](../explanation/release-and-closeout.md#journey-completion-example) | 2199 |
| PF-REL-04 | [release-and-closeout](../explanation/release-and-closeout.md#journey-completion-example) | 2200 |
| PF-REL-05 | [release-and-closeout](../explanation/release-and-closeout.md#journey-completion-example) | 2201 |
| PF-REL-06 | [release-and-closeout](../explanation/release-and-closeout.md#journey-completion-example) | 2202 |
| PF-REL-07 | [release-and-closeout](../explanation/release-and-closeout.md#journey-completion-example) | 2203 |
| PF-REL-08 | [release-and-closeout](../explanation/release-and-closeout.md#journey-completion-example) | 2204 |
| PF-API-01 | [api-contract](api-contract.md#events-ordering-and-schema-evolution) | 2322 |
| PF-API-02 | [api-contract](api-contract.md#events-ordering-and-schema-evolution) | 2323 |
| PF-API-03 | [api-contract](api-contract.md#events-ordering-and-schema-evolution) | 2324 |
| PF-API-04 | [api-contract](api-contract.md#events-ordering-and-schema-evolution) | 2325 |
| PF-API-05 | [api-contract](api-contract.md#events-ordering-and-schema-evolution) | 2326 |
| PF-API-06 | [api-contract](api-contract.md#events-ordering-and-schema-evolution) | 2327 |
| PF-API-07 | [api-contract](api-contract.md#events-ordering-and-schema-evolution) | 2328 |
| PF-PROV-01 | [providers](../explanation/providers.md#rate-limits-and-degraded-operation) | 2434 |
| PF-PROV-02 | [providers](../explanation/providers.md#rate-limits-and-degraded-operation) | 2435 |
| PF-PROV-03 | [providers](../explanation/providers.md#rate-limits-and-degraded-operation) | 2436 |
| PF-PROV-04 | [providers](../explanation/providers.md#rate-limits-and-degraded-operation) | 2437 |
| PF-PROV-05 | [providers](../explanation/providers.md#rate-limits-and-degraded-operation) | 2438 |
| PF-PROV-06 | [providers](../explanation/providers.md#rate-limits-and-degraded-operation) | 2439 |
| PF-PROV-07 | [providers](../explanation/providers.md#rate-limits-and-degraded-operation) | 2440 |
| PF-PROV-08 | [providers](../explanation/providers.md#desired-state-compilation-history-delivery-and-profile-changes) | 2477 |
| PF-PROV-09 | [providers](../explanation/providers.md#desired-state-compilation-history-delivery-and-profile-changes) | 2478 |
| PF-PROV-10 | [providers](../explanation/providers.md#desired-state-compilation-history-delivery-and-profile-changes) | 2479 |
| PF-PROV-11 | [providers](../explanation/providers.md#desired-state-compilation-history-delivery-and-profile-changes) | 2480 |
| PF-PROV-12 | [providers](../explanation/providers.md#desired-state-compilation-history-delivery-and-profile-changes) | 2481 |
| PF-PROV-13 | [providers](../explanation/providers.md#desired-state-compilation-history-delivery-and-profile-changes) | 2482 |
| PF-PROV-14 | [providers](../explanation/providers.md#desired-state-compilation-history-delivery-and-profile-changes) | 2483 |
| PF-DUR-01 | [persistence-and-durability](../explanation/persistence-and-durability.md#cost-and-recovery-trade-off) | 2609 |
| PF-DUR-02 | [persistence-and-durability](../explanation/persistence-and-durability.md#cost-and-recovery-trade-off) | 2610 |
| PF-DUR-03 | [persistence-and-durability](../explanation/persistence-and-durability.md#cost-and-recovery-trade-off) | 2611 |
| PF-DUR-04 | [persistence-and-durability](../explanation/persistence-and-durability.md#cost-and-recovery-trade-off) | 2612 |
| PF-DUR-05 | [persistence-and-durability](../explanation/persistence-and-durability.md#cost-and-recovery-trade-off) | 2613 |
| PF-DUR-06 | [persistence-and-durability](../explanation/persistence-and-durability.md#cost-and-recovery-trade-off) | 2614 |
| PF-DUR-07 | [persistence-and-durability](../explanation/persistence-and-durability.md#cost-and-recovery-trade-off) | 2615 |
| PF-DUR-08 | [persistence-and-durability](../explanation/persistence-and-durability.md#cost-and-recovery-trade-off) | 2616 |
| PF-REC-01 | [recovery](../explanation/recovery.md#restore-drills) | 2707 |
| PF-REC-02 | [recovery](../explanation/recovery.md#restore-drills) | 2708 |
| PF-REC-03 | [recovery](../explanation/recovery.md#restore-drills) | 2709 |
| PF-REC-04 | [recovery](../explanation/recovery.md#restore-drills) | 2710 |
| PF-REC-05 | [recovery](../explanation/recovery.md#restore-drills) | 2711 |
| PF-REC-06 | [recovery](../explanation/recovery.md#restore-drills) | 2712 |
| PF-REC-07 | [recovery](../explanation/recovery.md#restore-drills) | 2713 |
| PF-REC-08 | [recovery](../explanation/recovery.md#restore-drills) | 2714 |
| PF-REC-09 | [recovery](../explanation/recovery.md#restore-drills) | 2715 |
| PF-REC-10 | [recovery](../explanation/recovery.md#restore-drills) | 2716 |
| PF-REC-11 | [recovery](../explanation/recovery.md#restore-drills) | 2717 |
| PF-REC-12 | [recovery](../explanation/recovery.md#restore-drills) | 2718 |
| PF-UPG-01 | [upgrades](../explanation/upgrades.md#harness-maintenance-versus-performance-experimentation) | 2804 |
| PF-UPG-02 | [upgrades](../explanation/upgrades.md#harness-maintenance-versus-performance-experimentation) | 2805 |
| PF-UPG-03 | [upgrades](../explanation/upgrades.md#harness-maintenance-versus-performance-experimentation) | 2806 |
| PF-UPG-04 | [upgrades](../explanation/upgrades.md#harness-maintenance-versus-performance-experimentation) | 2807 |
| PF-UPG-05 | [upgrades](../explanation/upgrades.md#harness-maintenance-versus-performance-experimentation) | 2808 |
| PF-UPG-06 | [upgrades](../explanation/upgrades.md#harness-maintenance-versus-performance-experimentation) | 2809 |
| PF-UPG-07 | [upgrades](../explanation/upgrades.md#harness-maintenance-versus-performance-experimentation) | 2810 |
| PF-MET-01 | [experiments-and-metrics](../explanation/experiments-and-metrics.md#lessons-and-curation) | 2906 |
| PF-MET-02 | [experiments-and-metrics](../explanation/experiments-and-metrics.md#lessons-and-curation) | 2907 |
| PF-MET-03 | [experiments-and-metrics](../explanation/experiments-and-metrics.md#lessons-and-curation) | 2908 |
| PF-MET-04 | [experiments-and-metrics](../explanation/experiments-and-metrics.md#lessons-and-curation) | 2909 |
| PF-MET-05 | [experiments-and-metrics](../explanation/experiments-and-metrics.md#lessons-and-curation) | 2910 |
| PF-MET-06 | [experiments-and-metrics](../explanation/experiments-and-metrics.md#lessons-and-curation) | 2911 |
| PF-MET-07 | [experiments-and-metrics](../explanation/experiments-and-metrics.md#lessons-and-curation) | 2912 |
| PF-MET-08 | [experiments-and-metrics](../explanation/experiments-and-metrics.md#lessons-and-curation) | 2913 |
| PF-SEC-01 | [security](../explanation/security.md#figure-41-resource-pressure-response) | 2971 |
| PF-SEC-02 | [security](../explanation/security.md#figure-41-resource-pressure-response) | 2972 |
| PF-SEC-03 | [security](../explanation/security.md#figure-41-resource-pressure-response) | 2973 |
| PF-SEC-04 | [security](../explanation/security.md#figure-41-resource-pressure-response) | 2974 |
| PF-SEC-05 | [security](../explanation/security.md#figure-41-resource-pressure-response) | 2975 |
| PF-SEC-06 | [security](../explanation/security.md#figure-41-resource-pressure-response) | 2976 |
| PF-UX-01 | [operator-experience](../explanation/operator-experience.md#figure-42-progressive-owner-inquiry) | 3041 |
| PF-UX-02 | [operator-experience](../explanation/operator-experience.md#figure-42-progressive-owner-inquiry) | 3042 |
| PF-UX-03 | [operator-experience](../explanation/operator-experience.md#figure-42-progressive-owner-inquiry) | 3043 |
| PF-UX-04 | [operator-experience](../explanation/operator-experience.md#figure-42-progressive-owner-inquiry) | 3044 |
| PF-UX-05 | [operator-experience](../explanation/operator-experience.md#figure-42-progressive-owner-inquiry) | 3045 |
| PF-UX-06 | [operator-experience](../explanation/operator-experience.md#figure-42-progressive-owner-inquiry) | 3046 |
| PF-UX-07 | [operator-experience](../explanation/operator-experience.md#figure-42-progressive-owner-inquiry) | 3047 |
| PF-UX-08 | [operator-experience](../explanation/operator-experience.md#figure-42-progressive-owner-inquiry) | 3048 |
| NFR-01 | [product-acceptance](product-acceptance.md#quality-attributes-of-prifly-itself) | 3098 |
| NFR-02 | [product-acceptance](product-acceptance.md#quality-attributes-of-prifly-itself) | 3099 |
| NFR-03 | [product-acceptance](product-acceptance.md#quality-attributes-of-prifly-itself) | 3100 |
| NFR-04 | [product-acceptance](product-acceptance.md#quality-attributes-of-prifly-itself) | 3101 |
| NFR-05 | [product-acceptance](product-acceptance.md#quality-attributes-of-prifly-itself) | 3102 |
| NFR-06 | [product-acceptance](product-acceptance.md#quality-attributes-of-prifly-itself) | 3103 |
| NFR-07 | [product-acceptance](product-acceptance.md#quality-attributes-of-prifly-itself) | 3104 |
| NFR-08 | [product-acceptance](product-acceptance.md#quality-attributes-of-prifly-itself) | 3105 |
| NFR-09 | [product-acceptance](product-acceptance.md#quality-attributes-of-prifly-itself) | 3106 |
| NFR-10 | [product-acceptance](product-acceptance.md#quality-attributes-of-prifly-itself) | 3107 |
| NFR-11 | [product-acceptance](product-acceptance.md#quality-attributes-of-prifly-itself) | 3108 |
| NFR-12 | [product-acceptance](product-acceptance.md#quality-attributes-of-prifly-itself) | 3109 |
| AT-01 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3119 |
| AT-02 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3120 |
| AT-03 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3121 |
| AT-04 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3122 |
| AT-05 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3123 |
| AT-06 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3124 |
| AT-07 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3125 |
| AT-08 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3126 |
| AT-09 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3127 |
| AT-10 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3128 |
| AT-11 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3129 |
| AT-12 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3130 |
| AT-13 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3131 |
| AT-14 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3132 |
| AT-15 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3133 |
| AT-16 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3134 |
| AT-17 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3135 |
| AT-18 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3136 |
| AT-19 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3137 |
| AT-20 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3138 |
| AT-21 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3139 |
| AT-22 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3140 |
| AT-23 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3141 |
| AT-24 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3142 |
| AT-25 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3143 |
| AT-26 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3144 |
| AT-27 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3145 |
| AT-28 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3146 |
| AT-29 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3147 |
| AT-30 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3148 |
| AT-31 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3149 |
| AT-32 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3150 |
| AT-33 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3151 |
| AT-34 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3152 |
| AT-35 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3153 |
| AT-36 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3154 |
| AT-37 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3155 |
| AT-38 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3156 |
| AT-39 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3157 |
| AT-40 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3158 |
| AT-41 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3159 |
| AT-42 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3160 |
| AT-43 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3161 |
| AT-44 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3162 |
| AT-45 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3163 |
| AT-46 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3164 |
| AT-47 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3165 |
| AT-48 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3166 |
| AT-49 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3167 |
| AT-50 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3168 |
| AT-51 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3169 |
| AT-52 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3170 |
| AT-53 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3171 |
| AT-54 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3172 |
| AT-55 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3173 |
| AT-56 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3174 |
| AT-57 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3175 |
| AT-58 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3176 |
| AT-59 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3177 |
| AT-60 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3178 |
| AT-61 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3179 |
| AT-62 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3180 |
| AT-63 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3181 |
| AT-64 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3182 |
| AT-65 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3183 |
| AT-66 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3184 |
| AT-67 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3185 |
| AT-68 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3186 |
| AT-69 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3187 |
| AT-70 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3188 |
| AT-71 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3189 |
| AT-72 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3190 |
| AT-73 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3191 |
| AT-74 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3192 |
| AT-75 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3193 |
| AT-76 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3194 |
| AT-77 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3195 |
| AT-78 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3196 |
| AT-79 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3197 |
| AT-80 | [product-acceptance](product-acceptance.md#acceptance-scenarios) | 3198 |
| RP-01 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3257 |
| RP-02 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3258 |
| RP-03 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3259 |
| RP-04 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3260 |
| RP-05 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3261 |
| RP-06 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3262 |
| RP-07 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3263 |
| RP-08 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3264 |
| RP-09 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3265 |
| RP-10 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3266 |
| RP-11 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3267 |
| RP-12 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3268 |
| RP-13 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3269 |
| RP-14 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3270 |
| RP-15 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3271 |
| RP-16 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3272 |
| RP-17 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3273 |
| RP-18 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3274 |
| RP-19 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3275 |
| RP-20 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3276 |
| RP-21 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3277 |
| RP-22 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3278 |
| RP-23 | [deployment-parameters](deployment-parameters.md#fixed-direction-versus-unselected-parameters) | 3279 |

## Diagrams

| Source figure | Canonical home |
|---|---|
| 1 | [architecture](../explanation/architecture.md#figure-1-system-context) |
| 2 | [product-lifecycle](../explanation/product-lifecycle.md#figure-2-end-to-end-product-journey) |
| 3 | [architecture](../explanation/architecture.md#figure-3-factory-components) |
| 4 | [architecture](../explanation/architecture.md#figure-4-logical-deployment) |
| 5 | [worker-roles](worker-roles.md#figure-5-routing-ownership) |
| 6 | [domain-model](../explanation/domain-model.md#figure-6-domain-relationships) |
| 7 | [pilot](../explanation/pilot.md#figure-7-startup-and-pilot-registration) |
| 8 | [pilot](../explanation/pilot.md#figure-8-status-with-optional-enrichment) |
| 9 | [pilot](../explanation/pilot.md#figure-9-consequential-choice) |
| 10 | [planning](../explanation/planning.md#figure-10-planning-traceability) |
| 11 | [planning](../explanation/planning.md#figure-11-design-review-and-release) |
| 12 | [engineering-quality](../explanation/engineering-quality.md#figure-12-quality-evaluation-without-recursive-reviewers) |
| 13 | [delivery-planning](../explanation/delivery-planning.md#figure-13-decomposition-and-plan-review) |
| 14 | [routing-and-capacity](../explanation/routing-and-capacity.md#figure-14-admission-and-route-selection) |
| 15 | [context-and-code-intelligence](../explanation/context-and-code-intelligence.md#figure-15-progressive-context) |
| 16 | [execution-runtime](../explanation/execution-runtime.md#figure-16-workspace-handoff-to-a-fresh-current-correction-implementer) |
| 17 | [execution](../explanation/execution.md#figure-17-implementation-evidence-and-branch-checkpoint) |
| 18 | [review](../explanation/review.md#figure-18-one-reviewer-optional-additional-evidence-one-verdict) |
| 19 | [review](../explanation/review.md#figure-19-correction-without-a-new-work-item) |
| 20 | [findings-and-triage](../explanation/findings-and-triage.md#figure-20-finding-intake-has-two-paths) |
| 21 | [findings-and-triage](../explanation/findings-and-triage.md#figure-21-triage-hold-batch-and-eventual-resolution) |
| 22 | [findings-and-triage](../explanation/findings-and-triage.md#figure-22-closeout-cannot-hide-the-backlog) |
| 23 | [git-integration](../explanation/git-integration.md#figure-23-normal-pr-path-and-conflict-handling) |
| 24 | [git-integration](../explanation/git-integration.md#figure-24-merge-request-and-ambiguous-response) |
| 25 | [validation](../explanation/validation.md#figure-25-validation-target-lifecycle) |
| 26 | [validation](../explanation/validation.md#figure-26-validator-reports-factory-records-common-triage-follows) |
| 27 | [validation](../explanation/validation.md#figure-27-product-defects-use-normal-work-scheduling) |
| 28 | [change-control](../explanation/change-control.md#figure-28-change-proposal-to-replacement-baseline) |
| 29 | [release-and-closeout](../explanation/release-and-closeout.md#figure-29-release-readiness-and-publication) |
| 30 | [release-and-closeout](../explanation/release-and-closeout.md#figure-30-closeout-and-learning) |
| 31 | [api-contract](api-contract.md#figure-31-command-outcome-and-same-id-resolution) |
| 32 | [providers](../explanation/providers.md#figure-32-durable-provider-operation) |
| 33 | [persistence-and-durability](../explanation/persistence-and-durability.md#figure-33-authoritative-publication) |
| 34 | [persistence-and-durability](../explanation/persistence-and-durability.md#figure-34-takeover-and-predecessor-frontier) |
| 35 | [persistence-and-durability](../explanation/persistence-and-durability.md#figure-35-evidence-before-acceptance-pins-before-cleanup) |
| 36 | [recovery](../explanation/recovery.md#figure-36-empty-host-recovery) |
| 37 | [upgrades](../explanation/upgrades.md#figure-37-upgrade-and-rollback-boundary) |
| 38 | [upgrades](../explanation/upgrades.md#figure-38-parallel-migration-authoring-without-out-of-order-application) |
| 39 | [experiments-and-metrics](../explanation/experiments-and-metrics.md#figure-39-measurements-to-reviewed-recommendations) |
| 40 | [experiments-and-metrics](../explanation/experiments-and-metrics.md#figure-40-controlled-experiment-lifecycle) |
| 41 | [security](../explanation/security.md#figure-41-resource-pressure-response) |
| 42 | [operator-experience](../explanation/operator-experience.md#figure-42-progressive-owner-inquiry) |
| 43 | [operator-experience](../explanation/operator-experience.md#figure-43-project-onboarding) |

## Source appendices and editorial disposition

- Appendix A: [quality rubrics](quality-rubrics.md), preserving all nineteen profiles and criterion identities.
- Appendix B: [root glossary](../../CONTEXT.md); its repeated quick-reference distinctions are explained in the lifecycle, review and validation documents.
- Appendix C: [source register](source-register.md), with the adopted version/access controls in [standards registry](standards-registry.md). Historical source statements are provenance, not fresh verification.
- Appendices D and E: this navigation catalog replaces the monolithic contents/diagram lists.
- Appendix F: [Worker prompt/context contracts](worker-prompts.md), including thirteen roles, thirty-five jobs, cold-start requirements and qualification fixtures.
- The PRD cover, reading-copy links, candidate change-guide links and end marker are review packaging, not enduring product contracts. They are omitted.
- Section 32 is retained as [design governance](design-governance.md); it grants no implementation release.

Implementation traces and executable test results are added with their actual producers. Their absence here is not a test pass. [Product acceptance](product-acceptance.md) and [conformance](conformance.md) define required observations; [deployment parameters](deployment-parameters.md) block dependent release/admission until selected.

## Initial execution-handover refinements

[ADR-0029](../adr/0029-admit-external-reviewed-execution-packages.md) refines PF-PLN/PF-PLAN/PF-API authority and artifact ingestion without changing their engineering gates. [ADR-0030](../adr/0030-own-attempts-behind-herdr-launcher.md) refines PF-RUN/PF-SEC/PF-SCH process, socket, Docker and workspace ownership.
