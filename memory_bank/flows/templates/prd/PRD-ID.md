---
title: "PRD-ID: Product Initiative Name"
doc_kind: prd
doc_function: template
purpose: Governed wrapper template for PRDs. Read this to instantiate a compact Product Requirements Document without mixing wrapper metadata with the future PRD frontmatter.
derived_from:
  - ../../../dna/governance.md
  - ../../../dna/frontmatter.md
  - ../../../product/context.md
status: active
audience: humans_and_agents
template_for: prd
template_target_path: ../../../prd/PRD-<id>-short-name.md
canonical_for:
  - prd_template
---

# PRD-ID: Product Initiative Name

This file describes the wrapper template. The instantiated PRD lives below as an embedded contract and is copied without wrapper frontmatter and history.

## Wrapper Notes

The PRD in this template is intentionally lean. It records the product problem, users, goals, scope, and success metrics, but does not take ownership of implementation sequencing, architecture decisions, or verify/evidence contracts for downstream feature packages.

The PRD relies on `product/context.md`; it does not replace it. Do not copy all project-wide context into it if that context is already stably described upstream.

If the initiative changes domain concepts, rules, states, or events, update the corresponding document from `domain/` and add it to `derived_from`.

Use a PRD as the upstream layer between shared project context and multiple feature packages. If the initiative is local and does not require a separate product-layer document, a PRD can be skipped.

Replace `ID` with an accepted stable initiative, epic, issue, or project key. If no stable key exists, use a UTC timestamp in `YYYYMMDDTHHMMSSZ` format. Do not allocate a local monotonic sequence number.

## Instantiated Frontmatter

```yaml
title: "PRD-ID: Product Initiative Name"
doc_kind: prd
doc_function: canonical
purpose: "Records the initiative's product problem, target users, goals, scope, and success metrics."
derived_from:
  - ../product/context.md
  # Optional:
  # - ../domain/model.md
  # - ../domain/rules.md
  # - ../product/customers.md
  # - ../product/metrics.md
status: draft
audience: humans_and_agents
must_not_define:
  - implementation_sequence
  - architecture_decision
  - feature_level_verify_contract
```

## Instantiated Body

```markdown
# PRD-ID: Product Initiative Name

## Problem

Which user or business problem the initiative solves. Describe the problem language, not the solution. Link to shared context from `../product/context.md` and record only this initiative's delta.

## Users And Jobs

Who the primary user is and what job they are trying to do.

| User / Segment | Job To Be Done | Current Pain |
| --- | --- | --- |
| `primary-user` | What they want to do | What blocks them today |

## Goals

- `G-01` Which product outcome is required.
- `G-02` Which additional outcome is desirable.

## Non-Goals

- `NG-01` What is intentionally outside the initiative.
- `NG-02` What must not be silently inferred at the implementation level.

## Product Scope

Describe scope at the capability level, not as a change set.

### In Scope

- What must become possible for the user or system.

### Out Of Scope

- What remains outside the initiative boundaries.

## UX / Business Rules

- `BR-01` Important product or operational rule.
- `BR-02` Constraint that every downstream feature must respect.

If a rule is a shared domain invariant rather than initiative-specific product scope, update `../domain/rules.md` and add it to `derived_from`.

## Success Metrics

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | What we measure | Starting point | What counts as success | How we verify |

## Risks And Open Questions

- `RISK-01` What could derail the initiative at the product level.
- `OQ-01` Which unknown has not yet been resolved.

## Downstream Features

List expected feature packages if they are already clear.

| Feature | Why it exists | Status |
| --- | --- | --- |
| `FT-XXX` | Which slice it implements | planned / draft / active |
```
