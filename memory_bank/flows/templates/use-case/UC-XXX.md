---
title: "UC-XXX: Use Case Name"
doc_kind: use_case
doc_function: template
purpose: Governed wrapper template for use cases. Read this to instantiate a canonical user or operational scenario without mixing wrapper metadata with the future use case frontmatter.
derived_from:
  - ../../../dna/governance.md
  - ../../../dna/frontmatter.md
  - ../../../product/context.md
status: active
audience: humans_and_agents
template_for: use_case
template_target_path: ../../../use-cases/UC-XXX-short-name.md
canonical_for:
  - use_case_template
---

# UC-XXX: Use Case Name

This file describes the wrapper template. The instantiated use case lives below as an embedded contract and is copied without wrapper frontmatter and history.

## Wrapper Notes

A use case records a durable project scenario. It describes trigger, preconditions, main flow, alternatives, and postconditions, but does not go into implementation sequence, architecture, or feature-level verification.

If the scenario is too local and lives only inside one delivery unit, do not elevate it into `UC-*`: leave it in `SC-*` for the relevant feature.

If the scenario depends on a domain invariant, state transition, or domain event, add the corresponding document from `../domain/` to `derived_from`.

## Instantiated Frontmatter

```yaml
title: "UC-XXX: Use Case Name"
doc_kind: use_case
doc_function: canonical
purpose: "Records a durable user or operational scenario for the project."
derived_from:
  - ../product/context.md
  # Optional:
  # - ../prd/PRD-<id>-short-name.md
  # - ../domain/rules.md
  # - ../domain/states.md
  # - ../domain/events.md
status: draft
audience: humans_and_agents
must_not_define:
  - implementation_sequence
  - architecture_decision
  - feature_level_test_matrix
```

## Instantiated Body

```markdown
# UC-XXX: Use Case Name

## Goal

What result the actor should receive after successful scenario completion.

## Primary Actor

Who initiates the scenario.

## Trigger

Which event or intent starts the flow.

## Preconditions

- What must be true before the scenario starts.
- Which data, permissions, or system state are required.

## Main Flow

1. First scenario step.
2. Second scenario step.
3. Observable result.

## Alternate Flows / Exceptions

- `ALT-01` How the scenario branches for an expected alternative.
- `EX-01` Which failure or refusal must be handled correctly.

## Postconditions

- What is true after successful completion.
- What remains true after unsuccessful completion.

## Business Rules

- `BR-01` Rule that any implementation of this scenario must follow.
- `BR-02` Constraint or policy that affects the flow.

## Traceability

| Upstream / Downstream | References |
| --- | --- |
| PRD | `PRD-<id>` / `none` |
| Features | `FT-XXX`, `FT-YYY` |
| ADR | `ADR-<id>` / `none` |
```
