---
title: Templates Index
doc_kind: governance
doc_function: index
purpose: Navigation for reference project documentation templates. Read this to create a PRD, use case, epic, feature, ADR, prompt, process, or execution document without inventing a new structure.
derived_from:
  - ../../dna/governance.md
  - prd/PRD-ID.md
  - use-case/UC-XXX.md
  - epic/README.md
  - epic/charter.md
  - epic/roadmap.md
  - epic/decision-log.md
  - epic/subissues.md
  - epic/risks.md
  - feature/README.md
  - feature/brief.md
  - feature/design.md
  - feature/implementation-plan.md
  - feature/support/runtime-surfaces.md
  - feature/support/ui-reference.md
  - feature/support/use-cases.md
  - adr/ADR-ID.md
  - prompt/PROMPT-ID.md
  - process/README.md
  - process/process-card.md
  - process/session-handoff.md
  - process/lifecycle-protocol.md
  - feature/short.md
  - feature/large.md
status: active
audience: humans_and_agents
---

# Templates Index

The `memory_bank/flows/templates/` catalog stores reference project documentation templates. All templates live as governed wrapper documents with `doc_function: template`: the wrapper has its own purpose, while the frontmatter and body of the instantiated document live inside the embedded template contract.

- [PRD-ID: Product Initiative Name](prd/PRD-ID.md) - compact Product Requirements Document for an initiative that has not yet been decomposed into one concrete feature slice.
- [UC-XXX: Use Case Name](use-case/UC-XXX.md) - canonical use case for a durable user or operational scenario.
- [Epic Templates](epic/README.md) - index for `EP-XXX` package templates.
- [EP-XXX: Charter Template](epic/charter.md) - intent, scope, source/evidence, and stakeholder channels.
- [EP-XXX: Roadmap Template](epic/roadmap.md) - waves, dependencies, gates, and stop rules.
- [EP-XXX: Decision Log Template](epic/decision-log.md) - local epic decisions that do not require global ADR.
- [EP-XXX: Subissues Template](epic/subissues.md) - candidate/accepted delivery subissue registry.
- [EP-XXX: Risks Template](epic/risks.md) - epic-level risk register.
- [FT-XXX Feature README Template](feature/README.md) - conditional README template used when a package adds a design, plan, or support document beside `brief.md`. Answers the question: how to route an expanded feature package.
- [FT-XXX: Brief Template](feature/brief.md) - canonical template for new feature packages; scales from a single-file governed package with bounded design notes / execution controls to richer problem context and selects design / plan requirement gates. Answers the question: how to record intent, scope, and verify while keeping compact work in one owner.
- [FT-XXX: Design Template](feature/design.md) - canonical solution-space template for a feature package; compact packages keep only sections with real design facts. Answers the question: how to record selected design, rationale, contracts, failure modes, and design-pack routing.
- [FT-XXX: Implementation Plan](feature/implementation-plan.md) - conditional derived execution-plan template used only when `brief.md` records `Plan required: yes`; compact plans keep only executable controls. Answers the question: how to record sequencing and checkpoints after upstream owners are ready.
- [FT-XXX: Runtime Surfaces Template](feature/support/runtime-surfaces.md) - optional support template for current runtime inventory, semantic mapping, context matrix, and resolution tables.
- [FT-XXX: UI Reference Template](feature/support/ui-reference.md) - optional support template for interface changes, screen map, interaction states, and mockups.
- [FT-XXX: Feature Use Cases Template](feature/support/use-cases.md) - optional support template for derived use cases, test case candidates, and `FUC -> REQ -> CHK` review mapping.
- [ADR-ID: Short Decision Name](adr/ADR-ID.md) - ADR template. Answers the question: how to record an architecture decision.
- [PROMPT-ID: Reusable Prompt Name](prompt/PROMPT-ID.md) - reusable prompt document template. Answers the question: how to preserve source wording in frontmatter and improved prompt in a copyable body block.
- [Process Documentation Index Template](process/README.md) - process-document index template. Answers the question: how to assemble a routing layer for reusable process cards, session handoff, and lifecycle protocol.
- [PROCESS-ID: Compact Process Card](process/process-card.md) - short reusable workflow template. Answers the question: how to record a process with one trigger, steps, and exit criteria.
- [PROCESS-ID: Session Handoff](process/session-handoff.md) - state handoff template between sessions. Answers the question: how to continue a process without losing assumptions, risks, and next checks.
- [PROCESS-ID: Lifecycle Protocol](process/lifecycle-protocol.md) - full lifecycle protocol template. Answers the question: how to run a multi-phase process with gates, verification, and rollback.

## Legacy v1 Compatibility

These templates are a local compatibility addition for existing memory bank v1 feature packages. They are not used for new v2 feature packages.

- [FT-XXX: Feature Template - Short Legacy](feature/short.md) - legacy v1 `feature.md` template kept for maintaining existing packages.
- [FT-XXX: Feature Template - Large Legacy](feature/large.md) - legacy v1 `feature.md` template kept for maintaining existing packages.
