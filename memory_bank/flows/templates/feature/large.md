---
title: "FT-XXX: Feature Template - Large Legacy"
doc_kind: feature
doc_function: template
purpose: Legacy v1 wrapper template for an extended canonical `feature.md`. Read this only when maintaining an existing v1 feature package; new packages use `brief.md` and optional `design.md`.
derived_from:
  - ../../feature-flow.md
  - ../../../dna/frontmatter.md
  - ../../../engineering/testing-policy.md
status: active
audience: humans_and_agents
template_for: feature
template_target_path: ../../../features/FT-XXX/feature.md
canonical_for:
  - feature_template_large
---

# FT-XXX: Feature Name

This file describes the wrapper template. The instantiated `feature.md` lives below as an embedded contract and is copied without wrapper frontmatter and history.

## Wrapper Notes

This is a legacy v1 template kept for compatibility with existing `feature.md` packages. New memory bank v2 packages must start from `brief.md` and create optional `design.md` when solution ownership is required; see [../../feature-flow.md#version-boundary](../../feature-flow.md#version-boundary).

Use this template only when maintaining or migrating an existing v1 feature package and at least one `short.md` rule no longer holds: the feature affects several surfaces, changes a contract, requires explicit assumptions / blockers, or needs a non-trivial verification layer.

Use stable identifiers from the taxonomy in [../../feature-flow.md#stable-identifiers](../../feature-flow.md#stable-identifiers).

### Frontmatter Quick Ref

The full schema is in [../../../dna/frontmatter.md](../../../dna/frontmatter.md). For a standard feature, this is enough:

| Field | Required | Values / default |
|---|---|---|
| `title` | required | `"FT-XXX: Name"` |
| `doc_kind` | required | `feature` |
| `doc_function` | required | `canonical` |
| `purpose` | required | 1-2 sentences |
| `status` | required | `draft` -> `active` -> `archived` |
| `derived_from` | required for active | upstream documents |
| `delivery_status` | required for feature | `planned` -> `in_progress` -> `done` / `cancelled` |
| `audience` | recommended | `humans_and_agents` |
| `must_not_define` | recommended | what the document does NOT define |

## Instantiated Frontmatter

```yaml
title: "FT-XXX: Feature Name"
doc_kind: feature
doc_function: canonical
purpose: "Extended canonical feature document for a complex or multi-layer delivery unit."
derived_from:
  - ../../product/context.md
  # Optional:
  # - ../../prd/PRD-<id>-short-name.md
  # - ../../use-cases/UC-XXX-short-name.md
  # - ../../domain/model.md
  # - ../../domain/rules.md
  # - ../../domain/states.md
  # - ../../domain/events.md
status: draft
delivery_status: planned
audience: humans_and_agents
must_not_define:
  - implementation_sequence
```

## Instantiated Body

```markdown
# FT-XXX: Feature Name

## What

### Problem

Which symptom, constraint, or opportunity makes the feature necessary. If shared context is already recorded upstream, describe only the feature-specific delivery question here.

If an upstream PRD exists, this section records only the feature-specific delta relative to the PRD and does not rewrite the whole product document.

If an upstream use case exists, this section records the feature-specific change or implementation of that scenario, not the entire project flow.

If the feature changes shared domain concepts, rules, states, events, or context boundaries, add the corresponding `../../domain/` document to `derived_from` and describe only the feature-specific delta here.

### Outcome

Describe the outcome as a measurable table.

If a numeric success threshold applies only to this delivery unit, record it here. Elevate the threshold upstream only after a shared owner appears for multiple features.

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | What we measure | Starting point | What counts as success | How we verify |

### Scope

- `REQ-01` What must be included in the deliverable.
- `REQ-02` What else must be included in the deliverable.

### Non-Scope

- `NS-01` What is intentionally excluded.
- `NS-02` What the agent must not infer or implement independently.

### Constraints / Assumptions

- `ASM-01` What we currently rely on.
- `CON-01` What directly constrains design, rollout, or verification.
- `DEC-01` Which decision is not yet accepted and exactly what it blocks.

## How

### Solution

One short paragraph: the main technical approach and the main trade-off.

### Change Surface

Record exactly where changes are expected.

| Surface | Type | Why it changes |
| --- | --- | --- |
| `path/or/component` | code / config / doc / data | Why this is in the change set |

### Flow

1. What comes in as input.
2. What the system does.
3. What comes out as output.

### Contracts

Describe inputs, outputs, events, payloads, or schema changes if they matter for the feature.

| Contract ID | Input / Output | Producer / Consumer | Notes |
| --- | --- | --- | --- |
| `CTR-01` | What changes | Who writes / who reads | What must be respected |

### Failure Modes

- `FM-01` What can go wrong.
- `FM-02` How the system must respond.

### ADR Dependencies

If the feature depends on an ADR, record that explicitly.

| ADR | Current `decision_status` | Used for | Execution rule |
| --- | --- | --- | --- |
| `../../adr/ADR-<id>-short-decision-name.md` | `proposed` / `accepted` | Which design choice or baseline needs this | `proposed` is used only as a hypothesis / benchmark candidate and is not considered finalized design; `accepted` can be used as canonical input |

## Verify

`Verify` defines the canonical test case inventory for the delivery unit: positive scenarios through `SC-*`, feature-specific negative coverage through `NEG-*`, executable checks through `CHK-*`, and evidence through `EVID-*`.

### Exit Criteria

- `EC-01` Verifiable readiness signal.
- `EC-02` Another required readiness signal.

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `ASM-01`, `CON-01`, `DEC-01`, `CTR-01`, `FM-01` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-02` | `ASM-01`, `CON-01`, `CTR-01`, `FM-02` | `EC-02`, `SC-02` | `CHK-01` | `EVID-01` |

### Acceptance Scenarios

- `SC-01` Main happy path.
- `SC-02` Required real-world or edge scenario.

### Checks

Verify must be executable.

| Check ID | Covers | How to check | Expected result | Evidence path |
| --- | --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `SC-01` | Command or procedure | What counts as success | Where the artifact lives |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-xxx/verify/chk-01/` |

### Evidence

- `EVID-01` Which artifact must appear after verification.

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | Log, report, screenshot, or sample output | verify-runner / human | `artifacts/ft-xxx/verify/chk-01/` | `CHK-01` |
```
