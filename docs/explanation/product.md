# Product definition

Kind: explanation

## Product summary and problem statement

### What PriFly is

PriFly is a personal, local-first, autonomous software factory. A human owner talks to **Pilot**, an AI conversational interface. Pilot elicits and records the owner's requirements and turns explicit requests into calls to **Factory**, a deterministic Go application. Factory stores the meaning of the work, applies declared admission and scheduling rules within owner-released phases, starts an appropriately equipped **Worker** through **HerdR**, validates returned records, and controls the next transition. Workers supply the semantic design and evaluation judgments those rules consume.

A Worker is not a permanent autonomous employee with its own private backlog. It is a bounded execution assigned a specific role, input, output contract, authority, and resource envelope. One Worker may design a feature; another independently reviews that design. One implements a Work Item; another reviews the exact resulting code. A Validator later exercises the integrated product on a representative stack.

The owner can disconnect, replace Pilot, restart the container stack, or recover on a replacement host without using a chat transcript as the project database.

### Problems the product must solve

Today, too much workflow behavior lives in lengthy agent instructions. A model must remember sequencing, templates, issue state, review rules, tool restrictions, and the owner's design decisions while also doing cognitive work. That creates repeated context loading, inconsistent output, forgotten obligations, accidental scope changes, and coordination overhead.

PriFly must solve five related problems:

1. **Workflow memory:** accepted decisions and outstanding work must survive any conversation or execution session.
2. **Engineering quality:** every artifact must have a known quality standard, expected evidence, and a clear completion condition before work starts.
3. **Efficient execution:** independent review must not imply automatically running every expensive test twice, rebuilding an environment for every small fix, or keeping a large orchestrator model continuously active.
4. **Accountability:** every finding must either be corrected in its current work or remain tracked through triage and an explicit outcome. A successful merge must not masquerade as proof that the product works in its intended environment.
5. **Operational simplicity:** this is a hobby-scale containerized product, not an enterprise high-availability appliance or a hostile-code sandbox project.

### Product promise

The owner should be able to say, “I want to build this,” and then conduct one continuous conversation about goals, alternatives, progress, trade-offs, and results. After the owner releases each relevant phase, PriFly performs its research, design, planning, implementation, review, validation, triage, release, and closeout through bounded jobs and durable records. Saving or discussing an idea alone starts none of that project work.

The owner must also be able to ask, “Why did we decide that?”, “What blocks this?”, “What still has not been tested as a product?”, or “Are the cheaper models actually saving effort?” and receive an answer grounded in Factory records rather than a plausible reconstruction from model memory.

### Goals and observable success

| Goal | Observable success condition |
|---|---|
| Durable intent | A replacement Pilot can explain the same active goals, decisions, unresolved questions, and blockers without the previous conversation. |
| Owner-controlled fan-out | Intake starts no project Workers. Architecture, delivery planning, and execution each require the owner's explicit release of the exact package and scope. Engineering-quality gates must also pass. |
| Bounded cognition | Every AI execution has a role, exact subject, finite scope, recorded Route, and accountable result. |
| Efficient review | A Reviewer can accept sufficient Implementer evidence or gather more evidence in the same review; no automatic review-of-a-test-result recursion occurs. |
| Efficient corrections | A fresh Implementer attempt performs current corrections in the existing Implementation Workspace instead of provisioning the work environment again. |
| Honest delivery status | Merged work and validated product behavior are represented separately. |
| Controlled follow-up work | Findings can be held and batched without becoming invisible, and scope closeout cannot abandon them silently. |
| Recoverable operations | Published authoritative state and historical metrics survive local-host loss under the declared remote-dependency assumptions. |
| Useful learning | Route comparisons include review, rescue, failure, validation, and missing-data effects, not only successful first attempts. |

PriFly does not promise that AI never makes mistakes. It must make mistakes visible, bounded, attributable, reviewable, and recoverable.

---

## Users, scope, and bounding principles

### Primary user

The primary user is a technically capable individual who builds software and container-based environments, understands the intended product, and may not know every implementation language or tool. The system must explain decisions in ordinary engineering terms. It must not require the owner to understand low-level database replication or Git internals merely to approve a product direction.

The owner is both product decision-maker and local operator. These are different activities: approving a change in product behavior is not the same as repairing a cloud credential or restarting a runtime.

### Other participants

**Pilot** is the conversational interface. **CLI** means the command-line interface available to Pilot, tools, and the owner through different capabilities. **Bridge** is a future graphical interface over the same records and actions. **Workers** perform product work. Third-party harnesses, model providers, GitHub, Git remotes, R2, and HerdR are integrations, not additional workflow authorities.

### v1 product scope

v1 includes multi-project and multi-repository tracking; multiple admitted model/harness combinations; subscription, metered, and local-model Routes; structured planning and quality gates; implementation and correction; independent review; GitHub pull-request integration; product validation; common finding intake and semantic triage; batching; releases and closeout; durable owner attention; source-backed context; historical metrics; bounded experiments; host-loss recovery; and safe upgrades.

The first usable increment may implement a smaller vertical slice. It must not be labeled full v1 until the v1 acceptance obligations are met.

### Non-goals

v1 does not require a hosted multi-user service, distributed Worker fleet, microservices, PostgreSQL, Redis, a dedicated PriFly MCP server, automatic leader election, atomic cross-repository merge, mandatory merge queues, enterprise data-loss prevention, multi-cloud disaster recovery, or hostile-agent containment. Google Drive secondary backup is not a v1 dependency. A GUI is not required for the first interface.

Using an existing tool's MCP interface, such as Serena's, is permitted. That is different from making MCP the required protocol for Factory or building a new provider-broker MCP service.

### Bounding principles

| ID | Principle |
|---|---|
| BP-01 | Factory owns workflow meaning and durable state; Workers supply bounded cognitive results. |
| BP-02 | Pilot elicits and records owner intent, translates requests, and explains records. Substantive research, technical design, coding, triage, review, and validation are authorized Factory jobs. |
| BP-03 | Industry engineering quality, project conformance, and workflow eligibility are separate judgments. |
| BP-04 | A producer cannot approve its own consequential work. Independent review evaluates the artifact, not the producer's confidence. |
| BP-05 | Evidence gathering does not require a new Reviewer. A material candidate change requires a new review subject and a fresh review. |
| BP-06 | Only Factory dispatches Workers. Runtime features do not create permission to spawn untracked jobs. |
| BP-07 | Workers commit on their assigned branches. Factory publishes those branches and requests GitHub PR merges; it does not directly push product changes to `main`. |
| BP-08 | Current corrections stay inside the current Work Item/PR. Other findings enter tracked triage. |
| BP-09 | Small follow-ups can accumulate into coherent planning batches; holding or batching is not resolution. |
| BP-10 | Validation findings use the same triage and implementation pipeline as other findings. |
| BP-11 | An Implementation Workspace outlives individual implementation and current-correction attempts. It has at most one authorized writer at a time. |
| BP-12 | Required criteria and project-specific thresholds are selected before the work they judge. Evaluators cannot lower them after seeing results. |
| BP-13 | A consequential owner decision requires explicit owner authority, not interpretation of an example or conversational preference. |
| BP-14 | Authoritative success is published off-host before acknowledgment; transient progress may be lost. |
| BP-15 | A possibly sent external operation remains unresolved until its outcome can be established. Timeout does not mean failure. |
| BP-16 | Unknown applicability, unknown impact, unknown provider outcome, and unknown runtime state are different typed conditions. |
| BP-17 | More autonomy does not mean unlimited attempts, tokens, storage, or elapsed work. |
| BP-18 | The implementation environment is disposable; the historical project and measurement record is not. |
| BP-19 | Intake, architecture release, design approval/delivery-planning release, and execution release are distinct. A quality gate or external board status cannot substitute for owner authorization. |
| BP-20 | Provider projections are configurable views of canonical work. GitHub milestones map to Initiatives, and review/correction history is retained as structured records before publication. |

These are product and architecture requirements. They are not presented as external industry quality rubrics.
