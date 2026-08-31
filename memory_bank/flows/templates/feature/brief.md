---
title: "FT-XXX: Brief Template"
doc_kind: feature
doc_function: template
purpose: Governed wrapper template for canonical `brief.md` in AI-driven development. Defines how to instantiate a single-file governed feature and expand only when separate design or execution ownership is required.
derived_from:
  - ../../feature-flow.md
  - ../../../dna/frontmatter.md
  - ../../../engineering/testing-policy.md
status: active
audience: humans_and_agents
template_for: feature
template_target_path: ../../../features/FT-XXX/brief.md
canonical_for:
  - feature_brief_template
---

# FT-XXX: Feature Name

This file describes the wrapper template. The instantiated `brief.md` lives below as an embedded contract and is copied without wrapper frontmatter and history.

## Wrapper Notes

Use this template for every new feature package. `brief.md` records the delivery unit's problem, outcome, scope/non-scope, and verify contract; in a governed compact package it may also carry bounded design notes and execution controls.

Record `Design required: yes` only when the feature introduces or materially changes architecture, a shared contract/protocol/data flow/trust model, failure semantics, rollout mechanics, or requires alternatives/C4/new-ADR reasoning. Applying an established integration pattern or accepted ADR to another consumer does not trigger `design.md` by itself when those semantics remain unchanged; cite the owner in a short `Design Notes` section instead.

Separately, record `Plan required: yes/no` using [When `implementation-plan.md` Is Required](../../feature-flow.md#when-implementation-planmd-is-required). That section is the single owner of plan triggers and the bounded no-plan exception. Evaluate closed stages first: triggers discovered after `Done` or `Cancelled` become follow-up work. Missing-decision compatibility and late requirement changes remain defined by `feature-flow.md`.

For a governed compact package, instantiate only this `brief.md`, register it directly from `memory_bank/features/README.md`, and fill the required minimum: one clear problem statement, `REQ-*`, `NS-*`, both requirement decisions, `SC-*`, `CHK-*`, and `EVID-*`. Keep `Design Notes`, `Execution Controls`, metrics, assumptions, constraints, and rich evidence tables only when they add review value. Create package-level `README.md` together with the first design, plan, or support document.

Use stable identifiers according to the taxonomy in [../../feature-flow.md#stable-identifiers](../../feature-flow.md#stable-identifiers).

Link upstream PRD, use case, product, domain, or engineering owners in `derived_from` and record only this feature's delta. If the feature changes shared domain concepts, rules, states, events, or context boundaries, add the corresponding `../../domain/` owner instead of copying it here.

### Frontmatter Quick Ref

The full schema is in [../../../dna/frontmatter.md](../../../dna/frontmatter.md). For a standard feature, the following is enough:

| Field | Required | Values / default |
|---|---|---|
| `title` | required | `"FT-XXX: Name"` |
| `doc_kind` | required | `feature` |
| `doc_function` | required | `canonical` |
| `purpose` | required | 1-2 sentences |
| `status` | required | `draft` -> `active` -> `archived` |
| `derived_from` | required for active | upstream documents |
| `delivery_status` | required for lifecycle-owning `brief.md` | `planned` -> `in_progress` -> `done` / `cancelled` |
| `audience` | recommended | `humans_and_agents` |
| `must_not_define` | recommended | what the document does NOT define |

## Instantiated Frontmatter

```yaml
title: "FT-XXX: Feature Name"
doc_kind: feature
doc_function: canonical
purpose: "Canonical brief for the delivery unit. Records problem space, scope, verify, and any bounded compact-path design notes or execution controls."
derived_from:
  - ../../flows/feature-flow.md
  # Optional:
  # - ../../product/context.md
  # - ../../prd/PRD-<id>-short-name.md
  # - ../../use-cases/UC-XXX-short-name.md
  # - ../../domain/model.md
  # - ../../domain/rules.md
  # - ../../domain/states.md
  # - ../../domain/events.md
  # - ../../engineering/architecture.md
  # - ../../engineering/frontend.md
status: draft
delivery_status: planned
audience: humans_and_agents
must_not_define:
  - implementation_sequence
  - new_architecture_or_contract
```

## Instantiated Body: Compact Default

Copy this body by default and replace each placeholder. Add optional snippets only when they carry real facts.

```markdown
# FT-XXX: Feature Name

Source task / ticket: `<link>`

## What

One sentence describing the feature-specific problem or delivery outcome.

- `REQ-01` What must be included in the deliverable.
- `NS-01` What is intentionally excluded.

## Design Requirement Decision

`Design required: no` — Why no separate solution owner is needed. Change to `yes` and create `design.md` when a Design trigger applies.

## Plan Requirement Decision

`Plan required: no` — Why this brief plus issue / PR notes are sufficient. Change to `yes` and create `implementation-plan.md` when a Plan trigger applies.

## Verify

- `SC-01` (`REQ-01`) — Primary acceptance scenario and observable result.
- `CHK-01` (`REQ-01`, `SC-01`) — Command or procedure; expected result.
- `EVID-01` (`CHK-01`) — Concrete file, CI run, screenshot, log, or other carrier.
```

## Optional Expansion Snippets

Add only the snippets that carry real facts. They are not part of the compact default.

### Established Pattern Design Notes

```markdown
## Design Notes

- Existing pattern / accepted ADR owner: `<link or path>`.
- Feature-local application: What is reused without changing shared semantics.
```

### Bounded Execution Control

```markdown
## Execution Controls

- `AG-01` (`CHK-01`, `EVID-01`) — Bounded gate/reason; owner; approval or evidence carrier.
```

### Outcome Metric

```markdown
- `MET-01` — Metric; baseline; target; measurement method.
```

### Assumptions, Constraints, Or Blocking Decisions

```markdown
- `ASM-01` — Working premise.
- `CON-01` — Constraint on scope, verify, or acceptable solutions.
- `DEC-01` — Unresolved decision and exactly what it blocks.
```

### Negative Or Exit Coverage

```markdown
- `NEG-01` (`REQ-01`) — Negative or edge scenario that changes the verdict.
- `EC-01` (`REQ-01`) — Additional verifiable readiness signal.
```

### Compact Traceability Table

Use this instead of inline refs only when several requirements or checks are hard to scan.

```markdown
| Requirement | Scenarios | Checks | Evidence |
| --- | --- | --- | --- |
| `REQ-01` | `SC-01`, `NEG-01` | `CHK-01` | `EVID-01` |
```

### Rich Evidence Contract

Use this only when evidence has a stable path/producer contract or is reused by several checks.

```markdown
| Evidence | Artifact | Producer | Path / carrier | Reused by |
| --- | --- | --- | --- | --- |
| `EVID-01` | Report or screenshot | Agent / human | `<path or immutable link>` | `CHK-01` |
```
